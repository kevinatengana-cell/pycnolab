import os
import sys
import tempfile
import traceback
from pathlib import Path
from typing import Any, Dict, List, Optional

_RESOURCE_ROOT = Path(
    getattr(sys, '_MEIPASS', Path(__file__).resolve().parents[2])
)
_DATA_DIR = Path(
    os.environ.get(
        'PYCNOLAB_DATA_DIR',
        Path(tempfile.gettempdir()) / 'PycnoLab',
    )
).expanduser().resolve()
_TEMP_DIR = _DATA_DIR / 'tmp'


def _temporary_directory() -> Path:
    _TEMP_DIR.mkdir(parents=True, exist_ok=True)
    return _TEMP_DIR

from fastapi import FastAPI, HTTPException, Request, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

from moteur_python.api.backend_lifecycle import backend_lifecycle
from moteur_python.calculs.traction import (
    TractionCalculateur,
    TractionConfig,
    GammeCalculateur,
)
from moteur_python.import_excel.reader import lire_classeur_complet, lire_gamme_complete
from moteur_python.import_excel.reader import (
    lister_echantillons,
    lire_donnees_brutes,
    read_workbook,
)
from moteur_python.export_excel.production_workbook_exporter import (
    analyser_resultats,
    process_workbook,
)

app = FastAPI(title="Pycnolab Engine API", version="2.0.0")

# 1. CONFIGURATION CORS (Requis pour Flutter Desktop/Web)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# -----------------------------------------------------------------------------
# DEBUG : au lieu d'un "Internal Server Error" vide, renvoie le type d'erreur,
# son message et l'endroit du code où elle s'est produite.
# -----------------------------------------------------------------------------
@app.exception_handler(Exception)
async def toutes_les_erreurs(request: Request, exc: Exception):
    traceback.print_exc()
    lieu = ""
    frames = traceback.extract_tb(exc.__traceback__)
    if frames:
        f = frames[-1]
        lieu = f" [{os.path.basename(f.filename)}:{f.lineno} dans {f.name}]"
    return JSONResponse(
        status_code=500,
        content={"detail": f"{type(exc).__name__}: {exc}{lieu}"},
    )


@app.get("/health")
async def health():
    return {"service": "pycnolab-engine", "protocol": "3", "status": "ok"}


@app.post("/internal/heartbeat", status_code=204)
async def heartbeat():
    backend_lifecycle.beat()
    return Response(status_code=204)


@app.get("/")
async def racine(request: Request):
    return {
        "status": "ok",
        "moteur": "Pycnolab v2.0.0",
        "port": request.url.port,
        "health": "/health",
    }


# -----------------------------------------------------------------------------
# 2. MODÈLES DE DONNÉES (PYDANTIC)
# -----------------------------------------------------------------------------
class TractionRequest(BaseModel):
    deplacement: List[float]
    force: List[float]
    section_mm2: float
    longueur_initiale_mm: float
    config_personnalisee: Optional[Dict[str, Any]] = None


class ExportExcelRequest(BaseModel):
    donnees_traction: TractionRequest
    mapping_cellules: Dict[str, str]
    chemin_template: Optional[str] = "MODELE_TRACTION.xlsx"


class GammeRequest(BaseModel):
    nom_gamme: str
    echantillons: List[TractionRequest]


class EssaiExcelRequest(BaseModel):
    """Payload générique pour les routes /essais/{type}/...

    - `forme` : code de la forme choisie (cylindre, rectangle, carre,
      tube_circulaire, tube_rectangulaire, surface). Utilisé pour la
      traction et la compression, pour déterminer la formule de section.
    - `geometrie_traction` : peut contenir `section_mm2` et `l0_mm` pour
      les fichiers traction sans feuille de dimensions.
    """
    chemin_fichier: str
    l0_mm: float = 20.0
    geometrie_compression: Optional[Dict[str, Any]] = None
    geometrie_flexion: Optional[Dict[str, Any]] = None
    geometrie_traction: Optional[Dict[str, Any]] = None
    forme: Optional[str] = None
    chemin_modele: Optional[str] = None


class DonneesEssaiRequest(BaseModel):
    donnees: Dict[str, Any]
    l0_mm: float = 20.0
    geometrie_traction: Optional[Dict[str, Any]] = None
    geometrie_compression: Optional[Dict[str, Any]] = None
    geometrie_flexion: Optional[Dict[str, Any]] = None
    forme: Optional[str] = None


