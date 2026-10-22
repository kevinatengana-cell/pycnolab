[CmdletBinding()]
param(
    [switch]$SkipLocalBuild
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$coreRoot = Join-Path $repoRoot 'pycno_core'
$oldModelsDir = Join-Path $coreRoot 'moteur_python\modeles'
$newModelsDir = Join-Path $coreRoot 'moteur_python\models'
$specPath = Join-Path $coreRoot 'pycnolab_engine.spec'
$apiPath = Join-Path $coreRoot 'moteur_python\api\main.py'
$workflowPath = Join-Path $repoRoot '.github\workflows\build-windows.yml'

function Read-TextFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Fichier requis introuvable : $Path"
    }
    return [System.IO.File]::ReadAllText($Path)
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

if (-not (Test-Path -LiteralPath (Join-Path $repoRoot '.git'))) {
    throw "Le dossier du script n'est pas dans un dépôt Git reconnu : $repoRoot"
}
if (-not (Test-Path -LiteralPath $coreRoot -PathType Container)) {
    throw "Dossier pycno_core introuvable : $coreRoot"
}

$hasOld = Test-Path -LiteralPath $oldModelsDir -PathType Container
$hasNew = Test-Path -LiteralPath $newModelsDir -PathType Container
if ($hasOld -and $hasNew) {
    throw "Les deux dossiers existent déjà : 'modeles' et 'models'. Fusionne-les manuellement pour éviter d'écraser des fichiers, puis relance le script."
}
if (-not $hasOld -and -not $hasNew) {
    throw "Aucun dossier source 'modeles' ou 'models' n'existe dans $coreRoot\moteur_python."
}

$sourceModelsDir = if ($hasOld) { $oldModelsDir } else { $newModelsDir }
$requiredModels = @(
    'MODELE_TRACTION_VIDE.xlsx',
    'MODELE_COMPRESSION_VIDE.xlsx',
    'MODELE_FLEXION_VIDE.xlsx'
)
foreach ($name in $requiredModels) {
    if (-not (Test-Path -LiteralPath (Join-Path $sourceModelsDir $name) -PathType Leaf)) {
        throw "Modèle source manquant : $(Join-Path $sourceModelsDir $name)"
    }
}

$originalSpec = Read-TextFile $specPath
$originalApi = Read-TextFile $apiPath
$originalWorkflow = Read-TextFile $workflowPath

# Remplace la collecte du package `modeles`/`models` par l'inclusion explicite
# des fichiers Excel, en conservant le reste de la collecte (protocoles et libs).
$specPattern = 'datas\s*=\s*collect_data_files\(\s*["'']moteur_python\.(?:modeles|models)["'']\s*,\s*includes\s*=\s*\[\s*["'']\*\.xlsx["'']\s*\]\s*,?\s*\)'
$explicitSpecMarker = "models_dir = core_root / 'moteur_python' / 'models'"
if ([regex]::IsMatch($originalSpec, $specPattern)) {
    $newDataBlock = @"
models_dir = core_root / 'moteur_python' / 'models'
if not models_dir.is_dir():
    raise FileNotFoundError(f'Modeles Excel introuvables : {models_dir}')
model_files = sorted(models_dir.glob('*.xlsx'))
if not model_files:
    raise FileNotFoundError(f'Aucun modele .xlsx dans : {models_dir}')
datas = [(str(model_file), 'moteur_python/models') for model_file in model_files]
"@
    $updatedSpec = [regex]::Replace($originalSpec, $specPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $newDataBlock.TrimEnd() }, 1)
} elseif ($originalSpec.Contains($explicitSpecMarker) -and $originalSpec.Contains("'moteur_python/models'")) {
    $updatedSpec = $originalSpec
} else {
    throw "La section `datas` du spec ne correspond pas au format attendu. Aucun fichier n'a été modifié. Vérifie manuellement $specPath."
}

# Le backend fourni construit le chemin modèle dans cette route.
$oldApiPathLine = "        'modeles',"
$newApiPathLine = "        'models',"
$oldApiCount = ([regex]::Matches($originalApi, [regex]::Escape($oldApiPathLine))).Count
if ($oldApiCount -eq 1) {
    $updatedApi = $originalApi.Replace($oldApiPathLine, $newApiPathLine)
} elseif ($oldApiCount -eq 0 -and $originalApi.Contains($newApiPathLine)) {
    $updatedApi = $originalApi
} else {
    throw "Le segment de chemin attendu est absent ou ambigu dans $apiPath. Aucun fichier n'a été modifié."
}

