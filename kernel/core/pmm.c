#include "pmm.h"
#include "string.h"
#include "debug.h"
#include "terminal.h"

// Pointer to the bitmap in physical memory
static uint8_t *bitmap = (uint8_t *)PMM_BITMAP_BASE;
static uint32_t total_blocks = 0;
static uint32_t used_blocks = 0;
static uint32_t bitmap_size = 0;

// Next-Fit cursors (frame indices)
static uint32_t last_free_index = 0;
static uint32_t last_free_index_low = 0;

// Bitmap scanning constants
#define PMM_WORD_BITS 32u
#define PMM_WORD_FULL 0xFFFFFFFFu

static void pmm_panic_u32(const char *msg, uint32_t value)
{
    term_print("\n[PMM PANIC] ", TERM_COLOR_LIGHT_RED);
    term_print(msg, TERM_COLOR_LIGHT_RED);
    term_print(" (", TERM_COLOR_LIGHT_RED);
    term_print_hex(value, TERM_COLOR_YELLOW);
    term_print(")\n", TERM_COLOR_LIGHT_RED);
    panic("PMM fatal error");
}

// Helper: Set a bit (Mark used)
static void pmm_set(uint32_t frame)
{
    if (frame >= total_blocks)
        pmm_panic_u32("pmm_set: frame out of range", frame);

    uint32_t idx = frame / 8;
    uint32_t off = frame % 8;

    if (!(bitmap[idx] & (1u << off)))
    {
        bitmap[idx] |= (1u << off);
        used_blocks++;
    }
}

// Helper: Clear a bit (Mark free)
static void pmm_unset(uint32_t frame)
{
    if (frame >= total_blocks)
        pmm_panic_u32("pmm_unset: frame out of range", frame);

    uint32_t idx = frame / 8;
    uint32_t off = frame % 8;
    if (bitmap[idx] & (1u << off))
    {
        bitmap[idx] &= ~(1u << off);
        if (used_blocks == 0u)
            pmm_panic_u32("pmm_unset: used_blocks underflow", frame);
        used_blocks--;
    }
}

// Helper: Test a bit (Check if used)
static uint8_t pmm_test(uint32_t frame)
{
    uint32_t idx = frame / 8u;
    uint32_t off = frame % 8u;
    return (uint8_t)(bitmap[idx] & (uint8_t)(1u << off));
}

// Read a 32-bit word from the bitmap safely. Bytes beyond bitmap_size are treated as 0xFF (used).
static uint32_t pmm_bitmap_word(uint32_t word_index)
{
    uint32_t byte_index = word_index * 4u;
    uint32_t word = PMM_WORD_FULL;

    uint8_t *word_bytes = (uint8_t *)&word;
    for (uint32_t i = 0; i < 4u; i++)
    {
        if ((byte_index + i) < bitmap_size)
        {
            word_bytes[i] = bitmap[byte_index + i];
        }
    }

    return word;
}

static int32_t pmm_find_first_set_bit(uint32_t value)
{
    for (uint32_t bit = 0; bit < PMM_WORD_BITS; bit++)
    {
        if (value & (1u << bit))
            return (int32_t)bit;
    }
    return -1;
}

// Find a free frame in [start_frame, end_frame)
static int32_t pmm_find_free_in_range(uint32_t start_frame, uint32_t end_frame)
{
    if (start_frame >= end_frame)
        return -1;

    uint32_t start_word = start_frame / PMM_WORD_BITS;
    uint32_t end_word = (end_frame - 1u) / PMM_WORD_BITS;

    for (uint32_t word_index = start_word; word_index <= end_word; word_index++)
    {
        uint32_t word = pmm_bitmap_word(word_index);
        uint32_t mask = PMM_WORD_FULL;

        if (word_index == start_word)
        {
            uint32_t start_bit = start_frame % PMM_WORD_BITS;
            if (start_bit != 0u)
            {
                mask &= (PMM_WORD_FULL << start_bit);
            }
        }

        if (word_index == end_word)
        {
            uint32_t end_bit = (end_frame - 1u) % PMM_WORD_BITS;
            if (end_bit != (PMM_WORD_BITS - 1u))
            {
                mask &= ((1u << (end_bit + 1u)) - 1u);
            }
        }

        uint32_t candidates = (~word) & mask;
        if (candidates != 0u)
        {
            int32_t bit = pmm_find_first_set_bit(candidates);
            if (bit >= 0)
                return (int32_t)(word_index * PMM_WORD_BITS + (uint32_t)bit);
        }
    }

    return -1;
}

static int32_t pmm_first_free_from(uint32_t *cursor, uint32_t end_frame)
{
    if (*cursor >= end_frame)
        *cursor = 0;

    int32_t frame = pmm_find_free_in_range(*cursor, end_frame);
    if (frame >= 0)
        return frame;

    return pmm_find_free_in_range(0, *cursor);
}

// Next-Fit (word-scanned) finder
static int32_t pmm_first_free(void)
{
    if (used_blocks >= total_blocks)
        return -1;

    return pmm_first_free_from(&last_free_index, total_blocks);
}

