param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $env:BDS -or -not (Test-Path -LiteralPath (Join-Path $env:BDS 'bin\CodeGear.Group.Targets'))) {
    throw 'Run this script from a RAD Studio 10.2 Tokyo Command Prompt.'
}

$redist = Join-Path $env:BDS 'Redist\win32'
$runtimeFiles = @('rtl250.bpl', 'vcl250.bpl')
foreach ($file in $runtimeFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $redist $file) -PathType Leaf)) {
        throw "The Tokyo Win32 redistributable $file is missing from $redist."
    }
}

& msbuild (Join-Path $repo 'OTel4D.groupproj') /t:Build "/p:Config=$Configuration" /p:Platform=Win32 /v:minimal /nologo
if ($LASTEXITCODE -ne 0) { throw "The Win32 $Configuration build failed." }

$dist = (New-Item -Path (Join-Path $repo 'dist') -ItemType Directory -Force).FullName
$staging = Join-Path $dist ('.bundle-' + [guid]::NewGuid().ToString('N'))
$bundle = Join-Path $staging 'bundle'
$archiveName = "OTel4D-win32-$Configuration.zip"
$archive = Join-Path $dist $archiveName
$labSource = Join-Path $repo 'infra\observability'
$labFiles = @(
    'Dockerfile', 'compose.yaml', '.dockerignore', '.env.example',
    'grafana\provisioning.yaml', 'grafana\dashboards\otel4d-delphi-demo.json',
    'tests\smoke.py', 'tests\verify_delphi_demo.py'
)

try {
    $bin = New-Item -Path (Join-Path $bundle 'win32') -ItemType Directory
    $output = Join-Path $repo "source\Win32\$Configuration"
    foreach ($file in @('OTel4D.bpl', 'OTel4D.dcp', 'TelemetryDemo.exe')) {
        Copy-Item -LiteralPath (Join-Path $output $file) -Destination $bin.FullName
    }
    foreach ($file in $runtimeFiles) {
        Copy-Item -LiteralPath (Join-Path $redist $file) -Destination $bin.FullName
    }

    $lab = Join-Path $bundle 'observability'
    foreach ($file in $labFiles) {
        $destination = Join-Path $lab $file
        New-Item -Path (Split-Path -Parent $destination) -ItemType Directory -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $labSource $file) -Destination $destination
    }
    Copy-Item -LiteralPath (Join-Path $repo 'docs\demo-bundle.md') -Destination (Join-Path $bundle 'README.md')
    Copy-Item -LiteralPath (Join-Path $repo 'LICENSE'), (Join-Path $repo 'NOTICE') -Destination $bundle

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $temporaryArchive = Join-Path $staging $archiveName
    [System.IO.Compression.ZipFile]::CreateFromDirectory($bundle, $temporaryArchive)
    Move-Item -LiteralPath $temporaryArchive -Destination $archive -Force
    Write-Output $archive
} finally {
    if (Test-Path -LiteralPath $staging -PathType Container) {
        $resolved = (Resolve-Path -LiteralPath $staging).Path
        if ((Split-Path -Parent $resolved) -eq $dist) {
            Remove-Item -LiteralPath $resolved -Recurse -Force
        }
    }
}
