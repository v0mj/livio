$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

$workspace = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$buildDir = Join-Path $workspace "build"
$hostOutDir = if ($env:HOST_OUT_DIR) { $env:HOST_OUT_DIR } else { (Join-Path $buildDir "out") }
$hostOutDir = if ([System.IO.Path]::IsPathRooted($hostOutDir)) { $hostOutDir } else { (Join-Path $workspace $hostOutDir) }
$hostOutDir = [System.IO.Path]::GetFullPath($hostOutDir)
$workspaceRoot = [System.IO.Path]::GetFullPath($workspace.TrimEnd('\') + '\')
if (-not $hostOutDir.StartsWith($workspaceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "HOST_OUT_DIR must be inside $workspace"
}
$hostOutDirRelative = $hostOutDir.Substring($workspace.Length).TrimStart('\').Replace('\', '/')
$logPath = if ($env:BUILD_LOG_PATH) { $env:BUILD_LOG_PATH } else { Join-Path $buildDir "docker-build.log" }
$logPath = if ([System.IO.Path]::IsPathRooted($logPath)) { $logPath } else { Join-Path $workspace $logPath }
$logPath = [System.IO.Path]::GetFullPath($logPath)
$stderrPath = "$logPath.stderr"
$dockerScriptPath = Join-Path $buildDir ".livio-docker-build.sh"
$containerName = "livio-iso-build"
$hostWorkspaceMount = "/host-workspace"
$containerWorkspace = "/tmp/livio-src"
$buildLivioKernel = if ($env:BUILD_LIVIO_KERNEL) { $env:BUILD_LIVIO_KERNEL } else { "1" }

function ConvertTo-WindowsArgument {
  param([string]$Argument)

  if ($Argument.Length -eq 0) {
    return '""'
  }

  if ($Argument -notmatch '[\s"]') {
    return $Argument
  }

  $builder = [System.Text.StringBuilder]::new()
  [void]$builder.Append('"')
  $backslashes = 0

  foreach ($character in $Argument.ToCharArray()) {
    if ($character -eq [char]92) {
      $backslashes++
      continue
    }

    if ($character -eq [char]34) {
      [void]$builder.Append('\' * (($backslashes * 2) + 1))
      [void]$builder.Append('"')
      $backslashes = 0
      continue
    }

    if ($backslashes -gt 0) {
      [void]$builder.Append('\' * $backslashes)
      $backslashes = 0
    }

    [void]$builder.Append($character)
  }

  if ($backslashes -gt 0) {
    [void]$builder.Append('\' * ($backslashes * 2))
  }

  [void]$builder.Append('"')
  return $builder.ToString()
}

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $workspace "scripts\validate-source.ps1")

docker version | Out-Null
$existingContainer = docker ps -aq -f "name=^${containerName}$"
if ($existingContainer) {
  docker rm -f $containerName | Out-Null
}

$linuxScript = @'
set -euo pipefail
host_workspace=/host-workspace
container_workspace=/tmp/livio-src
export MAKEFLAGS="${MAKEFLAGS:--j$(nproc)}"

pacman -Sy --noconfirm \
  archiso rsync base-devel pacman-contrib python git \
  bc cpio gettext libelf openssl pahole rust rust-bindgen rust-src xxhash zstd \
  extra-cmake-modules libglvnd ninja qt6-tools qt6-translations \
  kcoreaddons kpmcore libpwquality qt6-declarative qt6-svg yaml-cpp

rm -rf "$container_workspace"
mkdir -p "$container_workspace"
rsync -a --delete --exclude build/ "$host_workspace/" "$container_workspace/"

cd "$container_workspace"
bash scripts/build-iso.sh

host_out_dir="${HOST_OUT_DIR:-/host-workspace/build/out}"
rm -rf "$host_out_dir"
mkdir -p "$host_out_dir"
cp -a build/out/. "$host_out_dir/"
if [[ -d build/profile/airootfs/usr/share/livio/packages ]]; then
  mkdir -p "$host_out_dir/packages"
  cp -a build/profile/airootfs/usr/share/livio/packages/. "$host_out_dir/packages/"
fi
'@

try {
  [System.IO.File]::WriteAllText(
    $dockerScriptPath,
    $linuxScript.Replace("`r`n", "`n"),
    [System.Text.UTF8Encoding]::new($false)
  )

  Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $logPath, $stderrPath

  $dockerArgs = @(
    "run",
    "--name", $containerName,
    "--privileged",
    "-v", "${workspace}:${hostWorkspaceMount}",
    "-w", "/",
    "-e", "HOST_OUT_DIR=/host-workspace/$hostOutDirRelative",
    "-e", "BUILD_LIVIO_KERNEL=$buildLivioKernel",
    "archlinux:latest",
    "bash", "/host-workspace/build/.livio-docker-build.sh"
  )

  $dockerArgumentLine = ($dockerArgs | ForEach-Object { ConvertTo-WindowsArgument $_ }) -join " "
  $dockerProcess = Start-Process `
    -FilePath "docker" `
    -ArgumentList $dockerArgumentLine `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError $stderrPath
  $dockerExitCode = $dockerProcess.ExitCode

  if (Test-Path -LiteralPath $stderrPath) {
    $stderrText = Get-Content -Raw -LiteralPath $stderrPath
    if ($stderrText) {
      Add-Content -LiteralPath $logPath -Value ""
      Add-Content -LiteralPath $logPath -Value $stderrText
    }
  }
}
finally {
  Remove-Item -Force -ErrorAction SilentlyContinue -LiteralPath $dockerScriptPath, $stderrPath
}

if ($dockerExitCode -ne 0) {
  throw "Docker build failed. See $logPath"
}
