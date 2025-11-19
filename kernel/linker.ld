/* =============================================================================
   PyramidOS Kernel Linker Script
   ============================================================================= */

/* The entry point symbol (used by debuggers, though bootloader jumps blindly) */
ENTRY(_start)

/* Output format: 32-bit ELF (Executable and Linkable Format) */
OUTPUT_FORMAT(elf32-i386)

SECTIONS {
    /* 
     * The kernel is loaded at physical 1MB (0x10000).
     * We set the location counter (.) to this address.
     */
    . = 0x00010000;

    /* 
     * .text: Executable Code
     * ALIGN(4K) ensures this section starts on a page boundary.
     */
    .text : ALIGN(4K) {
        /* 
         * CRITICAL: The object containing _start MUST be linked first 
         * by the Makefile for this to work correctly with a raw binary jump.
         */
        *(.text)
    }

    /* 
     * .rodata: Read-Only Data (Strings, Constants) 
     */
    .rodata : ALIGN(4K) {
        *(.rodata)
    }

    /* 
     * .data: Initialized Read-Write Data (Globals with values) 
     */
    .data : ALIGN(4K) {
        *(.data)
    }

    /* 
     * .bss: Uninitialized Read-Write Data (Globals = 0) and STACK
     * COMMON handles 'int x;' (tentative definitions)
     */
    .bss : ALIGN(4K) {
        *(COMMON)
        *(.bss)
    }

    /* 
     * Discard metadata sections we don't need in the raw kernel image 
     */
    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
        *(.note.gnu.build-id)
    }
}