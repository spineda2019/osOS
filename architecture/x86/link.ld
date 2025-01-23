ENTRY(boot)

SECTIONS {
    . = 0x00100000;        /* Load code at exactly 1MB */

    /* align everything at 0x1000 (4096 in decimal, i.e. 4KB) */
    .text ALIGN(0x1000) : 
    {
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
        // *(COMMON)
        *(.bss)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
