# Correctif reader.py

L'erreur vient de l'absence de cette fonction dans le fichier local :

```python
def lire_gamme_complete(...):
```

Copier le fichier fourni à cet emplacement :

```text
D:\F1\flutterapp\pycnolab\pycno_core\moteur_python\import_excel\reader.py
```

Sauvegarder l'ancien fichier avant remplacement.

Vérifier que la fonction est bien présente :

```powershell
cd D:\F1\flutterapp\pycnolab\pycno_core
Select-String -Path .\moteur_python\import_excel\reader.py -Pattern "def lire_gamme_complete"
```

Puis tester l'import sans lancer le serveur :

```powershell
.venv\Scripts\python.exe -c "from moteur_python.import_excel.reader import lire_gamme_complete; print('IMPORT READER OK')"
```

Enfin démarrer FastAPI :

```powershell
.venv\Scripts\python.exe -m uvicorn moteur_python.api.main:app --host 127.0.0.1 --port 8123 --log-level debug
```
