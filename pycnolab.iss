#define MyAppName "PycnoLab"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Jordan Atengana"
#define MyAppExeName "pycnolab.exe"

[Setup]
AppId={{C78A4E1B-9F32-4821-B892-1234567890AB}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=InstallerOutput
OutputBaseFilename=PycnoLab_Setup_v{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; 1. Fichiers du client Flutter (UI)
Source: "release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "backend\*"

; 2. Contenu complet du moteur Python (backend.exe, dossier _internal, python312.dll, etc.)
Source: "pycno_core\dist\backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{sys}\taskkill.exe"; Parameters: "/F /IM backend.exe"; Flags: runhidden waituntilterminated
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installation de Visual C++..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[InstallDelete]
Type: filesandordirs; Name: "{app}\backend"

[UninstallRun]
Filename: "taskkill.exe"; Parameters: "/F /IM backend.exe"; Flags: runhidden; RunOnceId: "KillBackend"
Filename: "taskkill.exe"; Parameters: "/F /IM {#MyAppExeName}"; Flags: runhidden; RunOnceId: "KillApp"

[Code]
var
  ErrorCode: Integer;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssDone then
  begin
    Exec('cmd.exe', '/c ping 127.0.0.1 -n 3 > nul & del /f /q "' + ExpandConstant('{srcexe}') + '"', '', SW_HIDE, ewNoWait, ErrorCode);
  end;
end;
