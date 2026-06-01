if [[ -z "${WAYLAND_DISPLAY:-}" && -z "${DISPLAY:-}" && "$(tty)" == "/dev/tty1" ]]; then
    if systemd-detect-virt --quiet --vm; then
        exec startx /usr/bin/startplasma-x11 -- :0
    fi

    export XDG_SESSION_TYPE=wayland
    exec dbus-run-session startplasma-wayland
fi