# -----------------------------------------------------------------------------
# 3. ENDPOINTS API
# -----------------------------------------------------------------------------
@app.post("/api/calculs/traction")
async def executer_calcul_traction(payload: TractionRequest):
    """Calcule les grandeurs mécaniques (E, Rm, Rp0.2, A%) pour une éprouvette."""
    config = (
        TractionConfig(**payload.config_personnalisee)
        if payload.config_personnalisee
        else TractionConfig()
    )
    calculateur = TractionCalculateur(config=config)
    try:
        return calculateur.analyser(
            deplacement_mm=payload.deplacement,
            force_N=payload.force,
            section_mm2=payload.section_mm2,
            longueur_initiale_mm=payload.longueur_initiale_mm,
        )
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/api/calculs/gamme")
async def executer_calcul_gamme(payload: GammeRequest):
    """Calcule les statistiques agrégées pour une série d'éprouvettes."""
    calculateur = GammeCalculateur()
    donnees = [
        {
            "nom": f"Éprouvette {i + 1}",
            "deplacement": ech.deplacement,
            "force": ech.force,
            "section_mm2": ech.section_mm2,
            "longueur_mm": ech.longueur_initiale_mm,
        }
        for i, ech in enumerate(payload.echantillons)
    ]
    try:
        return calculateur.analyser_gamme(donnees)
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.post("/api/fichier/analyser")
async def analyser_fichier_excel(file: UploadFile = File(...)):
    """Lit un fichier Excel brut issu de la machine de traction."""
    suffixe = os.path.splitext(file.filename)[1] if file.filename else ".xlsx"
    with tempfile.NamedTemporaryFile(
        delete=False,
        suffix=suffixe,
        dir=_temporary_directory(),
    ) as tmp:
        contenu = await file.read()
        tmp.write(contenu)
        tmp_path = tmp.name

    try:
        donnees_classeur = lire_classeur_complet(tmp_path)
        gamme_structuree = lire_gamme_complete(tmp_path)
        return {
            "nom_fichier": file.filename,
            "donnees_brutes": donnees_classeur,
            "gamme_interpretee": gamme_structuree,
        }
    except Exception as e:
        raise HTTPException(
            status_code=422,
            detail=f"Erreur de lecture du fichier Excel : {str(e)}",
        )
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)


@app.post("/api/export/excel")
async def exporter_excel(payload: ExportExcelRequest):
    """Génère la fiche de résultats Excel synthétique."""
    config = (
        TractionConfig(**payload.donnees_traction.config_personnalisee)
        if payload.donnees_traction.config_personnalisee
        else TractionConfig()
    )
    calculateur = TractionCalculateur(config=config)

    resultats = calculateur.analyser(
        deplacement_mm=payload.donnees_traction.deplacement,
        force_N=payload.donnees_traction.force,
        section_mm2=payload.donnees_traction.section_mm2,
        longueur_initiale_mm=payload.donnees_traction.longueur_initiale_mm,
    )

    fichier_sortie = _DATA_DIR / "rapport_genere.xlsx"

    try:
        from moteur_python.export_excel.production_workbook_exporter import exporter_rapport_traction
    except ImportError as e:
        raise HTTPException(
            status_code=501,
            detail="L'export Excel legacy n'est pas disponible dans cette version du moteur.",
        ) from e

    try:
        exporter_rapport_traction(
            chemin_modele_excel=payload.chemin_template,
            chemin_sortie=str(fichier_sortie),
            resultats=resultats,
            mapping_echantillon_zero=payload.mapping_cellules,
        )
        return {
            "status": "success",
            "fichier": fichier_sortie.name,
            "resultats": resultats,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'exportation : {str(e)}",
        )


def _geometrie_essai(
    type_essai: str, payload: EssaiExcelRequest
) -> Optional[Dict[str, Any]]:
    """Renvoie la géométrie à passer à read_workbook / process_workbook.

    - compression : payload.geometrie_compression
    - flexion     : payload.geometrie_flexion
    - traction    : payload.geometrie_traction
    """
    if type_essai == 'compression':
        return payload.geometrie_compression
    if type_essai == 'flexion':
        return payload.geometrie_flexion
    if type_essai == 'traction':
        return payload.geometrie_traction
    return None


