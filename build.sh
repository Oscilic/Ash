#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# ASH OPERATING SYSTEM
# Build Script - IA-32 / Multiboot2
# ============================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SRC_DIR="$ROOT_DIR/src"
BUILD_DIR="$ROOT_DIR/build"

OBJ_DIR="$BUILD_DIR/obj"
BIN_DIR="$BUILD_DIR/bin"
ISO_DIR="$BUILD_DIR/iso"

BOOT_SRC="$SRC_DIR/boot/x86/boot.s"
KERNEL_SRC="$SRC_DIR/kernel/main.zig"

LINKER_SCRIPT="$ROOT_DIR/config/linker/x86.ld"
GRUB_CONFIG="$ROOT_DIR/config/grub/grub.cfg"

KERNEL_ELF="$BIN_DIR/kernel.elf"
ASH_ISO="$BUILD_DIR/ash.iso"

echo "========================================"
echo " ASH Operating System - Build"
echo " Target: IA-32"
echo " Boot: Multiboot2 / GRUB2"
echo "========================================"

# ------------------------------------------------------------
# 1. Prepare directories
# ------------------------------------------------------------

echo "[1/6] Preparing directories..."

mkdir -p "$OBJ_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$ISO_DIR/boot/grub"

# ------------------------------------------------------------
# 2. Assemble boot.s
# ------------------------------------------------------------

echo "[2/6] Assembling boot.s..."

as --32 \
    "$BOOT_SRC" \
    -o "$OBJ_DIR/boot.o"
as --32 \
    src/arch/x86/exceptions.s \
    -o build/obj/exceptions.o
# ------------------------------------------------------------
# 3. Compile Zig kernel
# ------------------------------------------------------------

echo "[3/6] Compiling Zig kernel..."

zig build-obj \
    "$SRC_DIR/root.zig" \
    -target x86-freestanding-none \
    -O ReleaseFast \
    -fno-stack-check \
    -femit-bin="$OBJ_DIR/kernel.o"

# ------------------------------------------------------------
# 4. Link kernel
# ------------------------------------------------------------

echo "[4/6] Linking kernel..."

ld -m elf_i386 \
    -z max-page-size=0x1000 \
    -T config/linker/x86.ld \
    -o build/bin/kernel.elf \
    build/obj/boot.o \
    build/obj/exceptions.o \
    build/obj/kernel.o

# ------------------------------------------------------------
# 5. Validate Multiboot2
# ------------------------------------------------------------

echo "[5/6] Validating Multiboot2..."

if ! grub2-file --is-x86-multiboot2 "$KERNEL_ELF"; then
    echo "[ERROR] Invalid Multiboot2 kernel!"
    exit 1
fi

echo "[OK] Multiboot2 header validated."

# ------------------------------------------------------------
# 6. Generate ISO
# ------------------------------------------------------------

echo "[6/6] Generating ISO..."

cp "$KERNEL_ELF" "$ISO_DIR/boot/kernel.elf"
cp "$GRUB_CONFIG" "$ISO_DIR/boot/grub/grub.cfg"

grub2-mkrescue \
    -o "$ASH_ISO" \
    "$ISO_DIR"

echo
echo "========================================"
echo " ASH Build Successful!"
echo "========================================"
echo " Kernel: $KERNEL_ELF"
echo " ISO:    $ASH_ISO"
echo