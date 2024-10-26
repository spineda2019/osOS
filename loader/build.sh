#!/usr/bin/env bash
cd "$(dirname "$0")"

echo "Compiling loader.s into object file..."

nasm -f elf32 loader.s

echo "Linking executable..."

ld -T link.ld -melf_i386 loader.o -o kernel.elf
