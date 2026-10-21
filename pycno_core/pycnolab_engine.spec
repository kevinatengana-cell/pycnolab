# -*- mode: python ; coding: utf-8 -*-

from pathlib import Path
from PyInstaller.utils.hooks import collect_data_files, collect_submodules, collect_all

core_root = Path(SPECPATH).resolve()

# 1. Collecte des dépendances externes critiques (FastAPI, Uvicorn, Pydantic, python-multipart)
ext_datas, ext_binaries, ext_hiddenimports = [], [], []
for pkg in ('fastapi', 'uvicorn', 'pydantic', 'python_multipart'):
    d, b, h = collect_all(pkg)
    ext_datas.extend(d)
    ext_binaries.extend(b)
    ext_hiddenimports.extend(h)

# 2. Tes fichiers de données internes
datas = collect_data_files(
    'moteur_python.modeles',
    includes=['*.xlsx'],
)
datas += collect_data_files('moteur_python.protocoles')
datas += ext_datas  # On ajoute les datas externes

# 3. Fusion de tes submodules internes et des hiddenimports externes
hiddenimports = sorted(
    list(
        set(
            [
                module
                for package in (
                    'moteur_python.api',
                    'moteur_python.calculs',
                    'moteur_python.export_excel',
                    'moteur_python.export_pdf',
                    'moteur_python.import_excel',
                    'moteur_python.protocoles',
                )
                for module in collect_submodules(package)
            ] + ext_hiddenimports
        )
    )
)

a = Analysis(
    [str(core_root / 'pycnolab_engine.py')],
    pathex=[str(core_root)],
    binaries=ext_binaries,  # On inclut les binaires externes (comme les DLLs éventuelles)
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)
pyz = PYZ(a.pure)
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='backend',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name='backend',
)
