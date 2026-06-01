#!/usr/bin/env bash
set -euo pipefail

shopt -s nullglob

release_pkgs=(/root/livio-pkgs/livio-release-*.pkg.tar.zst)
local_pkgs=(/root/livio-pkgs/*.pkg.tar.zst)

if (( ${#local_pkgs[@]} > 0 )); then
    tmp_pacman_conf="$(mktemp)"
    cp /etc/pacman.conf "$tmp_pacman_conf"
    sed -i '/^[[:space:]]*CheckSpace$/d' "$tmp_pacman_conf"
    pacman --config "$tmp_pacman_conf" -U --noconfirm "${local_pkgs[@]}"
    rm -f "$tmp_pacman_conf"
    rm -rf /root/livio-pkgs
fi

if (( ${#release_pkgs[@]} == 0 )) || ! grep -q '^ID=livio$' /usr/lib/os-release; then
    echo "Livio release package was not installed correctly." >&2
    exit 1
fi

if ! id -u livio >/dev/null 2>&1; then
    useradd -m -g users -G wheel,audio,video,storage,network,power,input,render,games -s /bin/bash livio
fi

passwd -d livio
cp -a /etc/skel/. /home/livio/
mkdir -p /home/livio/Desktop
chmod 755 /usr/local/bin/livio-bootstrap-target
chmod 755 /usr/local/bin/livio-check-system
chmod 755 /usr/local/bin/livio-detect-gpu
chmod 755 /usr/local/bin/livio-start-installer
chmod 755 /usr/local/bin/livio-install-heroic
chmod 755 /home/livio/Desktop/Install\ Livio\ OS.desktop
chmod 440 /etc/sudoers.d/10-livio-live
chown -R livio:users /home/livio

ln -sf /usr/lib/systemd/system/multi-user.target /etc/systemd/system/default.target

systemctl enable NetworkManager.service
systemctl enable bluetooth.service
systemctl enable fstrim.timer
systemctl enable systemd-timesyncd.service
