<<<<<<< HEAD
from io import BytesIO
from pathlib import Path
from typing import Optional

import openpyxl
import pandas as pd
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
=======
"""
API FastAPI - PycnoLab, moteur de calcul essais de traction.
Reconstruit intégralement après une régression ayant fait disparaître
la plupart des routes (seuls /health et un endpoint de simulation
codé en dur subsistaient).
"""
from io import BytesIO
from pathlib import Path
from typing import Optional
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)

import openpyxl
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response
from pydantic import BaseModel, Field

from moteur_python.import_excel.reader import lire_gamme_complete
from moteur_python.protocoles.extraction.extract_norm_pdf import run_extraction
from moteur_python.calculs.traction import TractionCalculateur
from moteur_python.calculs.compression import CompressionCalculateur
from moteur_python.calculs.protocole import MoteurProtocole
from moteur_python.export_excel.rapport_labo import generer_rapport_labo
from moteur_python.modeles.models import (
    ConditionsAmbiantes,
    Echantillon,
    FamilleMateriau,
    Gamme,
    Materiau,
    Norme,
    PointCourbe,
    ResultatGamme,
)

app = FastAPI(title="PycnoLab Engine API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Schémas de requête (ce que Flutter envoie)
# ---------------------------------------------------------------------------

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
    # Le Dart actuel (gamme_request.dart) envoie un diamètre UNIQUE
    # ("diametre_mm"), pas une liste - converti en liste à 1 élément
    # en interne pour rester compatible avec Echantillon.diametres_mm.
    diametre_mm: Optional[float] = None
    force_rupture_newton: Optional[float] = None
    deplacement_rupture_mm: Optional[float] = None
    points_courbe: list[PointCourbeRequest] = Field(default_factory=list)
    parametres_extra: dict[str, float] = Field(default_factory=dict)


class GammeRequest(BaseModel):
    materiau: MateriauRequest
    norme: NormeRequest
    conditions: ConditionsRequest
    echantillons: list[EchantillonRequest]
<<<<<<< HEAD
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
=======
    calculs_demandes: list[str] = Field(default_factory=list)


class ImportExcelRequest(BaseModel):
    """Corps de requête pour les imports Excel. materiau/norme/conditions
    sont optionnels - si absents (cas actuel du Flutter), des valeurs
    provenant du fichier ou des valeurs par défaut sont utilisées."""
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
    chemin_fichier: str
    materiau: Optional[MateriauRequest] = None
    norme: Optional[NormeRequest] = None
    conditions: Optional[ConditionsRequest] = None
<<<<<<< HEAD
    calculs_demandes: list[str] = []
=======
    calculs_demandes: list[str] = Field(default_factory=list)
    # Champ ignoré s'il est envoyé (Flutter inclut parfois une liste vide
    # "echantillons" issue de GammeRequest.toJson() par réutilisation) -
    # Pydantic l'ignore silencieusement, pas besoin de le déclarer.


# ---------------------------------------------------------------------------
# Conversion requête -> objets métier
# ---------------------------------------------------------------------------

class ExtractionNormePdfRequest(BaseModel):
    chemin_fichier: str

class ExecProtocoleRequest(BaseModel):
    chemin_protocole: str
    chemin_fichier: str
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)


def _famille_enum(famille: str) -> FamilleMateriau:
    mapping = {item.value: item for item in FamilleMateriau}
<<<<<<< HEAD
    return mapping.get(famille.lower(), FamilleMateriau.AUTRE)
=======
    return mapping.get((famille or "autre").lower(), FamilleMateriau.AUTRE)
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)


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
<<<<<<< HEAD
=======
        calculs_demandes=gamme.calculs_demandes,
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
        echantillons=[
            Echantillon(
                identifiant=e.identifiant,
                longueur_initiale_mm=e.longueur_initiale_mm,
                largeur_mm=e.largeur_mm,
                epaisseur_mm=e.epaisseur_mm,
<<<<<<< HEAD
                diametres_mm=e.diametres_mm,
                force_rupture_newton=e.force_rupture_newton,
                deplacement_rupture_mm=e.deplacement_rupture_mm,
                points_courbe=[
                    PointCourbe(
                        force_newton=p.force_newton,
                        deplacement_mm=p.deplacement_mm,
                    )
=======
                diametres_mm=[e.diametre_mm] if e.diametre_mm is not None else [],
                force_rupture_newton=e.force_rupture_newton,
                deplacement_rupture_mm=e.deplacement_rupture_mm,
                points_courbe=[
                    PointCourbe(force_newton=p.force_newton, deplacement_mm=p.deplacement_mm)
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
                    for p in e.points_courbe
                ],
            )
            for e in gamme.echantillons
        ],
<<<<<<< HEAD
        calculs_demandes=gamme.calculs_demandes,
    )


