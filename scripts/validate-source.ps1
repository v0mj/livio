$ErrorActionPreference = "Stop"

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$errors = New-Object System.Collections.Generic.List[string]

function Add-Error {
  param([string]$Message)
  $errors.Add($Message) | Out-Null
}

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )
  if (-not $Condition) {
    Add-Error $Message
  }
}

function Read-Text {
  param([string]$RelativePath)
  Get-Content -LiteralPath (Join-Path $root $RelativePath) -Raw
}

$requiredFiles = @(
  "README.md",
  "config\live-packages.x86_64",
  "scripts\build-iso.sh",
  "scripts\build-iso-docker.ps1",
  "packaging\calamares\PKGBUILD",
  "packaging\linux-livio\prepare-source.sh",
  "packaging\livio-release\PKGBUILD",
  "packaging\livio-release\issue",
  "packaging\livio-release\issue.net",
  "packaging\livio-release\livio-logo.svg",
  "packaging\livio-release\livio-release.install",
  "packaging\livio-release\os-release",
  "packaging\livio-release\lsb-release",
  "overlay\airootfs\root\customize_airootfs.sh",
  "overlay\airootfs\usr\local\bin\livio-bootstrap-target",
  "overlay\airootfs\usr\local\bin\livio-check-system",
  "overlay\airootfs\usr\local\bin\livio-detect-gpu",
  "overlay\airootfs\usr\local\bin\livio-install-heroic",
  "overlay\airootfs\usr\local\bin\livio-start-installer",
  "overlay\airootfs\etc\calamares\settings.conf",
  "overlay\airootfs\etc\calamares\modules\netinstall.yaml",
  "overlay\airootfs\etc\calamares\modules\packagechooser_kernel.conf",
  "overlay\airootfs\etc\calamares\modules\packagechooser_desktop.conf",
  "overlay\airootfs\etc\calamares\modules\packagechooser_gpu.conf",
  "overlay\airootfs\etc\skel\.config\fastfetch\config.jsonc"
)

foreach ($relativePath in $requiredFiles) {
  Assert-True (Test-Path -LiteralPath (Join-Path $root $relativePath)) "Missing required file: $relativePath"
}

