/*
 * link.ld - load special symbols at specific addresses for x86 kernel's entry
 * Copyright (C) 2025 Sebastian Pineda (spineda.wpi.alum@gmail.com)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

ENTRY(boot)

SECTIONS {
    . = 0x00100000;        /* Load code at exactly 1MB */

    .multiboot ALIGN(0x1000):
    {
        KEEP(*(.multiboot))
    }

    .boot :
    {
        KEEP(*(.boot))
    }

    .trampoline :
    {
        KEEP(*(.trampoline))
    }

    .pagedata :
    {
        KEEP(*(.pagedata))
    }

    __stack_bottom = .;     /* Stack will be 1 MiB */
    . += 1024 * 1024;       /* 1 MiB */
    __stack_top = .;        /* Stack will be 1 MiB */

    /* Place post-trampoline in higher half virt memory */
    . += 0xC0000000;

    /* align everything at 0x1000 (4096 in decimal, i.e. 4KB) */
    .text : AT (ADDR (.text) - 0xC0000000)
    {
        *(.text)           /* All text sections from all files */
    }

    /* read-only data sections */
    .rodata ALIGN(0x1000) : AT (ADDR (.rodata) - 0xC0000000)
    {
        *(.rodata*)
    }

    /* data sections */
    .data ALIGN(0x1000) : AT (ADDR (.data) - 0xC0000000)
    {
        *(.data)
    }

    /* uninitialized data sections */
    .bss ALIGN(0x1000) : AT (ADDR (.bss) - 0xC0000000)
    {
        *(.bss)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
