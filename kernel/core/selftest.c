#include "selftest.h"

#include "pmm.h"
#include "heap.h"
#include "ata.h"
#include "string.h"

// Console output (implemented in kernel/core/main.c)
extern void term_print(const char *str, uint8_t color);
extern void term_print_hex(uint32_t n, uint8_t color);

#define COLOR_GREEN 0x0A
#define COLOR_WHITE 0x0F
#define COLOR_RED   0x0C
#define COLOR_CYAN  0x0B
#define COLOR_YELLOW 0x0E

#define SELFTEST_PMM_MAX_PAGES 256u
static void *pmm_test_pages[SELFTEST_PMM_MAX_PAGES];

static void selftest_print_status(const char *name, int rc)
{
    term_print("[", COLOR_WHITE);
    if (rc == 0)
    {
        term_print(" OK ", COLOR_GREEN);
    }
    else
    {
        term_print("FAIL", COLOR_RED);
    }
    term_print("] ", COLOR_WHITE);
    term_print(name, COLOR_WHITE);
    term_print("\n", COLOR_WHITE);
}

int selftest_pmm(void)
{
    term_print("\n[SELFTEST] PMM (Next-Fit)\n", COLOR_CYAN);

    uint32_t free_before = pmm_get_free_memory();
    uint32_t free_pages = free_before / PMM_PAGE_SIZE;

    // Avoid exhausting RAM: test at most 1/8th of current free pages, bounded.
    uint32_t pages_to_test = free_pages / 8u;
    if (pages_to_test > SELFTEST_PMM_MAX_PAGES)
        pages_to_test = SELFTEST_PMM_MAX_PAGES;
    if (pages_to_test < 8u)
        pages_to_test = (free_pages >= 8u) ? 8u : free_pages;

    term_print("Free before: ", COLOR_WHITE);
    term_print_hex(free_before, COLOR_YELLOW);
    term_print(" bytes\n", COLOR_WHITE);

    if (pages_to_test == 0u)
        return 1;

    for (uint32_t i = 0; i < pages_to_test; i++)
        pmm_test_pages[i] = 0;

    // 1) Allocate a batch of pages.
    for (uint32_t i = 0; i < pages_to_test; i++)
    {
        pmm_test_pages[i] = pmm_alloc_page();
        if (!pmm_test_pages[i])
            goto fail;
    }

    // 2) Free every other page (fragmentation pattern).
    for (uint32_t i = 0; i < pages_to_test; i += 2u)
    {
        pmm_free_page(pmm_test_pages[i]);
        pmm_test_pages[i] = 0;
    }

    // 3) Allocate again into the gaps.
    for (uint32_t i = 0; i < pages_to_test; i += 2u)
    {
        pmm_test_pages[i] = pmm_alloc_page();
        if (!pmm_test_pages[i])
            goto fail;
    }

    // Cleanup.
    for (uint32_t i = 0; i < pages_to_test; i++)
    {
        if (pmm_test_pages[i])
        {
            pmm_free_page(pmm_test_pages[i]);
            pmm_test_pages[i] = 0;
        }
    }

    {
        uint32_t free_after = pmm_get_free_memory();
        term_print("Free after:  ", COLOR_WHITE);
        term_print_hex(free_after, COLOR_YELLOW);
        term_print(" bytes\n", COLOR_WHITE);

        // Should match if PMM bookkeeping is correct.
        return (free_after == free_before) ? 0 : 2;
    }

fail:
    for (uint32_t i = 0; i < pages_to_test; i++)
    {
        if (pmm_test_pages[i])
        {
            pmm_free_page(pmm_test_pages[i]);
            pmm_test_pages[i] = 0;
        }
    }
    return 3;
}

int selftest_heap(void)
{
    term_print("\n[SELFTEST] Heap\n", COLOR_CYAN);

    // Requires heap_init() already executed.
    void *ptr1 = kmalloc(10);
    if (!ptr1)
        return 1;

    strcpy((char *)ptr1, "Pyramid");

    void *ptr2 = kmalloc(4096);
    if (!ptr2)
    {
        kfree(ptr1);
        return 2;
    }

    kfree(ptr1);

    void *ptr3 = kmalloc(5);
    if (!ptr3)
    {
        kfree(ptr2);
        return 3;
    }

    // Cleanup: keep heap state stable for later tests / shell usage.
    kfree(ptr2);
    kfree(ptr3);

    return 0;
}

int selftest_ata(void)
{
    term_print("\n[SELFTEST] ATA (Read Sector 0)\n", COLOR_CYAN);

    // ata_init() is a no-op today, but keep it as part of the contract.
    ata_init();

    uint8_t *buffer = (uint8_t *)kmalloc(512);
    if (!buffer)
        return 1;

    int ret = ata_read_sector(0, 0u, buffer);
    if (ret != 0)
    {
        kfree(buffer);
        return 2;
    }

    // Validate MBR signature.
    int ok = (buffer[510] == 0x55 && buffer[511] == 0xAA);

    kfree(buffer);
    return ok ? 0 : 3;
}

void selftest_run_all(void)
{
    term_print("\n=== PyramidOS Diagnostics ===\n", COLOR_YELLOW);

    int rc_pmm = selftest_pmm();
    selftest_print_status("Physical Memory Manager", rc_pmm);

    int rc_heap = selftest_heap();
    selftest_print_status("Kernel Heap", rc_heap);

    int rc_ata = selftest_ata();
    selftest_print_status("ATA Disk Controller", rc_ata);

    term_print("----------------------------\n", COLOR_WHITE);

    int failures = 0;
    failures += (rc_pmm != 0);
    failures += (rc_heap != 0);
    failures += (rc_ata != 0);

    term_print("Failures: ", COLOR_WHITE);
    term_print_hex((uint32_t)failures, COLOR_YELLOW);
    term_print("\n", COLOR_WHITE);
}