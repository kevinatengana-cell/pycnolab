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

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Utilise un chemin relatif par rapport à l'emplacement du script .iss
Source: "release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[InstallDelete]
Type: filesandordirs; Name: "{app}\backend"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

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