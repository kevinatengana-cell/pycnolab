# Plan B : backend Python embarqué

Ce plan de secours n'est pas activé dans le client Flutter ni dans Inno Setup.
Il prépare un runtime Python 3.12 autonome dans `runtime\python\`, avec le code
du backend et ses dépendances.

Depuis `pycno_core`, après avoir installé les dépendances dans `.venv_build` :

```powershell
.\embedded_plan_b\build_embedded.ps1
```

Pour tester le moteur manuellement :

```powershell
.\embedded_plan_b\run_backend.bat
```

Pour basculer le client vers ce backend, remplacer le lancement de
`backend\backend.exe` dans `BackendLauncherService` par un lancement de
`cmd.exe /c embedded_plan_b\run_backend.bat`, en transmettant le même
`--port-file` temporaire que le client attend. Conserver le contrôle de santé
`/health` et ne pas modifier l'installeur tant que ce plan n'a pas été validé.
