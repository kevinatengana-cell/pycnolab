from io import BytesIO
from pathlib import Path
from typing import Optional

import openpyxl
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

from ..import_excel.reader import lire_gamme_complete
from moteur_python.calculs.traction import TractionCalculateur
from moteur_python.modeles.models import (
    ConditionsAmbiantes,
    Echantillon,
    FamilleMateriau,
    Gamme,
    Materiau,
    Norme,
    PointCourbe,
)

from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="PycnoLab Engine API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class MateriauRequest(BaseModel):
    nom_usage: str
    code_interne: str
    famille: str = "autre"


class NormeRequest(BaseModel):
    code: str
    designation: str
    seuil_resistance_min_mpa: Optional[float] = None
    seuil_allongement_min_pourcent: Optional[float] = None


class ConditionsRequest(BaseModel):
    temperature_celsius: Optional[float] = None
    humidite_pourcent: Optional[float] = None
    duree_conditionnement_heures: Optional[float] = None


class PointCourbeRequest(BaseModel):
    force_newton: float
    deplacement_mm: float


class EchantillonRequest(BaseModel):
    identifiant: str
    longueur_initiale_mm: float
    largeur_mm: Optional[float] = None
    epaisseur_mm: Optional[float] = None
    diametres_mm: list[float] = []
    force_rupture_newton: Optional[float] = None
    deplacement_rupture_mm: Optional[float] = None
    points_courbe: list[PointCourbeRequest] = []
    parametres_extra: dict[str, float] = {}


class GammeRequest(BaseModel):
    materiau: MateriauRequest
    norme: NormeRequest
    conditions: ConditionsRequest
    echantillons: list[EchantillonRequest]
    calculs_demandes: list[str] = []


class ImportExcelRequest(BaseModel):
    """
    Le Flutter actuel (python_engine_service.dart) n'envoie que le
    chemin du fichier. materiau/norme/conditions sont optionnels ici
    pour ne pas casser cet appel existant - à défaut, des valeurs
    placeholder sont utilisées (voir _to_domain_gamme plus bas).
    A terme : Flutter devrait les envoyer (formulaire avant import, ou
    métadonnées lues depuis le fichier lui-même).
    """
    chemin_fichier: str
    materiau: Optional[MateriauRequest] = None
    norme: Optional[NormeRequest] = None
    conditions: Optional[ConditionsRequest] = None
    calculs_demandes: list[str] = []


def _famille_enum(famille: str) -> FamilleMateriau:
    mapping = {item.value: item for item in FamilleMateriau}
    return mapping.get(famille.lower(), FamilleMateriau.AUTRE)


def _to_domain_gamme(gamme: GammeRequest) -> Gamme:
    return Gamme(
        materiau=Materiau(
            nom_usage=gamme.materiau.nom_usage,
            code_interne=gamme.materiau.code_interne,
            famille=_famille_enum(gamme.materiau.famille),
        ),
        norme=Norme(
            code=gamme.norme.code,
            designation=gamme.norme.designation,
            seuil_resistance_min_mpa=gamme.norme.seuil_resistance_min_mpa,
            seuil_allongement_min_pourcent=gamme.norme.seuil_allongement_min_pourcent,
        ),
        conditions=ConditionsAmbiantes(
            temperature_celsius=gamme.conditions.temperature_celsius,
            humidite_pourcent=gamme.conditions.humidite_pourcent,
            duree_conditionnement_heures=gamme.conditions.duree_conditionnement_heures,
        ),
        echantillons=[
            Echantillon(
                identifiant=e.identifiant,
                longueur_initiale_mm=e.longueur_initiale_mm,
                largeur_mm=e.largeur_mm,
                epaisseur_mm=e.epaisseur_mm,
                diametres_mm=e.diametres_mm,
                force_rupture_newton=e.force_rupture_newton,
                deplacement_rupture_mm=e.deplacement_rupture_mm,
                points_courbe=[
                    PointCourbe(
                        force_newton=p.force_newton,
                        deplacement_mm=p.deplacement_mm,
                    )
                    for p in e.points_courbe
                ],
            )
            for e in gamme.echantillons
        ],
        calculs_demandes=gamme.calculs_demandes,
    )


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


# Format imposé pour l'import Excel/CSV : une ligne par échantillon.
# Ne couvre pas encore les courbes complètes (points_courbe) - à
# concevoir séparément une fois qu'un vrai fichier d'export machine
# sera disponible pour référence.

def _parse_diametres_cell(cell_value: object) -> list[float]:
    if pd.isna(cell_value):
        return []
    if isinstance(cell_value, (int, float)):
        return [float(cell_value)]
    raw = str(cell_value).strip()
    if not raw:
        return []
    separators = [";", ",", " "]
    for sep in separators:
        if sep in raw:
            parts = [part.strip() for part in raw.split(sep) if part.strip()]
            try:
                return [float(part) for part in parts]
            except ValueError:
                break
    try:
        return [float(raw)]
    except ValueError as exc:
        raise ValueError(f"Valeur de diametres_mm invalide : {cell_value}") from exc