static int32_t pmm_first_free_low(uint32_t max_frame)
{
    if (used_blocks >= total_blocks)
        return -1;

    return pmm_first_free_from(&last_free_index_low, max_frame);
}

void pmm_init(BootInfo *boot_info)
{
    // 1. Calculate Total Memory Size from E820
    E820Entry *mmap = (E820Entry *)boot_info->mmap_addr;
    uint64_t highest_addr = 0;

    for (uint32_t i = 0; i < boot_info->mmap_count; i++)
    {
        if (mmap[i].type == 1)
        { // Usable
            uint64_t top = mmap[i].base + mmap[i].length;
            if (top > highest_addr)
                highest_addr = top;
        }
    }

    // 2. Initialize Bitmap
    total_blocks = (uint32_t)((highest_addr + (PMM_PAGE_SIZE - 1)) / PMM_PAGE_SIZE);
    bitmap_size = (total_blocks + 7) / 8;

    last_free_index = 0;
    last_free_index_low = 0;

    // Default: Mark everything as USED (1)
    memset(bitmap, 0xFF, bitmap_size);
    used_blocks = total_blocks;

    // 3. Mark Usable Regions as FREE (0) based on E820
    for (uint32_t i = 0; i < boot_info->mmap_count; i++)
    {
        if (mmap[i].type == 1)
        { // Usable
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

void *pmm_alloc_page(void)
{
    int32_t frame = pmm_first_free();
    if (frame == -1)
        return 0;

    pmm_set((uint32_t)frame);

    // Next-Fit: next scan begins after this frame
    last_free_index = (uint32_t)frame + 1u;
    if (last_free_index >= total_blocks)
    {
        last_free_index = 0;
    }

    uint32_t addr = (uint32_t)frame * PMM_PAGE_SIZE;
    return (void *)addr;
}

void *pmm_alloc_page_low(uint32_t max_addr)
{
    uint32_t max_frame = max_addr / PMM_PAGE_SIZE;

    if (max_frame == 0u)
        return 0;

    if (max_frame > total_blocks)
        max_frame = total_blocks;

    int32_t frame = pmm_first_free_low(max_frame);
    if (frame == -1)
        return 0;

    pmm_set((uint32_t)frame);

    // Next-Fit: next scan begins after this frame
    last_free_index_low = (uint32_t)frame + 1u;
    if (last_free_index_low >= max_frame)
    {
        last_free_index_low = 0;
    }

    uint32_t addr = (uint32_t)frame * PMM_PAGE_SIZE;
    return (void *)addr;
}

void pmm_free_page(void *p)
{
    if (!p)
        return;

    uint32_t addr = (uint32_t)p;

    if ((addr % PMM_PAGE_SIZE) != 0u)
        pmm_panic_u32("pmm_free_page: unaligned address", addr);

    uint32_t frame = addr / PMM_PAGE_SIZE;

    if (frame >= total_blocks)
        pmm_panic_u32("pmm_free_page: address out of range", addr);

    /* Double-free / invalid free detection. */
    if (!pmm_test(frame))
        pmm_panic_u32("pmm_free_page: double free or corrupt frame", frame);

    pmm_unset(frame);

    // If we freed a block lower than the cursor, move the cursor back so we can fill gaps.
    if (frame < last_free_index)
    {
        last_free_index = frame;
    }
    if (frame < last_free_index_low)
    {
        last_free_index_low = frame;
    }
}

void pmm_mark_region_used(uint64_t base, uint64_t length)
{
    if (length == 0)
        return;

    // Page-round the range: [base, base+length) -> [start_frame, end_frame)
    uint64_t start_frame = base / PMM_PAGE_SIZE;
    uint64_t end_frame = (base + length + (PMM_PAGE_SIZE - 1)) / PMM_PAGE_SIZE;

    if (end_frame > (uint64_t)total_blocks)
        end_frame = (uint64_t)total_blocks;

    for (uint64_t frame = start_frame; frame < end_frame; frame++)
    {
        pmm_set((uint32_t)frame);
    }
}

void pmm_mark_region_free(uint64_t base, uint64_t length)
{
    if (length == 0)
        return;

    // Page-round the range: [base, base+length) -> [start_frame, end_frame)
    uint64_t start_frame = base / PMM_PAGE_SIZE;
    uint64_t end_frame = (base + length + (PMM_PAGE_SIZE - 1)) / PMM_PAGE_SIZE;

    if (end_frame > (uint64_t)total_blocks)
        end_frame = (uint64_t)total_blocks;

    for (uint64_t frame = start_frame; frame < end_frame; frame++)
    {
        pmm_unset((uint32_t)frame);
    }
}

uint32_t pmm_get_free_memory(void)
{
    return (total_blocks - used_blocks) * PMM_PAGE_SIZE;
}

uint32_t pmm_get_total_memory(void)
{
    return total_blocks * PMM_PAGE_SIZE;
}