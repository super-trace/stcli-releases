# Native Windows user-level installer. Windows PowerShell 5.1 or PowerShell 7.
param(
    [string]$Version = 'latest',
    [string]$InstallDirectory = (Join-Path $env:LOCALAPPDATA 'Supertrace\stcli\bin'),
    [string]$AssetDirectory = '',
    [switch]$NoPathUpdate
)
$ErrorActionPreference = 'Stop'
$repo = 'super-trace/stcli-releases'
if ($env:OS -ne 'Windows_NT') { throw 'Use install.sh on macOS, Linux, or WSL.' }
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Invalid version label.' }
if ([string]::IsNullOrWhiteSpace($InstallDirectory)) { throw 'Installation directory is empty.' }
$machine = $env:PROCESSOR_ARCHITEW6432
if (-not $machine) { $machine = $env:PROCESSOR_ARCHITECTURE }
switch ($machine) {
    'AMD64' { $arch = 'amd64' }
    'ARM64' { $arch = 'arm64' }
    default { throw "Unsupported Windows architecture: $machine" }
}
# Windows PowerShell 5.1 may otherwise negotiate legacy TLS defaults.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$useGh = $false
if (-not $AssetDirectory -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    $previousErrorPreference = $ErrorActionPreference
    try {
        # Windows PowerShell treats redirected native stderr as an ErrorRecord.
        # Missing gh login should select public HTTPS, not terminate installation.
        $ErrorActionPreference = 'Continue'
        & gh auth status *> $null
        $useGh = ($LASTEXITCODE -eq 0)
    } finally { $ErrorActionPreference = $previousErrorPreference }
}
if ($Version -eq 'latest') {
    if ($AssetDirectory) { throw 'Set -Version when installing offline.' }
    if ($useGh) {
        $Version = & gh release view --repo $repo --json tagName --jq '.tagName'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot find a release.' }
    } else {
        $release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest"
        $Version = $release.tag_name
    }
}
$Version = $Version -replace '^v', ''
if ($Version -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw 'Release returned an invalid version.' }
$archive = "stcli_${Version}_windows_${arch}.zip"
$work = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString())
$staged = $null
$backup = $null
New-Item -ItemType Directory -Path $work | Out-Null
try {
    if ($AssetDirectory) {
        Copy-Item -LiteralPath (Join-Path $AssetDirectory $archive) -Destination $work
        Copy-Item -LiteralPath (Join-Path $AssetDirectory 'checksums.txt') -Destination $work
    } elseif ($useGh) {
        & gh release download "v$Version" --repo $repo --dir $work --pattern $archive --pattern checksums.txt
        if ($LASTEXITCODE -ne 0) { throw 'Download failed.' }
    } else {
        foreach ($name in @($archive, 'checksums.txt')) {
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/$repo/releases/download/v$Version/$name" -OutFile (Join-Path $work $name)
        }
    }
    $checksumLines = @(Get-Content (Join-Path $work 'checksums.txt') | Where-Object {
        $_ -match ('^[0-9a-fA-F]{64}\s+' + [regex]::Escape($archive) + '$')
    })
    if ($checksumLines.Count -ne 1) { throw 'Missing or ambiguous SHA-256 checksum.' }
    $expected = ($checksumLines[0] -split '\s+')[0]
    $actual = (Get-FileHash (Join-Path $work $archive) -Algorithm SHA256).Hash
    if ($actual -ne $expected) { throw 'Checksum mismatch; existing installation left untouched.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead((Join-Path $work $archive))
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -ne 'stcli.exe') {
            throw 'Unexpected archive contents.'
        }
    } finally { $zip.Dispose() }
    Expand-Archive -LiteralPath (Join-Path $work $archive) -DestinationPath (Join-Path $work 'unpacked')
    New-Item -ItemType Directory -Force -Path $InstallDirectory | Out-Null
    $staged = Join-Path $InstallDirectory ('.stcli-' + [Guid]::NewGuid().ToString() + '.exe')
    Copy-Item -LiteralPath (Join-Path $work 'unpacked\stcli.exe') -Destination $staged
    $target = Join-Path $InstallDirectory 'stcli.exe'
    if (Test-Path -LiteralPath $target) {
        # PowerShell 5.1 marshals a null string argument as an empty path.
        # Supply a real temporary backup path for .NET Framework's Replace.
        $backup = Join-Path $InstallDirectory ('.stcli-backup-' + [Guid]::NewGuid().ToString() + '.exe')
        [IO.File]::Replace($staged, $target, $backup)
        Remove-Item -LiteralPath $backup -Force
        $backup = $null
    } else { [IO.File]::Move($staged, $target) }
    $staged = $null
    if (-not $NoPathUpdate) {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $entries = @($userPath -split ';' | Where-Object { $_ })
        if ($entries -notcontains $InstallDirectory) {
            [Environment]::SetEnvironmentVariable('Path', (($entries + $InstallDirectory) -join ';'), 'User')
        }
        if (($env:Path -split ';') -notcontains $InstallDirectory) { $env:Path += ";$InstallDirectory" }
    }
    Write-Host "Installed stcli $Version to $target"
    Write-Host 'Run: stcli login'
} finally {
    if ($staged -and (Test-Path -LiteralPath $staged)) { Remove-Item -LiteralPath $staged -Force }
    if ($backup -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    Remove-Item -LiteralPath $work -Recurse -Force
}
# Do not leave gh's unsuccessful authentication probe as the caller's exit code
# after a successful public installation (GitHub's PowerShell runner checks it).
exit 0
