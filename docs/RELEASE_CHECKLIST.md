# Livio OS release checklist

Use this checklist before publishing an ISO.

## Before building

- Run `powershell -ExecutionPolicy Bypass -File .\scripts\validate-source.ps1`
- Check that `README.md` and `BUILDING.md` match the current release
- Confirm `packaging/livio-release/os-release` has the intended version text
- Confirm the Calamares installer still shows Livio branding
- Confirm the Fastfetch logo is the Livio logo

## Build

Windows with Docker:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\build-iso-docker.ps1
```

Native Arch:

```bash
./scripts/build-iso.sh
```

## ISO checks

- Boot the ISO in VirtualBox
- Confirm the boot menu says `Livio OS`
- Confirm the KDE live desktop starts
- Open Konsole and confirm `fastfetch` shows the Livio logo
- Run `livioctl status`
- Run `livioctl doctor`
- Start the installer
- Confirm desktop, kernel, and GPU choices are visible
- Install into a blank VM disk
- Boot the installed system
- Run `livio-check-system`
- Run `livioctl doctor`

## Release files

Create checksums:

```powershell
Get-FileHash -Algorithm SHA256 .\livioos-*.iso
```

Publish:

- ISO file or external ISO download link
- SHA256 checksum
- release notes
- known issues
- VM-first warning
- source repo link

## Release warning text

Livio OS is an early preview build. Test it in a virtual machine first. The
installer needs internet access. Back up important data before installing on
real hardware.
