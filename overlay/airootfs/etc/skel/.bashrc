alias neofetch='fastfetch'

if [[ $- == *i* ]] && command -v fastfetch >/dev/null 2>&1 && [[ -z "${FASTFETCH_SHOWN:-}" ]]; then
    export FASTFETCH_SHOWN=1
    fastfetch
fi