if ($errors.Count -eq 0) {
  $settings = Read-Text "overlay\airootfs\etc\calamares\settings.conf"
  Assert-True ($settings -match "shellprocess@bootstrap") "Calamares sequence must run shellprocess@bootstrap."
  Assert-True ($settings -match "packagechooser@kernel") "Calamares sequence must offer the kernel chooser."
  Assert-True ($settings -notmatch "(?m)^\s*-\s*pacstrap\s*$") "Calamares source settings should not use the old bare pacstrap step."
  Assert-True ($settings -match "branding:\s*livio") "Calamares branding must be livio."

  $buildScript = Read-Text "scripts\build-iso.sh"
  Assert-True ($buildScript -match "brand_boot_menus") "Build script must patch inherited Arch boot menu labels."
  Assert-True (($buildScript -match "syslinux") -and ($buildScript -match "grub") -and ($buildScript -match "efiboot/loader")) "Boot menu branding must cover BIOS, GRUB and UEFI profile files."
  Assert-True ($buildScript -match "livio-release") "Build script must build and copy livio-release."
  Assert-True ($buildScript -match "BUILD_LIVIO_KERNEL") "Build script must support the linux-livio package build."
  Assert-True ($buildScript -match "repo-add") "Build script must create a local Livio package repository."
  Assert-True ($buildScript -match 'iso_name="livioos"') "Build script must set the ISO name to livioos."
  Assert-True ($buildScript -match 'install_dir="livio"') "Build script must set the archiso install_dir to livio."

  $customizeScript = Read-Text "overlay\airootfs\root\customize_airootfs.sh"
  Assert-True ($customizeScript -match "livio-release") "Live customizer must install livio-release from local packages."
  Assert-True ($customizeScript -notmatch "cat\s+>\s+/usr/lib/os-release") "Live identity should come from livio-release, not heredoc writes."

  $bootstrapScript = Read-Text "overlay\airootfs\usr\local\bin\livio-bootstrap-target"
  Assert-True ($bootstrapScript -match "retry 3 15 pacstrap") "Target bootstrap must retry pacstrap."
  Assert-True ($bootstrapScript -match "arch-chroot.*livio-release") "Target bootstrap must install livio-release in the target."
  Assert-True ($bootstrapScript -match "\[livio-local\]") "Target bootstrap must configure the local Livio package repository."
  Assert-True ($bootstrapScript -match "linux-lts") "Target bootstrap must keep the LTS fallback kernel."

  $gpuScript = Read-Text "overlay\airootfs\usr\local\bin\livio-detect-gpu"
  Assert-True ($gpuScript -match "gpu-nvidia") "GPU detection must know the NVIDIA choice."
  Assert-True ($gpuScript -match "gpu-hybrid") "GPU detection must know the hybrid choice."

  $packageList = Get-Content -LiteralPath (Join-Path $root "config\live-packages.x86_64") |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith("#") }
  $duplicatePackages = $packageList | Group-Object | Where-Object { $_.Count -gt 1 }
  Assert-True ($duplicatePackages.Count -eq 0) ("Duplicate live packages: " + (($duplicatePackages | ForEach-Object { $_.Name }) -join ", "))

  $netinstall = Read-Text "overlay\airootfs\etc\calamares\modules\netinstall.yaml"
  $chooserIds = @()
  foreach ($chooser in @("packagechooser_kernel.conf", "packagechooser_desktop.conf", "packagechooser_gpu.conf")) {
    $chooserText = Read-Text "overlay\airootfs\etc\calamares\modules\$chooser"
    $chooserIds += [regex]::Matches($chooserText, "(?m)^\s*-\s+id:\s*([a-z0-9-]+)\s*$") | ForEach-Object { $_.Groups[1].Value }
  }
  foreach ($chooserId in $chooserIds) {
    Assert-True ($netinstall -match [regex]::Escape("name: `"$chooserId`"")) "Package chooser id has no matching netinstall group: $chooserId"
  }
  Assert-True ($netinstall -match "linux-livio") "Netinstall must expose the linux-livio package group."

  try {
    Read-Text "overlay\airootfs\etc\skel\.config\fastfetch\config.jsonc" | ConvertFrom-Json | Out-Null
  } catch {
    Add-Error "Fastfetch JSON config is invalid: $($_.Exception.Message)"
  }

  Get-ChildItem -LiteralPath (Join-Path $root "overlay") -Recurse -Filter *.svg | ForEach-Object {
    try {
      [xml](Get-Content -LiteralPath $_.FullName -Raw) | Out-Null
    } catch {
      Add-Error "Invalid SVG XML: $($_.FullName)"
    }
  }

  $shellScripts = @(
    "scripts\build-iso.sh",
    "packaging\linux-livio\prepare-source.sh",
    "overlay\airootfs\root\customize_airootfs.sh",
    "overlay\airootfs\usr\local\bin\livio-bootstrap-target",
    "overlay\airootfs\usr\local\bin\livio-check-system",
    "overlay\airootfs\usr\local\bin\livio-detect-gpu",
    "overlay\airootfs\usr\local\bin\livio-install-heroic",
    "overlay\airootfs\usr\local\bin\livio-start-installer"
  )
  foreach ($relativePath in $shellScripts) {
    $fullPath = Join-Path $root $relativePath
    $firstLine = Get-Content -LiteralPath $fullPath -First 1
    $scriptText = Get-Content -LiteralPath $fullPath -Raw
    Assert-True ($firstLine -eq "#!/usr/bin/env bash") "Shell script missing bash shebang: $relativePath"
    Assert-True ($scriptText -match "set -euo pipefail") "Shell script missing strict mode: $relativePath"
  }
}

if ($errors.Count -gt 0) {
  Write-Host "Livio source validation failed:" -ForegroundColor Red
  foreach ($errorMessage in $errors) {
    Write-Host " - $errorMessage" -ForegroundColor Red
  }
  exit 1
}

Write-Host "Livio source validation passed." -ForegroundColor Green
