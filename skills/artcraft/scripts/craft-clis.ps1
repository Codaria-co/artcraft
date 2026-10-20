<#
Install, update and check the ArtCraft Crafting Apps command-line tools (Windows).

  craft-clis.ps1 list                    apps this script knows
  craft-clis.ps1 check   [app ...]       installed vs latest release
  craft-clis.ps1 install [app ...]       install missing CLIs, update outdated ones
  craft-clis.ps1 update  [app ...]       same as install

Env: ARTCRAFT_BIN_DIR (default %LOCALAPPDATA%\Programs\artcraft\bin), GITHUB_TOKEN (optional).
Every download is checked against the release's SHA256SUMS.txt before anything is extracted.
The CLI comes from the app's portable zip (<app>-<ver>-windows-<arch>-portable.zip).
#>
param(
  [Parameter(Position = 0)][string]$Command = 'help',
  [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Apps = @()
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$AllApps = @('photocraft', 'vectorcraft', 'filmcraft', 'effectcraft', 'pdfcraft', 'deckcraft', 'gridcraft',
  'wordcraft', 'lightcraft', 'designcraft', 'soundcraft', 'cadcraft', 'figcraft')
$Org = 'storytold'
$BinDir = if ($env:ARTCRAFT_BIN_DIR) { $env:ARTCRAFT_BIN_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs\artcraft\bin' }

function Get-Headers {
  $h = @{ 'User-Agent' = 'artcraft-craft-clis' }
  if ($env:GITHUB_TOKEN) { $h['Authorization'] = "Bearer $($env:GITHUB_TOKEN)" }
  return $h
}

function Get-Arch {
  switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'x64' }
    'ARM64' { 'arm64' }
    'x86' { 'x86' }
    default { throw "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
  }
}

function Get-LatestVersion([string]$App) {
  $r = Invoke-RestMethod -Headers (Get-Headers) -Uri "https://api.github.com/repos/$Org/$App/releases/latest"
  $tag = [string]$r.tag_name
  if ($tag -notmatch '^v?\d+(\.\d+)*$') { throw "unexpected tag for ${App}: $tag" }
  return $tag.TrimStart('v')
}

function Get-InstalledVersion([string]$App) {
  $exe = Join-Path $BinDir "$App-cli.exe"
  if (-not (Test-Path -LiteralPath $exe)) { return $null }
  $out = (& $exe --version 2>$null | Select-Object -First 1)
  if ($out -match '(\d+(\.\d+)+)') { return $Matches[1] }
  return $null
}

function Select-Apps([string[]]$Names) {
  if (-not $Names -or $Names.Count -eq 0) { return $AllApps }
  foreach ($n in $Names) {
    $a = $n.ToLowerInvariant() -replace '-cli$', ''
    if ($AllApps -notcontains $a) { throw "unknown app: $a (try: list)" }
    $a
  }
}

function Install-One([string]$App, [string]$Ver) {
  $arch = Get-Arch
  $asset = "$App-$Ver-windows-$arch-portable.zip"
  $member = "$App-$Ver-windows-$arch-portable/$App-cli.exe"
  $base = "https://github.com/$Org/$App/releases/download/v$Ver"
  $tmp = Join-Path ([IO.Path]::GetTempPath()) ("craft-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $tmp | Out-Null
  try {
    Write-Host "  downloading $asset"
    Invoke-WebRequest -UseBasicParsing -Headers (Get-Headers) -Uri "$base/SHA256SUMS.txt" -OutFile "$tmp\SHA256SUMS.txt"
    Invoke-WebRequest -UseBasicParsing -Headers (Get-Headers) -Uri "$base/$asset" -OutFile "$tmp\$asset"

    $want = $null
    foreach ($line in Get-Content -LiteralPath "$tmp\SHA256SUMS.txt") {
      $parts = $line -split '\s+', 2
      if ($parts.Count -eq 2 -and $parts[1].TrimStart('*') -eq $asset) { $want = $parts[0].ToLowerInvariant(); break }
    }
    if (-not $want) { throw "$asset is not listed in SHA256SUMS.txt" }
    $got = (Get-FileHash -Algorithm SHA256 -LiteralPath "$tmp\$asset").Hash.ToLowerInvariant()
    if ($want -ne $got) { throw "CHECKSUM MISMATCH for $asset (want $want, got $got)" }

    # Extract only the CLI entry; never expand the whole archive.
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$tmp\$asset")
    try {
      $entry = $zip.Entries | Where-Object { $_.FullName -eq $member } | Select-Object -First 1
      if (-not $entry) { throw "$member not found in $asset" }
      New-Item -ItemType Directory -Force -Path $BinDir | Out-Null
      $staged = Join-Path $BinDir ".$App-cli.new.exe"
      [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $staged, $true)
    } finally { $zip.Dispose() }

    $sig = Get-AuthenticodeSignature -LiteralPath $staged
    if ($sig.Status -ne 'Valid') { Write-Warning "  $App-cli.exe Authenticode status: $($sig.Status)" }

    Move-Item -Force -LiteralPath $staged -Destination (Join-Path $BinDir "$App-cli.exe")
    Write-Host "  installed $(Join-Path $BinDir "$App-cli.exe")"
  } finally {
    Remove-Item -Recurse -Force -LiteralPath $tmp -ErrorAction SilentlyContinue
  }
}

function Add-ToUserPath {
  $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $parts = @($userPath -split ';' | Where-Object { $_ })
  if ($parts -notcontains $BinDir) {
    [Environment]::SetEnvironmentVariable('Path', (($parts + $BinDir) -join ';'), 'User')
    Write-Host "added $BinDir to the user PATH (open a new terminal to use it)"
  }
}

switch ($Command) {
  'list' { $AllApps }
  'check' {
    $rc = 0
    '{0,-12} {1,-10} {2,-10} {3}' -f 'APP', 'INSTALLED', 'LATEST', 'STATUS'
    foreach ($a in Select-Apps $Apps) {
      $cur = Get-InstalledVersion $a
      try { $new = Get-LatestVersion $a } catch { $new = $null }
      $status = if (-not $new) { 'latest-unknown' } elseif (-not $cur) { $rc = 1; 'missing' }
                elseif ([version]$cur -lt [version]$new) { $rc = 1; 'outdated' } else { 'ok' }
      '{0,-12} {1,-10} {2,-10} {3}' -f $a, ($(if ($cur) { $cur } else { '-' })), ($(if ($new) { $new } else { '-' })), $status
    }
    exit $rc
  }
  { $_ -in 'install', 'update' } {
    $failed = @()
    foreach ($a in Select-Apps $Apps) {
      try {
        $new = Get-LatestVersion $a
        $cur = Get-InstalledVersion $a
        if ($cur -and -not ([version]$cur -lt [version]$new)) { Write-Host "$a-cli $cur is up to date"; continue }
        Write-Host "$a-cli $(if ($cur) { $cur } else { 'not installed' }) -> $new"
        Install-One $a $new
      } catch { Write-Warning "${a}: $_"; $failed += $a }
    }
    Add-ToUserPath
    if ($failed.Count -gt 0) { Write-Error "failed: $($failed -join ' ')"; exit 1 }
  }
  default { (Get-Content -LiteralPath $PSCommandPath -TotalCount 12 | Select-Object -Skip 1) -join "`n" }
}
