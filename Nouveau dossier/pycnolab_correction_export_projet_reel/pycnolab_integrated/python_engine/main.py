from io import BytesIO
from pathlib import Path
from typing import Optional

import openpyxl
from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel, Field

from moteur_python.calculs.compression import CompressionCalculateur
from moteur_python.calculs.protocole import MoteurProtocole
from moteur_python.calculs.traction import TractionCalculateur
from moteur_python.export_excel.rapport_labo import generer_rapport_labo
from moteur_python.export_excel.production_workbook_exporter import process_workbook
from moteur_python.import_excel.reader import lire_gamme_complete
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

app = FastAPI(title='PycnoLab Engine API')


class MateriauRequest(BaseModel):
    nom_usage: str
    code_interne: str
    famille: str = 'autre'


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
    diametre_mm: Optional[float] = None
    diametres_mm: list[float] = Field(default_factory=list)
    force_rupture_newton: Optional[float] = None
    deplacement_rupture_mm: Optional[float] = None
    points_courbe: list[PointCourbeRequest] = Field(default_factory=list)
    parametres_extra: dict[str, float] = Field(default_factory=dict)


class GammeRequest(BaseModel):
    materiau: MateriauRequest
    norme: NormeRequest
    conditions: ConditionsRequest = Field(default_factory=ConditionsRequest)
    echantillons: list[EchantillonRequest] = Field(default_factory=list)
    calculs_demandes: list[str] = Field(default_factory=list)


class ImportExcelRequest(BaseModel):
    chemin_fichier: str
    materiau: Optional[MateriauRequest] = None
    norme: Optional[NormeRequest] = None
    conditions: Optional[ConditionsRequest] = None
    calculs_demandes: list[str] = Field(default_factory=list)


class ExecProtocoleRequest(BaseModel):
    chemin_protocole: str
    chemin_fichier: str


class ExportExcelRequest(BaseModel):
    chemin_fichier: str
    l0_mm: float = 20.0


def _famille_enum(value: str) -> FamilleMateriau:
    return next((item for item in FamilleMateriau if item.value == (value or 'autre').lower()), FamilleMateriau.AUTRE)


def _to_domain_gamme(request: GammeRequest) -> Gamme:
    samples = []
    for item in request.echantillons:
        diameters = list(item.diametres_mm)
        if not diameters and item.diametre_mm is not None:
            diameters = [item.diametre_mm]
        samples.append(Echantillon(
            identifiant=item.identifiant,
            longueur_initiale_mm=item.longueur_initiale_mm,
            largeur_mm=item.largeur_mm,
            epaisseur_mm=item.epaisseur_mm,
            diametres_mm=diameters,
            force_rupture_newton=item.force_rupture_newton,
            deplacement_rupture_mm=item.deplacement_rupture_mm,
            points_courbe=[PointCourbe(force_newton=p.force_newton, deplacement_mm=p.deplacement_mm) for p in item.points_courbe],
        ))
    return Gamme(
        materiau=Materiau(request.materiau.nom_usage, request.materiau.code_interne, _famille_enum(request.materiau.famille)),
        norme=Norme(request.norme.code, request.norme.designation, request.norme.seuil_resistance_min_mpa, request.norme.seuil_allongement_min_pourcent),
        conditions=ConditionsAmbiantes(
            request.conditions.temperature_celsius,
            request.conditions.humidite_pourcent,
            request.conditions.duree_conditionnement_heures,
        ),
        echantillons=samples,
        calculs_demandes=request.calculs_demandes,
    )


def _from_excel(request: ImportExcelRequest) -> Gamme:
    payload = lire_gamme_complete(request.chemin_fichier)
    if request.materiau is not None:
        payload['materiau'] = request.materiau.model_dump()
    if request.norme is not None:
        payload['norme'] = request.norme.model_dump()
    if request.conditions is not None:
        payload['conditions'] = request.conditions.model_dump()
    payload['calculs_demandes'] = request.calculs_demandes
    return _to_domain_gamme(GammeRequest.model_validate(payload))


def _resultat_json(result: ResultatGamme) -> dict:
    samples = []
    for calculated, source in zip(result.resultats_echantillons, result.gamme.echantillons):
        samples.append({
            'identifiant': calculated.identifiant,
            'contrainte_rupture_mpa': calculated.contrainte_rupture_mpa,
            'deformation_rupture_pourcent': calculated.deformation_rupture_pourcent,
            'module_young_mpa': calculated.module_young_mpa,
            'force_max_newton': source.force_rupture_newton,
            'energie_rupture_joule': calculated.energie_rupture_joules,
            'limite_elastique_mpa': calculated.limite_elastique_mpa,
            'section_mm2': source.section_mm2(),
            'longueur_initiale_mm': source.longueur_initiale_mm,
            'largeur_mm': source.largeur_mm,
            'epaisseur_mm': source.epaisseur_mm,
            'diametres_mm': source.diametres_mm,
            'force_rupture_newton': source.force_rupture_newton,
            'deplacement_rupture_mm': source.deplacement_rupture_mm,
            'points_courbe': [p.__dict__ for p in source.points_courbe],
        })
    return {
        'materiau_nom': result.gamme.materiau.nom_usage,
        'norme_code': result.gamme.norme.code,
        'horodatage': result.gamme.horodatage.isoformat(),
        'statut': result.statut.value,
        'resistance_moyenne_mpa': result.resistance_moyenne_mpa,
        'ecart_type_mpa': result.ecart_type_mpa,
        'module_young_moyen_mpa': result.module_young_moyen_mpa,
        'deformation_moyenne_pourcent': result.deformation_moyenne_pourcent,
        'ecart_type_deformation_pourcent': result.ecart_type_deformation_pourcent,
        'ecart_type_module_young_mpa': result.ecart_type_module_young_mpa,
        'energie_rupture_moyenne_joules': result.energie_rupture_moyenne_joules,
        'limite_elastique_moyenne_mpa': result.limite_elastique_moyenne_mpa,
        'resultats_echantillons': samples,
        'echantillons': samples,
        'statistiques': {
            'sigma_moyenne': result.resistance_moyenne_mpa,
            'sigma_ecart_type': result.ecart_type_mpa,
            'epsilon_moyen': result.deformation_moyenne_pourcent,
            'epsilon_ecart_type': result.ecart_type_deformation_pourcent,
        },
    }


