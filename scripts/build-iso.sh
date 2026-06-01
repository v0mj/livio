#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_PROFILE="${BASE_PROFILE:-/usr/share/archiso/configs/releng}"
PROFILE_DIR="${PROFILE_DIR:-$ROOT_DIR/build/profile}"
WORK_DIR="${WORK_DIR:-$ROOT_DIR/build/work}"
OUT_DIR="${OUT_DIR:-$ROOT_DIR/build/out}"
CALAMARES_SRC_DIR="${CALAMARES_SRC_DIR:-$ROOT_DIR/packaging/calamares}"
CALAMARES_BUILD_DIR="${CALAMARES_BUILD_DIR:-$ROOT_DIR/build/calamares}"
RELEASE_SRC_DIR="${RELEASE_SRC_DIR:-$ROOT_DIR/packaging/livio-release}"
RELEASE_BUILD_DIR="${RELEASE_BUILD_DIR:-$ROOT_DIR/build/livio-release}"
LIVIOCTL_SRC_DIR="${LIVIOCTL_SRC_DIR:-$ROOT_DIR/packaging/livioctl}"
LIVIOCTL_BUILD_DIR="${LIVIOCTL_BUILD_DIR:-$ROOT_DIR/build/livioctl}"
BUILD_LIVIO_KERNEL="${BUILD_LIVIO_KERNEL:-1}"
KERNEL_SRC_DIR="${KERNEL_SRC_DIR:-$ROOT_DIR/packaging/linux-livio}"
KERNEL_SOURCE_DIR="${KERNEL_SOURCE_DIR:-$ROOT_DIR/build/linux-livio-source}"
KERNEL_BUILD_DIR="${KERNEL_BUILD_DIR:-$ROOT_DIR/build/linux-livio}"
LIVIO_REPO_SIGN_KEY="${LIVIO_REPO_SIGN_KEY:-}"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_cmd mkarchiso
require_cmd rsync
require_cmd sed
require_cmd awk
require_cmd date
require_cmd makepkg
require_cmd repo-add

if [[ ! -d "$BASE_PROFILE" ]]; then
    echo "Base archiso profile not found: $BASE_PROFILE" >&2
    echo "Install the archiso package on an Arch Linux build host first." >&2
    exit 1
fi

if [[ ! -d "$CALAMARES_SRC_DIR" ]]; then
    echo "Missing Calamares packaging directory: $CALAMARES_SRC_DIR" >&2
    exit 1
fi

if [[ ! -d "$RELEASE_SRC_DIR" ]]; then
    echo "Missing Livio release packaging directory: $RELEASE_SRC_DIR" >&2
    exit 1
fi

if [[ ! -d "$LIVIOCTL_SRC_DIR" ]]; then
    echo "Missing livioctl packaging directory: $LIVIOCTL_SRC_DIR" >&2
    exit 1
fi

if [[ "$BUILD_LIVIO_KERNEL" == "1" && ! -f "$KERNEL_SRC_DIR/prepare-source.sh" ]]; then
    echo "Missing Livio kernel source preparer: $KERNEL_SRC_DIR/prepare-source.sh" >&2
    exit 1
fi

build_arch_package() {
    local -n out_paths="$1"
    local source_dir="$2"
    local build_dir="$3"
    local package_glob="$4"
    local display_name="$5"
    shift 5
    local makepkg_flags=("$@")

    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    rsync -a "$source_dir/" "$build_dir/"

    if [[ "$(id -u)" -eq 0 ]]; then
        if ! id -u livio-builder >/dev/null 2>&1; then
            useradd -m -s /bin/bash livio-builder
        fi

        chown -R livio-builder:livio-builder "$build_dir"
        runuser -u livio-builder -- bash -lc "cd '$build_dir' && makepkg -df --noconfirm ${makepkg_flags[*]}"
    else
        ( cd "$build_dir" && makepkg -df --noconfirm "${makepkg_flags[@]}" )
    fi

    mapfile -t out_paths < <(find "$build_dir" -maxdepth 1 -type f -name "$package_glob" | sort)
    if [[ "${#out_paths[@]}" -eq 0 ]]; then
        echo "$display_name package build did not produce a package archive." >&2
        exit 1
    fi
}

brand_boot_menus() {
    local boot_file
    local boot_roots=()
    local boot_root

    for boot_root in \
        "$PROFILE_DIR/boot" \
        "$PROFILE_DIR/loader" \
        "$PROFILE_DIR/syslinux" \
        "$PROFILE_DIR/grub" \
        "$PROFILE_DIR/efiboot/loader"; do
        if [[ -d "$boot_root" ]]; then
            boot_roots+=("$boot_root")
        fi
    done

    if [[ "${#boot_roots[@]}" -eq 0 ]]; then
        return
    fi

    while IFS= read -r -d '' boot_file; do
        sed -i \
            -e 's|Arch Linux install medium|Livio OS live/install medium|g' \
            -e 's|Boot the Arch Linux install medium|Boot the Livio OS live/install medium|g' \
            -e 's|install Arch Linux or perform system maintenance|try or install Livio OS and perform system maintenance|g' \
            -e 's|install Arch Linux|try or install Livio OS|g' \
            "$boot_file"
    done < <(find "${boot_roots[@]}" -type f \( -name '*.cfg' -o -name '*.conf' \) -print0)
}