def _est_format_excel_complet(chemin: str) -> bool:
    if chemin.lower().endswith(".csv"):
        return False
    try:
        xl = pd.ExcelFile(chemin)
    except Exception:
        return False

    feuilles = {nom.strip().upper() for nom in xl.sheet_names}
    return {"INFO", "DIAMETRES", "COURBE"}.issubset(feuilles)


def _lire_echantillons_depuis_fichier(chemin: str) -> list[EchantillonRequest]:
    if chemin.lower().endswith(".csv"):
        df = pd.read_csv(chemin, sep=None, engine="python")
    else:
        df = pd.read_excel(chemin, sheet_name=0)

    colonnes_rectangulaire = [
        "identifiant",
        "longueur_initiale_mm",
        "largeur_mm",
        "epaisseur_mm",
        "force_rupture_newton",
        "deplacement_rupture_mm",
    ]
    colonnes_circulaire = [
        "identifiant",
        "longueur_initiale_mm",
        "diametres_mm",
        "force_rupture_newton",
        "deplacement_rupture_mm",
    ]

    colonnes_presentes = set(df.columns)
    format_circulaire = "diametres_mm" in colonnes_presentes
    format_rectangulaire = {
        "largeur_mm",
        "epaisseur_mm",
    }.issubset(colonnes_presentes)

    if format_circulaire:
        colonnes_attendues = colonnes_circulaire
    elif format_rectangulaire:
        colonnes_attendues = colonnes_rectangulaire
    else:
        raise HTTPException(
            status_code=422,
            detail=(
                "Fichier Excel/CSV invalide : le fichier doit contenir soit "
                "les colonnes pour une section rectangulaire (largeur_mm, "
                "epaisseur_mm), soit la colonne diametres_mm pour une section "
                "circulaire, en plus des champs identifiant, longueur_initiale_mm, "
                "force_rupture_newton et deplacement_rupture_mm."
            ),
        )

    colonnes_manquantes = [c for c in colonnes_attendues if c not in colonnes_presentes]
    if colonnes_manquantes:
        raise HTTPException(
            status_code=422,
            detail=(
                f"Colonnes manquantes dans le fichier : {colonnes_manquantes}. "
                f"Colonnes attendues (dans cet ordre ou non) : {colonnes_attendues}"
            ),
        )

    echantillons = []
    for _, ligne in df.iterrows():
        diametres = _parse_diametres_cell(ligne["diametres_mm"]) if format_circulaire else []
        echantillons.append(
            EchantillonRequest(
                identifiant=str(ligne["identifiant"]),
                longueur_initiale_mm=float(ligne["longueur_initiale_mm"]),
                largeur_mm=float(ligne["largeur_mm"]) if format_rectangulaire else None,
                epaisseur_mm=float(ligne["epaisseur_mm"]) if format_rectangulaire else None,
                diametres_mm=diametres,
                force_rupture_newton=float(ligne["force_rupture_newton"]),
                deplacement_rupture_mm=float(ligne["deplacement_rupture_mm"]),
            )
        )
    return echantillons


@app.post("/essais/traction/calculer-depuis-excel")
def calculer_depuis_excel(requete: ImportExcelRequest) -> dict:
    """
    Format SIMPLE : une ligne par échantillon, section rectangulaire,
    pas de courbe complète (donc pas de module d'Young calculable).
    Voir _COLONNES_ATTENDUES ci-dessus pour les colonnes exactes.
    """
    if not Path(requete.chemin_fichier).exists():
        raise HTTPException(
            status_code=404,
            detail=f"Fichier introuvable : {requete.chemin_fichier}",
        )

    if _est_format_excel_complet(requete.chemin_fichier):
        try:
            donnees = lire_gamme_complete(requete.chemin_fichier)
        except (KeyError, ValueError) as e:
            raise HTTPException(
                status_code=422,
                detail=f"Erreur de format dans le fichier : {e}",
            )
        gamme = GammeRequest(**donnees)
    else:
        echantillons = _lire_echantillons_depuis_fichier(requete.chemin_fichier)
        gamme = GammeRequest(
            materiau=requete.materiau
            or MateriauRequest(nom_usage="À définir", code_interne="TEMP", famille="autre"),
            norme=requete.norme or NormeRequest(code="À définir", designation="À définir"),
            conditions=requete.conditions or ConditionsRequest(),
            echantillons=echantillons,
            calculs_demandes=requete.calculs_demandes,
        )

    return calculer_traction(gamme)


