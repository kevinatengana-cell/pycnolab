# Correctif erreur ResultatEchantillon

Remplacer dans le projet :

`pycno_core/moteur_python/calculs/protocole.py`

Le correctif retire l’argument `force_max_newton` qui n’existe pas dans le constructeur actuel de `ResultatEchantillon`.

Après copie, arrêter le serveur avec Ctrl+C puis relancer :

```powershell
cd D:\F1\flutterapp\pycnolab\pycno_core
.venv\Scripts\python.exe -m uvicorn moteur_python.api.main:app --host 127.0.0.1 --port 8123
```

Puis relancer Flutter et le runner Studio.
