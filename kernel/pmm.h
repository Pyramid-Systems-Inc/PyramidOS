#ifndef PMM_H
#define PMM_H

#include <stdint.h>
#include "bootinfo.h"

// Page Size is 4KB
#define PMM_PAGE_SIZE 4096

// We will place the Bitmap at 128KB (0x20000)
// This is safe: Kernel is at 64KB-80KB.
#define PMM_BITMAP_BASE 0x00020000

void pmm_init(BootInfo *boot_info);
void *pmm_alloc_page(void);
void pmm_free_page(void *p);
void pmm_mark_region_used(uint64_t base, uint64_t length);
void pmm_mark_region_free(uint64_t base, uint64_t length);
uint32_t pmm_get_free_memory(void);
uint32_t pmm_get_total_memory(void);

#endif