# Ajoute un garde-fou après PyInstaller : le workflow échouera avant Inno si
# l'un des trois modèles n'a pas été inclus dans dist/backend/_internal.
$workflowMarker = '      - name: Validate bundled Excel model templates'
if ($originalWorkflow.Contains($workflowMarker)) {
    $updatedWorkflow = $originalWorkflow
} else {
    $workflowAnchor = '      - name: Set up Flutter'
    $anchorIndex = $originalWorkflow.IndexOf($workflowAnchor, [System.StringComparison]::Ordinal)
    if ($anchorIndex -lt 0) {
        throw "Étape d'insertion introuvable dans $workflowPath. Aucun fichier n'a été modifié."
    }
    $validationStep = @'
      - name: Validate bundled Excel model templates
        shell: pwsh
        run: |
          $modelDir = "pycno_core\dist\backend\_internal\moteur_python\models"
          $required = @(
            "MODELE_TRACTION_VIDE.xlsx",
            "MODELE_COMPRESSION_VIDE.xlsx",
            "MODELE_FLEXION_VIDE.xlsx"
          )
          foreach ($name in $required) {
            $path = Join-Path $modelDir $name
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
              throw "Modèle Excel absent du bundle PyInstaller : $path"
            }
            Write-Host "Modèle inclus : $path"
          }

'@
    $updatedWorkflow = $originalWorkflow.Insert($anchorIndex, $validationStep)
}

# Sauvegarde temporaire des trois fichiers avant édition, hors du dépôt.
$backupDir = Join-Path $env:TEMP ('PycnoLab_models_migration_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
Copy-Item -LiteralPath $specPath -Destination (Join-Path $backupDir 'pycnolab_engine.spec')
Copy-Item -LiteralPath $apiPath -Destination (Join-Path $backupDir 'api_main.py')
Copy-Item -LiteralPath $workflowPath -Destination (Join-Path $backupDir 'build-windows.yml')

$renamedDirectory = $false
try {
    if ($hasOld) {
        Move-Item -LiteralPath $oldModelsDir -Destination $newModelsDir
        $renamedDirectory = $true
    }
    Write-Utf8NoBom $specPath $updatedSpec
    Write-Utf8NoBom $apiPath $updatedApi
    Write-Utf8NoBom $workflowPath $updatedWorkflow
} catch {
    Write-Utf8NoBom $specPath $originalSpec
    Write-Utf8NoBom $apiPath $originalApi
    Write-Utf8NoBom $workflowPath $originalWorkflow
    if ($renamedDirectory -and (Test-Path -LiteralPath $newModelsDir) -and -not (Test-Path -LiteralPath $oldModelsDir)) {
        Move-Item -LiteralPath $newModelsDir -Destination $oldModelsDir
    }
    throw
}

Write-Host "Sources alignées sur le dossier moteur_python\models." -ForegroundColor Green
Write-Host "Sauvegarde des fichiers précédents : $backupDir" -ForegroundColor DarkGray
Write-Host 'Le script ne fait ni git add, ni commit, ni push.' -ForegroundColor Cyan

if (-not $SkipLocalBuild) {
    $venvPython = Join-Path $coreRoot '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
        $pythonExe = $venvPython
    } else {
        $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
        if (-not $pythonCommand) {
            throw "Python introuvable. Crée/utilise pycno_core\.venv ou ajoute Python au PATH. Les sources ont été mises à jour."
        }
        $pythonExe = $pythonCommand.Source
    }

    $runningBackend = Get-Process -Name backend -ErrorAction SilentlyContinue
    if ($runningBackend) {
        throw 'Arrête les processus backend.exe avant de reconstruire le backend.'
    }

    Push-Location $coreRoot
    try {
        Remove-Item -LiteralPath '.\build' -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath '.\dist\backend' -Recurse -Force -ErrorAction SilentlyContinue
        & $pythonExe -m PyInstaller --noconfirm --clean --distpath '.\dist' --workpath '.\build' '.\pycnolab_engine.spec'
        if ($LASTEXITCODE -ne 0) {
            throw "PyInstaller a échoué avec le code $LASTEXITCODE. Les modifications source sont conservées pour diagnostic."
        }
    } finally {
        Pop-Location
    }

    $builtModelsDir = Join-Path $coreRoot 'dist\backend\_internal\moteur_python\models'
    foreach ($name in $requiredModels) {
        $builtModel = Join-Path $builtModelsDir $name
        if (-not (Test-Path -LiteralPath $builtModel -PathType Leaf)) {
            throw "Build incomplet : modèle absent du bundle : $builtModel"
        }
        Write-Host "Modèle vérifié dans dist : $builtModel" -ForegroundColor Green
    }
    if (-not (Test-Path -LiteralPath (Join-Path $coreRoot 'dist\backend\backend.exe') -PathType Leaf)) {
        throw 'Build incomplet : dist\backend\backend.exe est absent.'
    }
}

Push-Location $repoRoot
try {
    git diff --check
    if ($LASTEXITCODE -ne 0) {
        throw 'git diff --check a détecté des erreurs d'espacement.'
    }
    Write-Host ''
    Write-Host 'Changements à examiner avant git add / commit / push :' -ForegroundColor Cyan
    git status --short
    git diff --stat
} finally {
    Pop-Location
}

Write-Host ''
if ($SkipLocalBuild) {
    Write-Host 'Préparation terminée sans build local. Le workflow GitHub vérifiera les fichiers après PyInstaller.' -ForegroundColor Green
} else {
    Write-Host 'Préparation terminée : les modèles sont présents dans le bundle local. Tu peux inspecter le diff avant le push.' -ForegroundColor Green
}