=======
        )


def _gamme_depuis_fichier(chemin: str, requete: ImportExcelRequest) -> Gamme:
    """Lit le fichier Excel via reader.py, construit une Gamme complète.
    Seules les données BRUTES du reader sont utilisées (identifiant,
    diamètres, courbe, L0) - contrainte/module/etc. sont toujours
    recalculés par TractionCalculateur, jamais repris tels quels du
    reader, pour garantir une seule source de vérité pour les calculs."""
    donnees = lire_gamme_complete(chemin)

    materiau_req = requete.materiau
    if materiau_req is None or materiau_req.nom_usage.strip().lower() in {"", "\u00e0 d\u00e9finir"}:
        materiau_req = MateriauRequest(
            nom_usage=donnees.get("materiau_nom", "À définir"),
            code_interne=Path(chemin).stem,
            famille="autre",
        )
    norme_req = requete.norme or NormeRequest(
        code=donnees.get("norme_code", "À définir"),
        designation=donnees.get("norme_code", "À définir"),
        )
    conditions_req = requete.conditions or ConditionsRequest()

    echantillons = [
        Echantillon(
            identifiant=e["identifiant"],
            longueur_initiale_mm=e["longueur_initiale_mm"],
            diametres_mm=e["diametres_mm"],
            force_rupture_newton=e.get("force_rupture_newton"),
            deplacement_rupture_mm=e.get("deplacement_rupture_mm"),
            points_courbe=[
                PointCourbe(force_newton=p["force_newton"], deplacement_mm=p["deplacement_mm"])
                for p in e["points_courbe"]
            ],
        )
        for e in donnees["echantillons"]
    ]

    return Gamme(
        materiau=Materiau(
            nom_usage=materiau_req.nom_usage,
            code_interne=materiau_req.code_interne,
            famille=_famille_enum(materiau_req.famille),
        ),
        norme=Norme(
            code=norme_req.code,
            designation=norme_req.designation,
            seuil_resistance_min_mpa=norme_req.seuil_resistance_min_mpa,
            seuil_allongement_min_pourcent=norme_req.seuil_allongement_min_pourcent,
        ),
        conditions=ConditionsAmbiantes(
            temperature_celsius=conditions_req.temperature_celsius,
            humidite_pourcent=conditions_req.humidite_pourcent,
            duree_conditionnement_heures=conditions_req.duree_conditionnement_heures,
        ),
        calculs_demandes=requete.calculs_demandes,
        echantillons=echantillons,
        )


def _resultat_vers_json(resultat: ResultatGamme) -> dict:
    """Sérialise un ResultatGamme vers le JSON attendu par
    resultat_gamme.dart (noms de clés exacts, y compris les singuliers/
    pluriels qui diffèrent entre le modèle Python et le modèle Dart)."""
    return {
        "materiau_nom": resultat.gamme.materiau.nom_usage,
        "norme_code": resultat.gamme.norme.code,
        "horodatage": resultat.gamme.horodatage.isoformat(),
        "statut": resultat.statut.value,
        "resistance_moyenne_mpa": resultat.resistance_moyenne_mpa,
        "ecart_type_mpa": resultat.ecart_type_mpa,
        "module_young_moyen_mpa": resultat.module_young_moyen_mpa,
        "deformation_moyenne_pourcent": resultat.deformation_moyenne_pourcent,
        "ecart_type_deformation_pourcent": resultat.ecart_type_deformation_pourcent,
        "ecart_type_module_young_mpa": resultat.ecart_type_module_young_mpa,
        "energie_rupture_moyenne_joules": resultat.energie_rupture_moyenne_joules,
        "limite_elastique_moyenne_mpa": resultat.limite_elastique_moyenne_mpa,
        "resultats_echantillons": [
            {
                "identifiant": r.identifiant,
                "contrainte_rupture_mpa": r.contrainte_rupture_mpa,
                "deformation_rupture_pourcent": r.deformation_rupture_pourcent,
                "module_young_mpa": r.module_young_mpa,
                "force_max_newton": r.force_max_newton,
                "energie_rupture_joule": r.energie_rupture_joules,
                "limite_elastique_mpa": r.limite_elastique_mpa,
                "section_mm2": next(
                    (e.section_mm2() for e in resultat.gamme.echantillons if e.identifiant == r.identifiant),
                    None,
                ),
                # Nécessaire pour le graphique de courbe détaillée par
                # échantillon côté Flutter (_buildCourbeTraction) - oublié
                # dans une première version, ce qui laissait le graphique
                # vide malgré des valeurs numériques correctes.
                "points_courbe": [
                    {"force_newton": p.force_newton, "deplacement_mm": p.deplacement_mm}
                    for e in resultat.gamme.echantillons
                    if e.identifiant == r.identifiant
                    for p in e.points_courbe
                ],
            }
            for r in resultat.resultats_echantillons
        ],
    }


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

