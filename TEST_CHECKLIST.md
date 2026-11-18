# Checklist de validation Windows vierge

## Préparation

- [ ] Construire le backend et l'installeur depuis le commit testé.
- [ ] Conserver le `setup.exe` et le manifeste de l'artefact GitHub Actions.
- [ ] Choisir une machine virtuelle Windows 11 64 bits sans Python, Flutter ni Visual Studio.
- [ ] Utiliser Windows Sandbox (Windows 11 Pro/Enterprise) ou VirtualBox (gratuit).

## Installation et premier démarrage

- [ ] Installer uniquement le `setup.exe`; ne pas installer Python, Flutter ou Visual Studio.
- [ ] Lancer PycnoLab depuis le raccourci installé.
- [ ] Vérifier que l'application atteint l'écran d'accueil et que le backend répond à `/health`.
- [ ] Vérifier la création de `%LOCALAPPDATA%\PycnoLab\logs\backend.log`.
- [ ] Vérifier la création de `%LOCALAPPDATA%\PycnoLab\logs\backend_launcher.log`.
- [ ] Vérifier que les fichiers utilisateur se trouvent sous `%LOCALAPPDATA%\PycnoLab\`, pas dans `Program Files`.

## Vérification des hashes

Sur la machine de build :

```powershell
Get-FileHash .\pycno_core\dist\backend\backend.exe -Algorithm SHA256
Select-String -Path .\pycno_core\dist\backend\manifest.sha256 -Pattern '  backend\.exe$'
```

Sur la machine ayant l'application installée :

```powershell
Get-FileHash "$env:ProgramFiles\PycnoLab\backend\backend.exe" -Algorithm SHA256
```

Sur la machine vierge de test, exécuter la même commande. Comparer les trois
hashes; ils doivent correspondre à la ligne `backend.exe` du manifeste.

## Test dans la durée et antivirus

- [ ] Relancer PycnoLab le jour de l'installation et noter le résultat.
- [ ] Relancer PycnoLab le lendemain.
- [ ] Relancer PycnoLab trois jours après l'installation.
- [ ] Après chaque démarrage, vérifier les journaux sous `%LOCALAPPDATA%\PycnoLab\logs`.
- [ ] Dans Sécurité Windows > Protection contre les virus et menaces > Historique de protection, vérifier qu'aucune alerte ne concerne `backend.exe`, `_internal` ou PycnoLab.

## En cas d'échec

- [ ] Relever le hash installé et le comparer au hash du build.
- [ ] Conserver `backend_launcher.log` et `backend.log`.
- [ ] Noter l'heure de l'échec et toute action correspondante dans l'Historique de protection.
