/* =============================================================================
   PyramidOS Kernel - Main Entry Point
   ============================================================================= */

#include <stdint.h>
#include "bootinfo.h"
#include "pmm.h"
#include "idt.h"
#include "vmm.h"
#include "pic.h"
#include "io.h"
#include "shell.h"
#include "selftest.h"
#include "heap.h"
#include "timer.h"
#include "keyboard.h"
#include "ata.h"      // Added for Storage
#include "string.h"   // Added for strcpy
#include "terminal.h"
#include "cpu.h"

/* Console colors (VGA text-mode attributes) */
static const uint8_t COLOR_GREEN = TERM_COLOR_LIGHT_GREEN;
static const uint8_t COLOR_WHITE = TERM_COLOR_WHITE;

// --- Test Suites ---
// NOTE: Tests were migrated to [`kernel/core/selftest.c`](kernel/core/selftest.c:1).
//       Keep the legacy in-file test code disabled.
//       Use [`selftest_run_all()`](kernel/core/selftest.c:1) at boot or the "diagnose" KShell command.
#if 0

#define PMM_TEST_PAGES 512u
static void *pmm_test_pages[PMM_TEST_PAGES];

void test_pmm_nextfit(void) {
    term_print("\n[TEST] PMM Next-Fit...\n", COLOR_WHITE);

    uint32_t free_before = pmm_get_free_memory();
    term_print("Free before: ", COLOR_WHITE);
    term_print_hex(free_before, COLOR_WHITE);
    term_print("\n", COLOR_WHITE);

    for (uint32_t i = 0; i < PMM_TEST_PAGES; i++) {
        pmm_test_pages[i] = 0;
    }

    // 1) Allocate a batch of pages
    for (uint32_t i = 0; i < PMM_TEST_PAGES; i++) {
        pmm_test_pages[i] = pmm_alloc_page();
        if (!pmm_test_pages[i]) {
            term_print("PMM test: FAIL (OOM during allocation)\n", COLOR_RED);
            goto cleanup;
        }
    }

    // 2) Free every other page (fragmentation pattern)
    for (uint32_t i = 0; i < PMM_TEST_PAGES; i += 2u) {
        pmm_free_page(pmm_test_pages[i]);
        pmm_test_pages[i] = 0;
    }

    // 3) Allocate again into the gaps
    for (uint32_t i = 0; i < PMM_TEST_PAGES; i += 2u) {
        pmm_test_pages[i] = pmm_alloc_page();
        if (!pmm_test_pages[i]) {
            term_print("PMM test: FAIL (OOM during gap refill)\n", COLOR_RED);
            goto cleanup;
        }
    }

cleanup:
    for (uint32_t i = 0; i < PMM_TEST_PAGES; i++) {
        if (pmm_test_pages[i]) {
            pmm_free_page(pmm_test_pages[i]);
            pmm_test_pages[i] = 0;
        }
    }

    uint32_t free_after = pmm_get_free_memory();
    term_print("Free after:  ", COLOR_WHITE);
    term_print_hex(free_after, COLOR_WHITE);
    term_print("\n", COLOR_WHITE);

    if (free_after == free_before) {
        term_print("PMM test: OK\n", COLOR_GREEN);
    } else {
        term_print("PMM test: WARN (free mismatch)\n", COLOR_RED);
    }
}

void test_heap(void) {
    term_print("\n[TEST] Heap Allocation...\n", 0x0F);

    // 1. Basic Allocation
    void* ptr1 = kmalloc(10);
    term_print("Allocated 10 bytes at: 0x", 0x07);
    term_print_hex((uint32_t)ptr1, 0x07);
    
    if (ptr1 == 0) {
        term_print(" -> FAIL (Null Pointer)\n", 0x0C);
        return;
    }
    term_print(" -> OK\n", 0x0A);

    // 2. Write Verification
    strcpy((char*)ptr1, "Pyramid");
    term_print("Written Data: ", 0x07);
    term_print((char*)ptr1, 0x07);
    term_print("\n", 0x07);

    // 3. Second Allocation
    void* ptr2 = kmalloc(4096);
    term_print("Allocated 4096 bytes at: 0x", 0x07);
    term_print_hex((uint32_t)ptr2, 0x07);
    term_print("\n", 0x07);

    // 4. Free Logic
    term_print("Freeing ptr1...\n", 0x0F);
    kfree(ptr1);

    // 5. Reuse Check
    void* ptr3 = kmalloc(5);
    term_print("Allocated 5 bytes at: 0x", 0x07);
    term_print_hex((uint32_t)ptr3, 0x07);

    if (ptr3 == ptr1) {
        term_print(" -> OK (Reused freed block)\n", 0x0A);
    } else {
        term_print(" -> NOTE (New block created)\n", 0x0E);
    }
}

void test_ata(void) {
    term_print("\n[TEST] ATA Disk Driver...\n", 0x0F);
    
    // 1. Initialize
    ata_init();

    // 2. Buffer allocation
    uint8_t* buffer = (uint8_t*)kmalloc(512);
    if (!buffer) {
        term_print("FAIL: Heap OOM during disk test.\n", 0x0C);
        return;
    }

    // 3. Read Sector 0 (LBA 0)
    term_print("Reading Sector 0... ", 0x07);
    int ret = ata_read_sector(0, 0u, buffer);

    if (ret == 0) {
        term_print("OK\n", 0x0A);
        
        // 4. Verify Signature (The last 2 bytes of MBR are always 55 AA)
        term_print("Signature Check: ", 0x07);
        if (buffer[510] == 0x55 && buffer[511] == 0xAA) {
            term_print("MATCH (0x55AA)\n", 0x0A);
        } else {
            term_print("FAIL (Data Mismatch)\n", 0x0C);
            term_print_hex(buffer[510], 0x0C);
            term_print(" ", 0x0C);
            term_print_hex(buffer[511], 0x0C);
            term_print("\n", 0x0C);
        }
    } else {
        term_print("FAIL (Error Code: ", 0x0C);
        term_print_hex(ret, 0x0C); // Print the error number
        term_print(")\n", 0x0C);
    }

    kfree(buffer);
}

#endif // legacy test code

// --- Main Entry ---

void k_main(void) {
    term_init();
    term_print("PyramidOS Kernel v0.8 - Storage Test\n", COLOR_GREEN);
    term_print("------------------------------------\n", COLOR_WHITE);

    // Core Init
    pmm_init((BootInfo*)BOOT_INFO_ADDRESS);
    idt_init();
    pic_remap();
    vmm_init();

    // Hardware Init (before enabling interrupts)
    term_print("Initializing PIT Timer...\n", COLOR_WHITE);
    timer_init();

    term_print("Initializing Keyboard...\n", COLOR_WHITE);
    keyboard_init();
    
    // Subsystem Init
    term_print("Initializing Heap...\n", COLOR_WHITE);
    heap_init();

    // Run Diagnostics (PMM + Heap + ATA)
    selftest_run_all();

    // IRQ Policy: start with everything masked, then enable only what we use.
    pic_disable();
    pic_clear_mask(0); // IRQ0: PIT Timer
    pic_clear_mask(1); // IRQ1: PS/2 Keyboard
    cpu_sti();

    shell_init();
    shell_run();

    while (1)
    {
        cpu_idle();
    }
}