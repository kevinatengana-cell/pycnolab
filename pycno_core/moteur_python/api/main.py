# moteur_python/api/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any

app = FastAPI(title="Moteur de Calcul Essais de Traction")

class GammeRequest(BaseModel):
    chemin_fichier: Optional[str] = None
    # autres champs optionnels...

@app.post("/essais/traction/calculer-depuis-excel-complet")
async def calculer_depuis_excel_complet(request: Dict[str, Any]):
    chemin = request.get("chemin_fichier")
    if not chemin:
        raise HTTPException(status_code=400, detail="chemin_fichier requis")
    
    # Simulation / Traitement réel de l'essai
    resultats = [
        {
            "identifiant": "Echantillon 1",
            "largeur_mm": 10.0,
            "epaisseur_mm": 2.0,
            "section_mm2": 20.0,
            "force_rupture_newton": 1500.0,
            "contrainte_rupture_mpa": 75.0,
            "module_young_mpa": 3200.0,
            "energie_rupture_joules": 4.5,
            "limite_elastique_mpa": 50.0,
            "points_courbe": [
                {"deplacement_mm": 0.0, "force_newton": 0.0},
                {"deplacement_mm": 0.5, "force_newton": 500.0},
                {"deplacement_mm": 1.0, "force_newton": 1000.0},
                {"deplacement_mm": 1.5, "force_newton": 1500.0}
            ]
        }
    ]
    
    statistiques = {
        "epsilon_moyen": 2.5
    }

    # IMPORTANT: On fournit TOUTES les variantes de clés pour garantir
    # la compatibilité avec toutes les vues Flutter
    return {
        "materiau_nom": "Matériau Test",
        "resistance_moyenne_mpa": 75.0,
        "module_young_moyen_mpa": 3200.0,
        "energie_rupture_moyenne_joules": 4.5,
        "limite_elastique_moyenne_mpa": 50.0,
        "statistiques": statistiques,
        "resultats_echantillons": resultats,
        "echantillons": resultats
    }
@app.get("/health")
def health_check():
    return {"status": "ok"}