build_local_package_repo() {
    local repo_dir="$1"

    if ! compgen -G "$repo_dir/*.pkg.tar.zst" >/dev/null; then
        return 0
    fi

    (
        cd "$repo_dir"
        rm -f livio-local.db livio-local.db.tar.zst livio-local.files livio-local.files.tar.zst
        if [[ -n "$LIVIO_REPO_SIGN_KEY" ]]; then
            repo-add --sign --key "$LIVIO_REPO_SIGN_KEY" -n -R livio-local.db.tar.zst ./*.pkg.tar.zst
        else
            repo-add -n -R livio-local.db.tar.zst ./*.pkg.tar.zst
        fi
    )
}

calamares_pkg_paths=()
release_pkg_paths=()
livioctl_pkg_paths=()
kernel_pkg_paths=()
build_arch_package calamares_pkg_paths "$CALAMARES_SRC_DIR" "$CALAMARES_BUILD_DIR" 'calamares-[0-9]*-x86_64.pkg.tar.zst' "Calamares"
build_arch_package release_pkg_paths "$RELEASE_SRC_DIR" "$RELEASE_BUILD_DIR" 'livio-release-*.pkg.tar.zst' "Livio release"
build_arch_package livioctl_pkg_paths "$LIVIOCTL_SRC_DIR" "$LIVIOCTL_BUILD_DIR" 'livioctl-[0-9]*-x86_64.pkg.tar.zst' "livioctl"

if [[ "$BUILD_LIVIO_KERNEL" == "1" ]]; then
    bash "$KERNEL_SRC_DIR/prepare-source.sh" "$KERNEL_SOURCE_DIR"
    build_arch_package kernel_pkg_paths "$KERNEL_SOURCE_DIR" "$KERNEL_BUILD_DIR" 'linux-livio-*.pkg.tar.zst' "Livio gaming kernel" "--skippgpcheck"
else
    echo "Skipping linux-livio build because BUILD_LIVIO_KERNEL=$BUILD_LIVIO_KERNEL"
fi

rm -rf "$PROFILE_DIR"
rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR" "$OUT_DIR"

rsync -a --delete "$BASE_PROFILE/" "$PROFILE_DIR/"
rsync -a "$ROOT_DIR/overlay/" "$PROFILE_DIR/"
cat "$ROOT_DIR/config/live-packages.x86_64" >> "$PROFILE_DIR/packages.x86_64"

awk '!seen[$0]++' "$PROFILE_DIR/packages.x86_64" > "$PROFILE_DIR/packages.x86_64.tmp"
mv "$PROFILE_DIR/packages.x86_64.tmp" "$PROFILE_DIR/packages.x86_64"

sed -i 's/^iso_name=.*/iso_name="livioos"/' "$PROFILE_DIR/profiledef.sh"
sed -i "s/^iso_label=.*/iso_label=\"LIVIO_$(date +%Y%m)\"/" "$PROFILE_DIR/profiledef.sh"
sed -i 's|^iso_publisher=.*|iso_publisher="Livio OS"|' "$PROFILE_DIR/profiledef.sh"
sed -i 's|^iso_application=.*|iso_application="Livio OS Live/Install Medium"|' "$PROFILE_DIR/profiledef.sh"
sed -i 's/^install_dir=.*/install_dir="livio"/' "$PROFILE_DIR/profiledef.sh"

mkdir -p "$PROFILE_DIR/airootfs/root/livio-pkgs"
mkdir -p "$PROFILE_DIR/airootfs/usr/share/livio/packages"
for package_path in "${calamares_pkg_paths[@]}" "${release_pkg_paths[@]}" "${livioctl_pkg_paths[@]}"; do
    cp "$package_path" "$PROFILE_DIR/airootfs/root/livio-pkgs/"
done
for package_path in "${release_pkg_paths[@]}" "${livioctl_pkg_paths[@]}" "${kernel_pkg_paths[@]}"; do
    cp "$package_path" "$PROFILE_DIR/airootfs/usr/share/livio/packages/"
done
build_local_package_repo "$PROFILE_DIR/airootfs/usr/share/livio/packages"

brand_boot_menus

chmod 755 \
    "$PROFILE_DIR/airootfs/root/customize_airootfs.sh" \
    "$PROFILE_DIR/airootfs/usr/local/bin/livio-bootstrap-target" \
    "$PROFILE_DIR/airootfs/usr/local/bin/livio-check-system" \
    "$PROFILE_DIR/airootfs/usr/local/bin/livio-detect-gpu" \
    "$PROFILE_DIR/airootfs/usr/local/bin/livio-start-installer" \
    "$PROFILE_DIR/airootfs/usr/local/bin/livio-install-heroic"
chmod 755 "$PROFILE_DIR/airootfs/etc/skel/Desktop/Install Livio OS.desktop"

echo "Building Livio OS ISO..."
echo "  Base profile : $BASE_PROFILE"
echo "  Profile dir  : $PROFILE_DIR"
echo "  Work dir     : $WORK_DIR"
echo "  Output dir   : $OUT_DIR"
echo "  Calamares    : $CALAMARES_BUILD_DIR"
echo "  Livio release: $RELEASE_BUILD_DIR"
echo "  livioctl     : $LIVIOCTL_BUILD_DIR"
echo "  Livio kernel : $BUILD_LIVIO_KERNEL"

mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$PROFILE_DIR"
