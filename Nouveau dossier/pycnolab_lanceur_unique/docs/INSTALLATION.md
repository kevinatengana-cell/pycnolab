# Lanceur PycnoLab unifié

Le projet Windows doit utiliser une seule architecture backend :

```text
pycno_core/.venv/Scripts/python.exe
pycno_core/moteur_python/api/main.py
```

Le lanceur ne recherche plus `python_engine`, ne lance plus `main:app` et ne peut donc plus choisir une seconde copie du backend.

Remplacer :

```text
D:\F1\flutterapp\pycnolab\flutter_app\lib\services\backend_launcher_service.dart
```

Puis fermer toutes les instances avant le premier démarrage :

```powershell
Get-NetTCPConnection -LocalPort 8123 -State Listen -ErrorAction SilentlyContinue
Stop-Process -Id NUMERO_DU_PID -Force
```

Lancer ensuite uniquement :

```powershell
cd D:\F1\flutterapp\pycnolab
flutter clean
flutter pub get
flutter run -d windows
```

Ne pas lancer Uvicorn manuellement en parallèle.