def _require_file(path: str) -> Path:
    file = Path(path).expanduser().resolve()
    if not file.is_file():
        raise HTTPException(status_code=404, detail=f'Fichier introuvable : {file}')
    return file


@app.get('/health')
def health() -> dict[str, str]:
    return {'status': 'ok'}


@app.post('/essais/traction/calculer')
def calculer_traction(request: GammeRequest) -> dict:
    return _resultat_json(TractionCalculateur().calculer(_to_domain_gamme(request)))


@app.post('/essais/compression/calculer')
def calculer_compression(request: GammeRequest) -> dict:
    return _resultat_json(CompressionCalculateur().calculer(_to_domain_gamme(request)))


@app.post('/essais/traction/calculer-depuis-excel')
def calculer_traction_excel(request: ImportExcelRequest) -> dict:
    return _resultat_json(TractionCalculateur().calculer(_from_excel(request)))


@app.post('/essais/compression/calculer-depuis-excel-complet')
def calculer_compression_excel(request: ImportExcelRequest) -> dict:
    return _resultat_json(CompressionCalculateur().calculer(_from_excel(request)))


@app.post('/protocoles/executer')
@app.post('/essais/protocole/executer')
@app.post('/api/v1/protocoles/executer')
def executer_protocole(request: ExecProtocoleRequest) -> dict:
    import json
    protocole_file = _require_file(request.chemin_protocole)
    excel_file = _require_file(request.chemin_fichier)
    try:
        protocole = json.loads(protocole_file.read_text(encoding='utf-8'))
        gamme = _from_excel(ImportExcelRequest(chemin_fichier=str(excel_file)))
        result = MoteurProtocole(protocole).calculer(gamme)
        return _resultat_json(result)
    except HTTPException:
        raise
    except Exception as error:
        raise HTTPException(status_code=422, detail=f'Exécution impossible : {error}') from error


@app.post('/essais/traction/exporter-excel')
def exporter_classeur_traction(request: ExportExcelRequest) -> Response:
    source = _require_file(request.chemin_fichier)
    template = Path(__file__).resolve().parent / 'moteur_python' / 'modeles' / 'MODELE_TRACTION.xlsx'
    if not template.is_file():
        raise HTTPException(status_code=500, detail=f'Modèle Excel introuvable : {template}')
    output = Path.cwd() / 'RAPPORT_TRACTION.xlsx'
    try:
        process_workbook(source, template, output, request.l0_mm)
        content = output.read_bytes()
    except (ValueError, KeyError, OSError) as error:
        raise HTTPException(status_code=422, detail=f'Export Excel impossible : {error}') from error
    finally:
        output.unlink(missing_ok=True)
    return Response(
        content=content,
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={'Content-Disposition': 'attachment; filename=RAPPORT_TRACTION.xlsx'},
    )


@app.post('/essais/traction/export-excel')
def export_excel(request: GammeRequest) -> Response:
    result = TractionCalculateur().calculer(_to_domain_gamme(request))
    workbook = openpyxl.Workbook()
    sheet = workbook.active
    sheet.title = 'Résultats'
    sheet.append(['Échantillon', 'Contrainte (MPa)', 'Déformation (%)', 'Module (MPa)'])
    for item in result.resultats_echantillons:
        sheet.append([item.identifiant, item.contrainte_rupture_mpa, item.deformation_rupture_pourcent, item.module_young_mpa])
    buffer = BytesIO()
    workbook.save(buffer)
    return Response(
        content=buffer.getvalue(),
        media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        headers={'Content-Disposition': 'attachment; filename=PV.xlsx'},
    )


@app.post('/essais/traction/rapport-labo')
def rapport_labo(chemins_fichiers: list[str]) -> Response:
    if not chemins_fichiers:
        raise HTTPException(status_code=422, detail='Aucun fichier fourni.')
    results = [TractionCalculateur().calculer(_from_excel(ImportExcelRequest(chemin_fichier=str(_require_file(path))))) for path in chemins_fichiers]
    output = Path.cwd() / 'rapport_labo.xlsx'
    generer_rapport_labo(results, str(output))
    try:
        content = output.read_bytes()
    finally:
        output.unlink(missing_ok=True)
    return Response(content=content, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')


if __name__ == '__main__':
    import uvicorn
    uvicorn.run(app, host='127.0.0.1', port=8123)