@app.post("/essais/traction/calculer-depuis-excel-complet")
def calculer_depuis_excel_complet(requete: ImportExcelRequest) -> dict:
    """
    Format COMPLET : 3 feuilles (INFO, DIAMETRES, COURBE), section
    circulaire via 3 diamètres, courbe complète par échantillon donc
    module d'Young calculable. Voir lecteur_excel_complet.py pour le
    détail du format attendu.
    """
    if not Path(requete.chemin_fichier).exists():
        raise HTTPException(
            status_code=404,
            detail=f"Fichier introuvable : {requete.chemin_fichier}",
        )

    try:
        donnees = lire_gamme_complete(requete.chemin_fichier)
    except (KeyError, ValueError) as e:
        raise HTTPException(
            status_code=422,
            detail=f"Erreur de format dans le fichier : {e}",
        )

    gamme = GammeRequest(**donnees)
    return calculer_traction(gamme)


@app.post("/essais/traction/calculer")
def calculer_traction(gamme: GammeRequest) -> dict:
    domaine = _to_domain_gamme(gamme)
    resultat = TractionCalculateur().calculer(domaine)

    # On renvoie aussi les données d'entrée (dimensions, force, déplacement)
    # par échantillon afin que l'UI Flutter puisse afficher les valeurs
    # brutes (section, force, déplacement) sans ambiguïté.
    # Build per-sample detailed entries combining results and raw inputs
    resultats = []
    for r, ech in zip(resultat.resultats_echantillons, resultat.gamme.echantillons):
        try:
            section_val = ech.section_mm2()
        except Exception:
            section_val = None
        resultats.append(
            {
                "identifiant": r.identifiant,
                "contrainte_rupture_mpa": r.contrainte_rupture_mpa,
                "deformation_rupture_pourcent": r.deformation_rupture_pourcent,
                "module_young_mpa": r.module_young_mpa,
                "energie_rupture_joules": r.energie_rupture_joules,
                "limite_elastique_mpa": r.limite_elastique_mpa,
                # Valeurs d'entrée
                "longueur_initiale_mm": ech.longueur_initiale_mm,
                "largeur_mm": ech.largeur_mm,
                "epaisseur_mm": ech.epaisseur_mm,
                "diametres_mm": ech.diametres_mm,
                "force_rupture_newton": ech.force_rupture_newton,
                "deplacement_rupture_mm": ech.deplacement_rupture_mm,
                "points_courbe": [{"force_newton": p.force_newton, "deplacement_mm": p.deplacement_mm} for p in ech.points_courbe],
                # Section calculée côté serveur (utile pour affichage direct)
                "section_mm2": section_val,
            }
        )

    # Statistics object expected by the Flutter UI
    # Calculer la moyenne des allongements (%) si disponible
    deformations = [r.deformation_rupture_pourcent for r in resultat.resultats_echantillons if r.deformation_rupture_pourcent is not None]
    epsilon_moyen = float(sum(deformations) / len(deformations)) if deformations else 0.0

    statistiques = {
        "sigma_moyenne": resultat.resistance_moyenne_mpa,
        "sigma_ecart_type": resultat.ecart_type_mpa,
        "epsilon_moyen": epsilon_moyen,
        "epsilon_ecart_type": resultat.ecart_type_deformation_pourcent,
        "module_young_ecart_type_mpa": resultat.ecart_type_module_young_mpa,
    }

    return {
        "materiau_nom": resultat.gamme.materiau.nom_usage,
        "norme_code": resultat.gamme.norme.code,
        "horodatage": resultat.gamme.horodatage.isoformat(),
        # Liste nommée 'resultats_echantillons' (compatibilité) et 'echantillons'
        # (format attendu par l'UI). On fournit les deux pour compatibilité.
        "resultats_echantillons": resultats,
        "echantillons": resultats,
        "statistiques": statistiques,
        "resistance_moyenne_mpa": resultat.resistance_moyenne_mpa,
        "ecart_type_mpa": resultat.ecart_type_mpa,
        "module_young_moyen_mpa": resultat.module_young_moyen_mpa,
        "ecart_type_module_young_mpa": resultat.ecart_type_module_young_mpa,
        "deformation_moyenne_pourcent": resultat.deformation_moyenne_pourcent,
        "ecart_type_deformation_pourcent": resultat.ecart_type_deformation_pourcent,
        "energie_rupture_moyenne_joules": resultat.energie_rupture_moyenne_joules,
        "limite_elastique_moyenne_mpa": resultat.limite_elastique_moyenne_mpa,
        "statut": resultat.statut.value,
    }


@app.post("/essais/traction/export-excel")
def export_excel(gamme: GammeRequest, type_graphique: str = "barres") -> Response:
    del type_graphique
    domaine = _to_domain_gamme(gamme)
    resultat = TractionCalculateur().calculer(domaine)

    workbook = openpyxl.Workbook()
    worksheet = workbook.active
    worksheet.title = "Résultats"
    worksheet.append(["Échantillon", "Contrainte (MPa)", "Déformation (%)", "Module (MPa)"])

    for item in resultat.resultats_echantillons:
        worksheet.append(
            [
                item.identifiant,
                item.contrainte_rupture_mpa,
                item.deformation_rupture_pourcent,
                item.module_young_mpa,
            ]
        )

    buffer = BytesIO()
    workbook.save(buffer)
    buffer.seek(0)

    return Response(
        content=buffer.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=PV.xlsx"},
    )