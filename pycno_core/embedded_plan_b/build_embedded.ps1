$ErrorActionPreference = 'Stop'

$planRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$engineRoot = Split-Path -Parent $planRoot
$pythonVersion = '3.12.10'
$archiveName = "python-$pythonVersion-embed-amd64.zip"
$archiveUri = "https://www.python.org/ftp/python/$pythonVersion/$archiveName"
$archivePath = Join-Path $env:TEMP $archiveName
$pythonRoot = Join-Path $planRoot 'runtime\python'
$appRoot = Join-Path $pythonRoot 'app'
$sitePackages = Join-Path $pythonRoot 'Lib\site-packages'
$buildPython = Join-Path $engineRoot '.venv_build\Scripts\python.exe'

if (-not (Test-Path -LiteralPath $buildPython -PathType Leaf)) {
    throw "Python 3.12 build venv not found: $buildPython"
}

if (Test-Path -LiteralPath $pythonRoot) {
    Remove-Item -LiteralPath $pythonRoot -Recurse -Force
}
New-Item -ItemType Directory -Path $pythonRoot -Force | Out-Null

try {
    Invoke-WebRequest -Uri $archiveUri -OutFile $archivePath
    Expand-Archive -LiteralPath $archivePath -DestinationPath $pythonRoot -Force
}
finally {
    if (Test-Path -LiteralPath $archivePath) {
        Remove-Item -LiteralPath $archivePath -Force
    }
}

New-Item -ItemType Directory -Path $sitePackages, $appRoot -Force | Out-Null
$pthFile = Join-Path $pythonRoot 'python312._pth'
if (-not (Test-Path -LiteralPath $pthFile -PathType Leaf)) {
    throw "Embedded Python path configuration not found: $pthFile"
}
[System.IO.File]::WriteAllLines(
    $pthFile,
    @('python312.zip', '.', 'app', 'Lib\site-packages', 'import site'),
    [System.Text.Encoding]::ASCII
)

& $buildPython -m pip install `
    --disable-pip-version-check `
    --target $sitePackages `
    -r (Join-Path $engineRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) {
    throw "Installing embedded backend dependencies failed with exit code $LASTEXITCODE."
}

Copy-Item `
    -LiteralPath (Join-Path $engineRoot 'pycnolab_engine.py') `
    -Destination (Join-Path $appRoot 'backend.py') `
    -Force
Copy-Item `
    -LiteralPath (Join-Path $engineRoot 'moteur_python') `
    -Destination (Join-Path $appRoot 'moteur_python') `
    -Recurse -Force

Write-Output "Embedded Python backend prepared: $pythonRoot"
