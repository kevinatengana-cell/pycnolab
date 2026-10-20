from pathlib import Path

core_root = Path(SPECPATH).resolve()
from PyInstaller.utils.hooks import collect_data_files, collect_submodules

datas = collect_data_files(
    'moteur_python.modeles',
    includes=['*.xlsx'],
)
datas += collect_data_files('moteur_python.protocoles')
hiddenimports = sorted(
    {
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
    }
)

a = Analysis(
    [str(core_root / 'pycnolab_engine.py')],
    pathex=[str(core_root)],
    binaries=[],
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
