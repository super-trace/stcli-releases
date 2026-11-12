Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$InstallDir = if ($env:STCLI_INSTALL_DIR) { $env:STCLI_INSTALL_DIR } else { Join-Path $env:USERPROFILE ".stcli\bin" }
$GitHubRepo = "super-trace/stcli-releases"
$ApiUrl = if ($env:GITHUB_API_URL) { $env:GITHUB_API_URL } else { "https://api.github.com" }
$ServerUrl = if ($env:GITHUB_SERVER_URL) { $env:GITHUB_SERVER_URL } else { "https://github.com" }

function Get-ApiHeaders {
    $headers = @{ "User-Agent" = "stcli-installer" }
    if ($env:GITHUB_TOKEN) { $headers["Authorization"] = "Bearer $env:GITHUB_TOKEN" }
    return $headers
}

function Invoke-WithRetry([scriptblock]$Request) {
    for ($attempt = 1; ; $attempt++) {
        try { return & $Request } catch {
            if ($attempt -ge 3) { throw }
            Write-Host "Request failed, retrying..."
            Start-Sleep -Seconds 2
        }
    }
}

function Detect-Platform {
    if ($env:OS -ne "Windows_NT") { throw "Use install.sh on macOS, Linux, or WSL." }
    $machine = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    switch ($machine) {
        "AMD64" { $script:ArchLabel = "amd64" }
        "ARM64" { $script:ArchLabel = "arm64" }
        default { throw "Unsupported architecture: $machine. Supported: AMD64, ARM64." }
    }
    # Windows PowerShell 5.1 may otherwise negotiate legacy TLS defaults.
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "Detected: windows $script:ArchLabel"
}

function Get-LatestVersion {
    try {
        $release = Invoke-WithRetry { Invoke-RestMethod -Uri "$ApiUrl/repos/$GitHubRepo/releases/latest" -Headers (Get-ApiHeaders) -UseBasicParsing }
        $script:LatestVersion = $release.tag_name -replace "^v", ""
    } catch {
        throw "Could not determine the latest version: $($_.Exception.Message)`nCheck your internet connection, or set GITHUB_TOKEN if you are being rate limited."
    }
    if (-not $script:LatestVersion) { throw "Could not parse a version from the GitHub release response." }

    if ($env:STCLI_VERSION) {
        $script:Version = $env:STCLI_VERSION -replace "^v", ""
        Write-Host "Installing requested version: v$script:Version (latest is v$script:LatestVersion)"
    } else {
        $script:Version = $script:LatestVersion
        Write-Host "Latest version: v$script:Version"
    }
    if ($script:Version -cnotmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') { throw "Invalid release version." }
}

function Download-And-Verify {
    $archive = "stcli_${script:Version}_windows_${script:ArchLabel}.zip"
    $baseUrl = "$ServerUrl/$GitHubRepo/releases/download/v${script:Version}"

    $script:TmpDir = Join-Path ([IO.Path]::GetTempPath()) "stcli-install-$([Guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $script:TmpDir | Out-Null
    $archivePath = Join-Path $script:TmpDir $archive
    $checksumsPath = Join-Path $script:TmpDir "checksums.txt"

    Write-Host "Downloading stcli v${script:Version}..."
    Invoke-WithRetry { Invoke-WebRequest -Uri "$baseUrl/checksums.txt" -OutFile $checksumsPath -UseBasicParsing }

    $expected = $null
    foreach ($line in Get-Content $checksumsPath) {
        $parts = $line.Trim() -split "\s+", 2
        if ($parts.Count -eq 2 -and $parts[1].Trim() -ceq $archive) {
            if ($expected -or $parts[0] -cnotmatch '^[a-fA-F0-9]{64}$') { throw "Invalid or duplicate checksum for $archive" }
            $expected = $parts[0].ToLowerInvariant()
        }
    }
    if (-not $expected) { throw "Checksum entry not found for $archive" }

    Invoke-WithRetry { Invoke-WebRequest -Uri "$baseUrl/$archive" -OutFile $archivePath -UseBasicParsing }

    Write-Host "Verifying checksum..."
    $actual = (Get-FileHash -Path $archivePath -Algorithm SHA256).Hash.ToLower()
    if ($actual -ne $expected) {
        throw "Checksum verification failed.`n  Expected: $expected`n  Actual:   $actual`nThe downloaded file may be corrupted. Please try again."
    }
    Write-Host "Checksum verified."

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        if ($zip.Entries.Count -ne 1 -or $zip.Entries[0].FullName -ne "stcli.exe") { throw "Unexpected archive contents." }
    } finally { $zip.Dispose() }
    Expand-Archive -Path $archivePath -DestinationPath $script:TmpDir -Force
}

