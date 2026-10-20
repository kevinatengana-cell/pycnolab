# Correctif exécution protocole Studio

Copier `lib/services/python_engine_service.dart` dans le projet Flutter :
`lib/services/python_engine_service.dart`

Copier `pycno_core/moteur_python/api/main.py` dans le backend :
`pycno_core/moteur_python/api/main.py`

Le client appelle `/protocoles/executer`. Le backend accepte aussi les anciens chemins `/essais/protocole/executer` et `/api/v1/protocoles/executer`.

Après remplacement :

```powershell
cd D:\F1\flutterapp\pycnolab\pycno_core
.venv\Scripts\python.exe -m uvicorn moteur_python.api.main:app --host 127.0.0.1 --port 8123
```

Puis, dans un autre terminal :

```powershell
cd D:\F1\flutterapp\pycnolab
flutter clean
flutter pub get
flutter analyze
flutter run -d windows
```
