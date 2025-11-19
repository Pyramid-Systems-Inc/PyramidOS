#include "pmm.h"
#include "string.h"

// Pointer to the bitmap in physical memory
static uint8_t* bitmap = (uint8_t*)PMM_BITMAP_BASE;
static uint32_t total_blocks = 0;
static uint32_t used_blocks = 0;
static uint32_t bitmap_size = 0;

// Helper: Set a bit (Mark used)
static void pmm_set(uint32_t frame) {
    uint32_t idx = frame / 8;
    uint32_t off = frame % 8;
    bitmap[idx] |= (1 << off);
    used_blocks++;
}

// Helper: Clear a bit (Mark free)
static void pmm_unset(uint32_t frame) {
    uint32_t idx = frame / 8;
    uint32_t off = frame % 8;
    if (bitmap[idx] & (1 << off)) {
        bitmap[idx] &= ~(1 << off);
        used_blocks--;
    }
}

// Helper: Test a bit (Check if used)
static uint8_t pmm_test(uint32_t frame) {
    uint32_t idx = frame / 8;
    uint32_t off = frame % 8;
    return (bitmap[idx] & (1 << off));
}

// Helper: Find first free frame
static int32_t pmm_first_free() {
    for (uint32_t i = 0; i < total_blocks; i++) {
        if (bitmap[i/8] != 0xFF) { // Optimization: skip full bytes
            for (int j = 0; j < 8; j++) {
                int bit = 1 << j;
                if (!(bitmap[i/8] & bit)) {
                    return (i/8)*8 + j;
                }
            }
        }
    }
    return -1; // OOM (Out of Memory)
}

void pmm_init(BootInfo* boot_info) {
    // 1. Calculate Total Memory Size from E820
    E820Entry* mmap = (E820Entry*)boot_info->mmap_addr;
    uint64_t highest_addr = 0;

    for (uint32_t i = 0; i < boot_info->mmap_count; i++) {
        if (mmap[i].type == 1) { // Usable
            uint64_t top = mmap[i].base + mmap[i].length;
            if (top > highest_addr) highest_addr = top;
        }
    }

    // 2. Initialize Bitmap
    total_blocks = highest_addr / PMM_PAGE_SIZE;
    bitmap_size = total_blocks / 8;
    
    // Default: Mark everything as USED (1)
    memset(bitmap, 0xFF, bitmap_size);
    used_blocks = total_blocks;

    // 3. Mark Usable Regions as FREE (0) based on E820
    for (uint32_t i = 0; i < boot_info->mmap_count; i++) {
        if (mmap[i].type == 1) { // Usable
            pmm_mark_region_free(mmap[i].base, mmap[i].length);
        }
    }

    // 4. Lock Critical Regions (Mark as USED)
    
    // Lock Page 0 (Null Pointer safety)
    pmm_mark_region_used(0x0, 0x1000); 

    // Lock Kernel (Starts at 0x10000, Size in BootInfo)
    // We align size up to next page
    pmm_mark_region_used(0x10000, boot_info->kernel_size);

    // Lock Bitmap itself (Starts at PMM_BITMAP_BASE, Size is bitmap_size)
    pmm_mark_region_used(PMM_BITMAP_BASE, bitmap_size);
    
    // Lock BootInfo and E820 Map (around 0x5000)
    pmm_mark_region_used(0x5000, 0x1000);
}

void* pmm_alloc_page(void) {
    int32_t frame = pmm_first_free();
    if (frame == -1) return 0; // Out of Memory

    pmm_set(frame);
    uint32_t addr = frame * PMM_PAGE_SIZE;
    return (void*)addr;
}

void pmm_free_page(void* p) {
    uint32_t addr = (uint32_t)p;
    uint32_t frame = addr / PMM_PAGE_SIZE;
    pmm_unset(frame);
}

void pmm_mark_region_used(uint64_t base, uint64_t length) {
    uint32_t align = base / PMM_PAGE_SIZE;
    uint32_t blocks = length / PMM_PAGE_SIZE;
    
    // Handle partial pages (if length isn't multiple of 4096, ensure we cover it)
    if (length % PMM_PAGE_SIZE) blocks++;

    for (uint32_t i = 0; i < blocks; i++) {
        pmm_set(align + i);
    }
}

void pmm_mark_region_free(uint64_t base, uint64_t length) {
    uint32_t align = base / PMM_PAGE_SIZE;
    uint32_t blocks = length / PMM_PAGE_SIZE;

    for (uint32_t i = 0; i < blocks; i++) {
        pmm_unset(align + i);
    }
}

uint32_t pmm_get_free_memory(void) {
    return (total_blocks - used_blocks) * PMM_PAGE_SIZE;
}

uint32_t pmm_get_total_memory(void) {
    return total_blocks * PMM_PAGE_SIZE;
}