function Install-Binary {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    $src = Join-Path $script:TmpDir "stcli.exe"
    $dest = Join-Path $InstallDir "stcli.exe"
    $old = "$dest.old"

    if (Test-Path $old) { Remove-Item $old -Force -ErrorAction SilentlyContinue }

    # Windows locks a running image against overwrite but allows a rename.
    $movedAside = $false
    if (Test-Path $dest) {
        Move-Item -Path $dest -Destination $old -Force
        $movedAside = $true
    }
    try {
        Move-Item -Path $src -Destination $dest -Force
    } catch {
        if ($movedAside -and -not (Test-Path $dest)) { Move-Item -Path $old -Destination $dest -Force }
        throw
    }
    if (Test-Path $old) { Remove-Item $old -Force -ErrorAction SilentlyContinue }
}

function Send-EnvironmentChange {
    # Registry writes do not notify running processes; broadcast so new terminals see the PATH.
    try {
        if (-not ("Win32.NativeMethods" -as [type])) {
            Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
'@
        }
        $result = [UIntPtr]::Zero
        [Win32.NativeMethods]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, "Environment", 2, 5000, [ref]$result) | Out-Null
    } catch { }
}

function Setup-Path {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("Environment", $true)
    if (-not $key) { throw "Could not open HKCU\Environment to update PATH." }
    try {
        # Read unexpanded and write back with the existing kind, so %VAR% entries survive.
        $current = [string]$key.GetValue("Path", "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $entries = @($current -split ";" | Where-Object { $_ -ne "" })
        if ($entries -contains $InstallDir) { return }
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        try { $kind = $key.GetValueKind("Path") } catch { }
        $newPath = if ([string]::IsNullOrEmpty($current)) { $InstallDir } else { "$InstallDir;$current" }
        $key.SetValue("Path", $newPath, $kind)
    } finally { $key.Dispose() }

    Send-EnvironmentChange
    $env:Path = "$InstallDir;$env:Path"
    Write-Host "Added $InstallDir to user PATH."
    $script:PathUpdated = $true
}

function Print-Success {
    Write-Host ""
    Write-Host "stcli v${script:Version} installed to $InstallDir\stcli.exe"
    Write-Host ""
    if ($script:Version -ne $script:LatestVersion) {
        Write-Host "Note: You installed v${script:Version}, but the latest is v${script:LatestVersion}."
        Write-Host "Re-run this installer without STCLI_VERSION to upgrade."
        Write-Host ""
    }
    if ($script:PathUpdated) { Write-Host "Restart your terminal for PATH changes to take effect, then:" }
    Write-Host "  stcli          - authenticate with your Google or GitHub SSO"
    Write-Host "  stcli --help   - see available commands"
}

$script:Version = ""
$script:LatestVersion = ""
$script:ArchLabel = ""
$script:TmpDir = ""
$script:PathUpdated = $false

# Failures throw rather than exit, so `irm ... | iex` does not close the caller's session.
try {
    Detect-Platform
    Get-LatestVersion
    Download-And-Verify
    Install-Binary
    Setup-Path
    Print-Success
} finally {
    if ($script:TmpDir -and (Test-Path $script:TmpDir)) { Remove-Item -Recurse -Force $script:TmpDir }
}
