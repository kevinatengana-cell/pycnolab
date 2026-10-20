from pathlib import Path
from tempfile import TemporaryDirectory
from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

from ..export_excel.production_workbook_exporter import process_workbook

router = APIRouter(prefix='/essais/traction', tags=['traction'])


class ExportTractionRequest(BaseModel):
    input_path: str
    output_path: str | None = None
    l0_mm: float = 20.0


@router.post('/exporter-excel')
def exporter_excel(request: ExportTractionRequest):
    input_path = Path(request.input_path)
    if not input_path.is_file():
        raise HTTPException(status_code=400, detail='Fichier Excel d’entrée introuvable.')
    output_path = Path(request.output_path) if request.output_path else input_path.with_name('RAPPORT_TRACTION.xlsx')
    try:
        result = process_workbook(input_path, Path(__file__).parents[2] / 'modeles' / 'MODELE_TRACTION.xlsx', output_path, request.l0_mm)
    except (ValueError, KeyError, OSError) as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return FileResponse(result, filename=result.name, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
