"""Fragment à intégrer dans moteur_python/api/main.py."""
from pathlib import Path
import os
import tempfile

from fastapi import HTTPException
from fastapi.responses import Response

from moteur_python.export_excel.rapport_labo_modele import XLSX_MIME, generer_rapport_modele


class RapportModeleRequest(BaseModel):
    chemins_fichiers: list[str]
    chemin_modele: str | None = None


@app.post("/essais/traction/rapport-modele")
def rapport_modele(requete: RapportModeleRequest) -> Response:
    if not requete.chemins_fichiers:
        raise HTTPException(status_code=422, detail="Aucun fichier de mesures fourni.")

    chemins = [Path(p).expanduser().resolve() for p in requete.chemins_fichiers]
    manquants = [str(p) for p in chemins if not p.is_file()]
    if manquants:
        raise HTTPException(status_code=404, detail=f"Fichier(s) introuvable(s) : {manquants}")

    modele = Path(requete.chemin_modele).expanduser().resolve() if requete.chemin_modele else (
        Path(__file__).resolve().parents[2] / "modeles" / "TRACTIONFIBREVEGETALE.xlsx"
    )
    if not modele.is_file():
        raise HTTPException(status_code=404, detail=f"Modèle Excel introuvable : {modele}")

    try:
        resultats = []
        for chemin in chemins:
            domaine = _gamme_depuis_fichier(str(chemin), ImportExcelRequest(chemin_fichier=str(chemin)))
            resultats.append(TractionCalculateur().calculer(domaine))

        with tempfile.NamedTemporaryFile(suffix=".xlsx", delete=False) as tmp:
            sortie = Path(tmp.name)
        try:
            generer_rapport_modele(resultats, modele, sortie)
            contenu = sortie.read_bytes()
        finally:
            sortie.unlink(missing_ok=True)
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Génération du rapport impossible : {exc}") from exc

    return Response(
        content=contenu,
        media_type=XLSX_MIME,
        headers={"Content-Disposition": "attachment; filename=TRACTIONFIBREVEGETALE_resultats.xlsx"},
    )
