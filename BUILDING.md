# Building Livio OS

This guide explains how to build a Livio OS ISO from this repository.

You do not need the old `build/` folder from another developer. The files in
this repository are the source. The `build/` folder is generated again when you
run the build.

## What you need

- A stable internet connection
- At least `40 GB` free disk space
- `8 GB` RAM or more
- Time for the kernel build
- Either Docker Desktop on Windows or a real Arch Linux build environment

The full build creates a custom `linux-livio` kernel. That part can take a long
time. On slower machines it can take hours. If you only want to check whether
the ISO wiring works, you can skip the custom kernel.

## Recommended path on Windows

Use this path if you are on Windows and have Docker Desktop installed.

1. Start Docker Desktop.
2. Open PowerShell in the repository folder.
3. Run the source check:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\validate-source.ps1
```

4. Build the ISO:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-iso-docker.ps1
```

The finished ISO is written to:

```text
build\out
```

The build log is written to:

```text
build\docker-build.log
```

## Faster Windows test build

This skips the custom Livio kernel and only checks the general ISO build path.

```powershell
$env:BUILD_LIVIO_KERNEL="0"
powershell -ExecutionPolicy Bypass -File .\scripts\build-iso-docker.ps1
Remove-Item Env:\BUILD_LIVIO_KERNEL
```

Use the full build again before publishing a release ISO.

## Native Arch Linux build

Use this path if you are already on Arch Linux or inside an Arch VM.

Install the required packages:

```bash
sudo pacman -S --needed \
  archiso rsync base-devel pacman-contrib python git \
  bc cpio gettext libelf openssl pahole rust rust-bindgen rust-src xxhash zstd \
  extra-cmake-modules libglvnd ninja qt6-tools qt6-translations \
  kcoreaddons kpmcore libpwquality qt6-declarative qt6-svg yaml-cpp
```

Run the build:

```bash
./scripts/build-iso.sh
```

For a faster test build without `linux-livio`:

```bash
BUILD_LIVIO_KERNEL=0 ./scripts/build-iso.sh
```

The finished ISO is written to:

```text
build/out
```

## What gets built

The build creates:

- a Livio-branded ArchISO profile
- the live KDE environment
- the Calamares installer package
- the `livio-release` identity package
- the optional `linux-livio` kernel package
- a local `livio-local` package repository inside the ISO
- the final bootable Livio OS ISO

When `BUILD_LIVIO_KERNEL=1`, the build generates `linux-livio` from Arch's
maintained `linux-zen` package recipe and renames it for Livio.

## How to test the ISO

Use a virtual machine first. Do not test a new installer directly on important
hardware.

Basic checks:

1. Boot the ISO in a VM.
2. Confirm the boot menu says `Livio OS`.
3. Confirm the KDE live desktop starts.
4. Start `Install Livio OS` from the desktop.
5. Confirm the installer shows desktop, kernel, and GPU choices.
6. Install into a blank virtual disk.
7. Boot the installed system.
8. Run:

```bash
livio-check-system
```

The installer currently expects internet access during installation because it
uses Arch package repositories for the target system.

## Common problems

### Docker is not running

Start Docker Desktop and run the build again.

### Not enough disk space

Remove old generated output from `build/` or build on a drive with more free
space. The source files do not need to be deleted.

### The kernel build takes too long

Run a test build with:

```powershell
$env:BUILD_LIVIO_KERNEL="0"
powershell -ExecutionPolicy Bypass -File .\scripts\build-iso-docker.ps1
Remove-Item Env:\BUILD_LIVIO_KERNEL
```

Then run the full build later.

### Pacman or mirror errors

Try again later or use a better network connection. The build depends on Arch
repositories, and the installer also needs working package mirrors.

### The installer fails inside the VM

Check that the VM has internet access. Use a blank virtual disk for the test.
After a failed install, create a fresh VM disk and try again.

## What belongs in GitHub

The repository should contain the source files, package recipes, installer
configuration, scripts, and documentation.

The repository should not contain generated ISO files or the generated `build/`
folder. Those files are large, machine-made artifacts. They can be rebuilt from
the source.
