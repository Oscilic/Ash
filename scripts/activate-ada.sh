#!/usr/bin/env bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Usa: source scripts/activate-ada.sh"
    exit 1
fi

ALIRE_BIN="/mnt/ash-dev/toolchains/alire/2.1.1/bin"
GNATPROVE_BIN="$HOME/.local/share/alire/releases/gnatprove_16.1.0_82528bef/bin"

if [[ ! -x "$ALIRE_BIN/alr" || ! -x "$GNATPROVE_BIN/gnatprove" ]]; then
    echo "Error: herramientas Ada/SPARK no encontradas."
    return 1
fi

export PATH="$GNATPROVE_BIN:$ALIRE_BIN:$PATH"

echo "Ash: entorno Ada/SPARK activado."
