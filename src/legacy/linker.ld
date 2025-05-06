/*
 * Minimal Linker Script for Pyramid Bootloader - Legacy Stage 2
 * To be used with i686-elf-ld.
 * Assumes Stage 1 loads Stage 2 to linear address 0x8000.
 */

ENTRY(stage2_entry_point) /* Entry point defined in entry.asm */
OUTPUT_FORMAT(elf32-i386) /* Match the object file format */

SECTIONS {
    /* Start placing sections at 0x8000 */
    . = 0x8000;

    /* Code section */
    .text : {
        *(.text)
    }

    /* Read-only data section */
    .rodata : {
        *(.rodata)
    }

    /* Read-write data section */
    .data : {
        *(.data)
    }

    /* Uninitialized data section */
    .bss : {
        *(.bss)
    }

    /* Discard standard library sections we don't need */
    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
    }
}
