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

    /* align everything at 0x1000 (4096 in decimal, i.e. 4KB) */
    .text ALIGN(0x1000) : 
    {
        KEEP(*(.text.multiboot*))
        *(.text)           /* All text sections from all files */
    }

    /* read-only data sections */
    .rodata ALIGN(0x1000) :
    {
        *(.rodata*)
    }

    /* data sections */
    .data ALIGN(0x1000) :
    {
        *(.data)
    }

    /* read-only data sections */
    .bss ALIGN(0x1000) :
    {
        /* *(COMMON) */
        *(.bss)
    }

    . = ALIGN(4);
    . += 128 * 1024;        /* 128KB */
    __stack_top = .;        /* Stack will be 128KB */

    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
