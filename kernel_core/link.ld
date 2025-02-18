ENTRY(kernel_core)

SECTIONS {
    . = 0x00100000;        /* Load code at exactly 1MB */

    .text ALIGN (0x1000) : /* Align at 4KB */
    {
        *(.text)           /* All text sections from all files */
    }

    /* read-only data sections */
    .rodata ALIGN (0x1000) :
    {
        *(.rodata*)
    }

    /* data sections */
    .data ALIGN (0x1000) :
    {
        *(.data)
    }

    /* read-only data sections */
    .bss ALIGN (0x1000) :
    {
        *(COMMON)
        *(.bss)
    }
}
