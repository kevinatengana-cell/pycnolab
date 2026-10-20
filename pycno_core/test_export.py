import sys
from pathlib import Path

# Ajouter moteur_python au chemin d'import
sys.path.insert(0, str(Path(__file__).parent / "moteur_python"))

from export_excel.production_workbook_exporter import process_workbook

base = Path("moteur_python")
chemin_source = base / "IMPORT_TRACTION.xlsx"
chemin_template = base / "MODELE_TRACTION_VIDE.xlsx"
chemin_sortie = Path("test_genere.xlsx")

print(f"Source   : {chemin_source} ({chemin_source.is_file()})")
print(f"Template : {chemin_template} ({chemin_template.is_file()})")

process_workbook(chemin_source, chemin_template, chemin_sortie, l0_mm=20.0)
print(f"OK : {chemin_sortie}")