@app.post('/essais/{type_essai}/lister-echantillons')
def route_lister_echantillons(type_essai: str, payload: EssaiExcelRequest):
    try:
        return lister_echantillons(payload.chemin_fichier, type_essai)
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.post('/essais/{type_essai}/lire-brut')
def route_lire_donnees_brutes(type_essai: str, payload: EssaiExcelRequest):
    try:
        return lire_donnees_brutes(payload.chemin_fichier, type_essai)
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.post('/essais/{type_essai}/calculer-depuis-excel')
def route_calculer_depuis_excel(type_essai: str, payload: EssaiExcelRequest):
    try:
        donnees = read_workbook(
            payload.chemin_fichier,
            type_essai=type_essai,
            geometrie=_geometrie_essai(type_essai, payload),
            forme=payload.forme,
        )
        return analyser_resultats(donnees, l0_mm=payload.l0_mm)
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.post('/essais/{type_essai}/calculer')
def route_calculer_donnees_capture(
    type_essai: str, payload: DonneesEssaiRequest
):
    if type_essai not in ('traction', 'compression', 'flexion'):
        raise HTTPException(status_code=422, detail=f"type_essai inconnu : {type_essai!r}")
    donnees = dict(payload.donnees)
    donnees['type_essai'] = type_essai

    # Injecter la géométrie UI dans les échantillons qui en manquent.
    # Nécessaire quand les données viennent de la capture SQLite (stockées
    # via lire_donnees_brutes, sans section_mm2 ni l0_mm).
    if type_essai == 'traction':
        geo = payload.geometrie_traction or {}
        section_ui = geo.get('section_mm2')
        l0_ui = float(geo.get('l0_mm') or payload.l0_mm or 20.0)
        for gamme in donnees.get('gammes', []):
            for ech in gamme.get('echantillons', []):
                if 'l0_mm' not in ech or ech['l0_mm'] is None:
                    ech['l0_mm'] = l0_ui
                if 'section_mm2' not in ech or ech['section_mm2'] is None:
                    if section_ui is not None:
                        ech['section_mm2'] = float(section_ui)
        # Filtrer les échantillons sans section (ne peuvent pas être calculés)
        for gamme in donnees.get('gammes', []):
            gamme['echantillons'] = [
                e for e in gamme['echantillons']
                if 'section_mm2' in e and e['section_mm2'] is not None
            ]
        donnees['gammes'] = [
            g for g in donnees.get('gammes', []) if g['echantillons']
        ]
        if not donnees.get('gammes'):
            raise HTTPException(
                status_code=422,
                detail=(
                    "Aucun échantillon calculable : la section transversale "
                    "(section_mm2) est manquante. Renseignez-la dans "
                    "geometrie_traction.section_mm2."
                ),
            )

    elif type_essai == 'compression':
        geo = payload.geometrie_compression or {}
        for gamme in donnees.get('gammes', []):
            for ech in gamme.get('echantillons', []):
                if 'l0_mm' not in ech or ech['l0_mm'] is None:
                    l0 = geo.get('l0_mm') or payload.l0_mm
                    if l0:
                        ech['l0_mm'] = float(l0)
                if 'section_mm2' not in ech or ech['section_mm2'] is None:
                    sec = geo.get('section_mm2')
                    if sec is not None:
                        ech['section_mm2'] = float(sec)

    elif type_essai == 'flexion':
        geo = payload.geometrie_flexion or {}
        if geo:
            donnees['geometrie_flexion'] = geo

    try:
        return analyser_resultats(donnees, l0_mm=payload.l0_mm)
    except (KeyError, TypeError, ValueError) as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@app.post('/essais/{type_essai}/exporter-excel')
def route_exporter_essai_excel(type_essai: str, payload: EssaiExcelRequest):
    if type_essai not in ('traction', 'compression', 'flexion'):
        raise HTTPException(status_code=422, detail=f"type_essai inconnu : {type_essai!r}")

    modele_defaut = _RESOURCE_ROOT.joinpath(
        'moteur_python',
        'modeles',
        f'MODELE_{type_essai.upper()}_VIDE.xlsx',
    )
    chemin_modele = payload.chemin_modele or str(modele_defaut)

    try:
        with tempfile.TemporaryDirectory(
            prefix='pycnolab_export_',
            dir=_temporary_directory(),
        ) as dossier_temporaire:
            chemin_sortie = os.path.join(dossier_temporaire, 'rapport.xlsx')
            process_workbook(
                input_path=payload.chemin_fichier,
                template_path=chemin_modele,
                output_path=chemin_sortie,
                type_essai=type_essai,
                l0_mm=payload.l0_mm,
                geometrie=_geometrie_essai(type_essai, payload),
                forme=payload.forme,
            )
            contenu = Path(chemin_sortie).read_bytes()
    except FileNotFoundError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error
    except ValueError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error

    return Response(
        content=contenu,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={'Content-Disposition': f'attachment; filename="RAPPORT_{type_essai.upper()}.xlsx"'},
    )


if __name__ == "__main__":
    from pycnolab_engine import main

    main()