@app.post("/protocoles/extraction/pdf")
def extraire_norme_pdf(requete: ExtractionNormePdfRequest) -> dict:
    """Builds a local, deterministic protocol draft from a text-based PDF."""
    chemin = Path(requete.chemin_fichier).expanduser()
    if not chemin.is_file():
        raise HTTPException(status_code=404, detail="Fichier PDF introuvable.")
    if chemin.suffix.lower() != ".pdf":
        raise HTTPException(status_code=422, detail="Le fichier doit etre un PDF.")

    try:
        return run_extraction(chemin)
    except RuntimeError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=422,
            detail=f"Extraction du PDF impossible : {exc}",
        ) from exc

@app.post("/protocoles/executer")
@app.post("/api/v1/protocoles/executer")
def executer_protocole(requete: ExecProtocoleRequest) -> dict:
    import json
    
    # Résolution explicite en chemin absolu
    chemin_proto = Path(requete.chemin_protocole).expanduser().resolve()
    chemin_excel = Path(requete.chemin_fichier).expanduser().resolve()
    
    if not chemin_proto.exists():
        raise HTTPException(
            status_code=404, 
            detail=f"Fichier protocole introuvable sur le disque : {chemin_proto}"
        )
    if not chemin_excel.exists():
        raise HTTPException(
            status_code=404, 
            detail=f"Fichier Excel introuvable sur le disque : {chemin_excel}"
        )

    try:
        with open(chemin_proto, "r", encoding="utf-8") as f:
            protocole_dict = json.load(f)
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Protocole JSON invalide : {e}")

    try:
        domaine = _gamme_depuis_fichier(str(chemin_excel), ImportExcelRequest(chemin_fichier=str(chemin_excel)))
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Erreur d'import Excel : {e}")

    try:
        moteur = MoteurProtocole(protocole_dict)
        resultat = moteur.calculer(domaine)
        return _resultat_vers_json(resultat)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Échec de l'exécution : {e}")

>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


<<<<<<< HEAD
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
=======
@app.post("/essais/traction/calculer")
def calculer_traction(gamme: GammeRequest) -> dict:
    domaine = _to_domain_gamme(gamme)
    resultat = TractionCalculateur().calculer(domaine)
    return _resultat_vers_json(resultat)
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)


@app.post("/essais/traction/calculer-depuis-excel-complet")
def calculer_depuis_excel_complet(requete: ImportExcelRequest) -> dict:
    """
<<<<<<< HEAD
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
=======
    Format COMPLET : fichier Excel avec feuilles INFO/DIAMETRES/COURBE
    (voir reader.py). Lit réellement le fichier - remplace l'ancien
    endpoint qui renvoyait des valeurs simulées codées en dur.
    """
    if not Path(requete.chemin_fichier).exists():
        raise HTTPException(status_code=404, detail=f"Fichier introuvable : {requete.chemin_fichier}")

    try:
        domaine = _gamme_depuis_fichier(requete.chemin_fichier, requete)
    except (KeyError, ValueError, FileNotFoundError) as e:
        raise HTTPException(status_code=422, detail=f"Erreur de format dans le fichier : {e}")

    resultat = TractionCalculateur().calculer(domaine)
    return _resultat_vers_json(resultat)


