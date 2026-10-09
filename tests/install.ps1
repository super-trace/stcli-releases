$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $root | Out-Null
try {
    $assets = Join-Path $root 'assets'
    $payload = Join-Path $root 'payload'
    $bin = Join-Path $root 'bin with spaces'
    New-Item -ItemType Directory -Path $assets, $payload | Out-Null
    Set-Content (Join-Path $payload 'stcli.exe') 'test executable fixture'
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'amd64' }
    $name = "stcli_test_windows_${arch}.zip"
    $archive = Join-Path $assets $name
    Compress-Archive -Path (Join-Path $payload 'stcli.exe') -DestinationPath $archive
    $hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
    Set-Content (Join-Path $assets 'checksums.txt') "$hash  $name"
    $originalPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $installer = Join-Path $PSScriptRoot '..\install.ps1'
    & $installer -Version test -AssetDirectory $assets -InstallDirectory $bin -NoPathUpdate
    & $installer -Version test -AssetDirectory $assets -InstallDirectory $bin -NoPathUpdate
    $installedHash = (Get-FileHash (Join-Path $bin 'stcli.exe')).Hash
    Set-Content $archive 'corrupt archive'
    $rejected = $false
    try { & $installer -Version test -AssetDirectory $assets -InstallDirectory $bin -NoPathUpdate }
    catch {
        if ($_ -notmatch 'Checksum mismatch') { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw 'Corrupt archive accepted.' }
    if ((Get-FileHash (Join-Path $bin 'stcli.exe')).Hash -ne $installedHash) { throw 'Installation changed after failed verification.' }
    if ([Environment]::GetEnvironmentVariable('Path', 'User') -ne $originalPath) { throw 'Unexpected PATH modification.' }
    # Exercise unauthenticated native gh stderr on Windows PowerShell 5.1,
    # with public HTTPS downloads replaced by local fixture copies.
    Compress-Archive -Path (Join-Path $payload 'stcli.exe') -DestinationPath $archive -Force
    $hash = (Get-FileHash $archive -Algorithm SHA256).Hash.ToLower()
    Set-Content (Join-Path $assets 'checksums.txt') "$hash  $name"
    function Invoke-WebRequest {
        param([switch]$UseBasicParsing, [string]$Uri, [string]$OutFile)
        $file = [IO.Path]::GetFileName(([Uri]$Uri).AbsolutePath)
        Copy-Item -LiteralPath (Join-Path $assets $file) -Destination $OutFile
    }
    & $installer -Version test -InstallDirectory (Join-Path $root 'public download') -NoPathUpdate
    if ($LASTEXITCODE -ne 0) { throw 'Successful public installation returned a failure exit code.' }
    if (-not (Test-Path (Join-Path $root 'public download\stcli.exe'))) { throw 'Public download fallback failed.' }
    Write-Host 'Install, reinstall, spaces, checksum rejection, and existing-install preservation passed.'
} finally { Remove-Item -LiteralPath $root -Recurse -Force }
