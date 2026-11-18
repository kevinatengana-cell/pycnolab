$ErrorActionPreference = 'Stop'

$engineRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$activateScript = Join-Path $engineRoot '.venv_build\Scripts\Activate.ps1'
$python = Join-Path $engineRoot '.venv_build\Scripts\python.exe'
$buildDirectory = Join-Path $engineRoot 'build'
$distDirectory = Join-Path $engineRoot 'dist'
$specFile = Join-Path $engineRoot 'pycnolab_engine.spec'

if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "Python 3.12 build environment not found: $python"
}
if (-not (Test-Path -LiteralPath $activateScript -PathType Leaf)) {
    throw "Build environment activation script not found: $activateScript"
}
if (-not (Test-Path -LiteralPath $specFile -PathType Leaf)) {
    throw "PyInstaller spec not found: $specFile"
}

. $activateScript
$pythonVersion = & $python -c "import platform, sys; print(f'{sys.version_info.major}.{sys.version_info.minor};{platform.architecture()[0]}')"
if ($LASTEXITCODE -ne 0 -or $pythonVersion -ne '3.12;64bit') {
    throw "The build environment must use 64-bit Python 3.12. Found: $pythonVersion"
}

foreach ($directory in @($buildDirectory, $distDirectory)) {
    if (Test-Path -LiteralPath $directory) {
        Remove-Item -LiteralPath $directory -Recurse -Force
    }
}

Push-Location $engineRoot
try {
    & $python -m PyInstaller --clean --noconfirm $specFile
    if ($LASTEXITCODE -ne 0) {
        throw "PyInstaller failed with exit code $LASTEXITCODE."
    }
}
finally {
    Pop-Location
}

$backendDirectory = Join-Path $distDirectory 'backend'
$backendExecutable = Join-Path $backendDirectory 'backend.exe'
$internalDirectory = Join-Path $backendDirectory '_internal'
if (-not (Test-Path -LiteralPath $backendExecutable -PathType Leaf)) {
    throw "Packaged backend executable not found: $backendExecutable"
}
if (-not (Test-Path -LiteralPath $internalDirectory -PathType Container)) {
    throw "Packaged backend _internal directory not found: $internalDirectory"
}

$files = @(
    Get-Item -LiteralPath $backendExecutable
    Get-ChildItem -LiteralPath $internalDirectory -File -Recurse |
        Sort-Object FullName
)
$backendPrefix = $backendDirectory.TrimEnd('\') + '\'
$manifestLines = foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($backendPrefix.Length).Replace('\', '/')
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $relativePath"
}
Set-Content -LiteralPath (Join-Path $backendDirectory 'manifest.sha256') `
    -Value $manifestLines -Encoding Ascii

$executableHash = (Get-FileHash -LiteralPath $backendExecutable -Algorithm SHA256).Hash
Write-Output "backend.exe SHA-256: $executableHash"
Write-Output "Backend bundle ready: $backendDirectory"