# ---------------------------------------------------------------------------
# Compression - ajouté sans toucher aux routes traction ci-dessus.
# Les fonctions _to_domain_gamme / _gamme_depuis_fichier / _resultat_vers_json
# sont déjà indépendantes du type d'essai (elles ne mentionnent jamais
# "traction") - seul le choix du Calculateur change ici. C'est la preuve
# concrète que l'architecture en briques se généralise sans duplication.
# ---------------------------------------------------------------------------

@app.post("/essais/compression/calculer")
def calculer_compression(gamme: GammeRequest) -> dict:
    domaine = _to_domain_gamme(gamme)
    resultat = CompressionCalculateur().calculer(domaine)
    return _resultat_vers_json(resultat)


@app.post("/essais/compression/calculer-depuis-excel-complet")
def calculer_compression_depuis_excel_complet(requete: ImportExcelRequest) -> dict:
    if not Path(requete.chemin_fichier).exists():
        raise HTTPException(status_code=404, detail=f"Fichier introuvable : {requete.chemin_fichier}")

    try:
        domaine = _gamme_depuis_fichier(requete.chemin_fichier, requete)
    except (KeyError, ValueError, FileNotFoundError) as e:
        raise HTTPException(status_code=422, detail=f"Erreur de format dans le fichier : {e}")

    resultat = CompressionCalculateur().calculer(domaine)
    return _resultat_vers_json(resultat)


@app.post("/essais/traction/export-excel")
def export_excel(gamme: GammeRequest) -> Response:
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
    domaine = _to_domain_gamme(gamme)
    resultat = TractionCalculateur().calculer(domaine)

    workbook = openpyxl.Workbook()
    worksheet = workbook.active
    worksheet.title = "Résultats"
    worksheet.append(["Échantillon", "Contrainte (MPa)", "Déformation (%)", "Module (MPa)"])
<<<<<<< HEAD

    for item in resultat.resultats_echantillons:
        worksheet.append(
            [
                item.identifiant,
                item.contrainte_rupture_mpa,
                item.deformation_rupture_pourcent,
                item.module_young_mpa,
            ]
        )
=======
    for item in resultat.resultats_echantillons:
        worksheet.append([
            item.identifiant, item.contrainte_rupture_mpa,
            item.deformation_rupture_pourcent, item.module_young_mpa,
        ])
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)

    buffer = BytesIO()
    workbook.save(buffer)
    buffer.seek(0)
<<<<<<< HEAD

=======
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
    return Response(
        content=buffer.getvalue(),
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=PV.xlsx"},
<<<<<<< HEAD
    )
=======
        )


@app.post("/essais/traction/rapport-labo")
def rapport_labo(chemins_fichiers: list[str]) -> Response:
    """Génère le rapport multi-feuilles (DIAMETRES, une feuille par
    gamme, RECAPITULATIF avec graphiques) à partir de fichiers déjà
    importés, relus et recalculés ici."""
    if not chemins_fichiers:
        raise HTTPException(status_code=422, detail="Aucun fichier fourni.")

    resultats = []
    for chemin in chemins_fichiers:
        if not Path(chemin).exists():
            raise HTTPException(status_code=404, detail=f"Fichier introuvable : {chemin}")
        try:
            domaine = _gamme_depuis_fichier(chemin, ImportExcelRequest(chemin_fichier=chemin))
        except (KeyError, ValueError) as e:
            raise HTTPException(status_code=422, detail=f"Erreur de format dans {chemin} : {e}")
        resultats.append(TractionCalculateur().calculer(domaine))

    import tempfile, os
    with tempfile.NamedTemporaryFile(suffix=".xlsx", delete=False) as tmp:
        chemin_temp = tmp.name
    try:
        generer_rapport_labo(resultats, chemin_temp)
        with open(chemin_temp, "rb") as f:
            contenu = f.read()
    finally:
        os.remove(chemin_temp)

    return Response(
        content=contenu,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": "attachment; filename=rapport_labo.xlsx"},
        )


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8123)
>>>>>>> b15a319 (Fix: corrections execution protocole et endpoints api)
