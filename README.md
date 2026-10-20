# PycnoLab

## Run Windows in debug mode

Run from the repository root with the project launcher. It stops only an
existing PycnoLab debug process from this workspace before rebuilding and
launching the app:

```powershell
.\scripts\run_windows.ps1
```

The editable Flutter build stays in its usual
`build\windows\x64\runner\Debug` directory. In debug mode, the app launches the
Python backend directly from `pycno_core` using the local virtual environment.
Backend source changes are used without rebuilding the PyInstaller bundle;
restart the app after editing Python files. Flutter changes continue to use
the normal debug/hot-reload workflow.

Flutter arguments can be passed through, for example
`.\scripts\run_windows.ps1 -FlutterArgs '--dart-define=EXAMPLE=value'`.

Initialize the backend environment if needed:

```powershell
py -m venv pycno_core\.venv
pycno_core\.venv\Scripts\python.exe -m pip install -r pycno_core\requirements.txt
```

## Build Windows Release

Build the Windows application and its self-contained Python engine from the
repository root on a Windows build machine:

```powershell
py -m venv pycno_core\.venv
pycno_core\.venv\Scripts\python.exe -m pip install -r pycno_core\requirements-build.txt
.\scripts\build_windows_release.ps1
```

The script packages the backend API and its Excel templates with PyInstaller,
builds Flutter in Release mode, and places the backend executable in
`build\windows\x64\runner\Release\backend`. Distribute the **entire**
`Release` directory (or a ZIP of it), not only `pycnolab.exe`. The destination
computer does not need Python installed.

After changing the Python engine or its dependencies, run the build script
again so the packaged backend contains the latest code. The backend reserves
an available loopback port at startup and publishes it to Flutter as
`PORT_BOUND:<port>`; no fixed port needs to be configured. Flutter sends a
heartbeat every two seconds, and the backend shuts down after ten seconds
without a heartbeat.

## Create a Windows installer

Install Inno Setup 6 on the build computer, then run:

```powershell
.\scripts\create_windows_installer.ps1
```

The installer is written to `build\installer\PycnoLab-Setup-1.0.0.exe`. It
installs per-user under `%LOCALAPPDATA%\Programs\PycnoLab`, creates a Start
Menu shortcut, offers an optional desktop shortcut, and registers a standard
uninstaller. It packages the complete Flutter Release bundle, including the
self-contained backend. Inno Setup is only needed on the build computer; it
does not need to be installed on users' computers.

Build or refresh the Release bundle first with
`.\scripts\build_windows_release.ps1` whenever the app or engine changes.
