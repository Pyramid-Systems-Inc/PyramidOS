/* kernel/linker.ld */
ENTRY(_start) /* The entry point is the _start label in entry.asm */
OUTPUT_FORMAT(elf32-i386)

SECTIONS {
    /* Load the kernel at 1MB */
    . = 0x10000;

    .text : {
        *(.text)
    }

    .rodata : {
        *(.rodata)
    }

    .data : {
        *(.data)
    }

    .bss : {
        *(.bss)
    }

    /* Discard unnecessary sections */
    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
    }
}