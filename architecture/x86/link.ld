ENTRY(boot)

SECTIONS {
    . = 0x00100000;        /* Load code at exactly 1MB */

    .text : 
    {
        *(.text)           /* All text sections from all files */
    }

    /* read-only data sections */
    .rodata :
    {
        *(.rodata*)
    }

    /* data sections */
    .data :
    {
        *(.data)
    }

    /* read-only data sections */
    .bss :
    {
        // *(COMMON)
        *(.bss)
    }

    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
    }
}
