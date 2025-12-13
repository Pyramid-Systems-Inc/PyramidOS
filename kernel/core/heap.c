#include "heap.h"
#include "vmm.h"
#include "debug.h" // For panic

static HeapHeader *start_header = 0;

void heap_init(void)
{
    // 1. Allocate pages for the heap
    // We map HEAP_INITIAL_SIZE bytes starting at HEAP_START_ADDR
    uint32_t current_addr = HEAP_START_ADDR;
    uint32_t end_addr = HEAP_START_ADDR + HEAP_INITIAL_SIZE;

    while (current_addr < end_addr)
    {
        vmm_alloc_page(current_addr);
        current_addr += 4096;
    }

    // 2. Initialize the first massive free block
    start_header = (HeapHeader *)HEAP_START_ADDR;
    start_header->size = HEAP_INITIAL_SIZE - sizeof(HeapHeader);
    start_header->is_free = 1;
    start_header->magic = HEAP_MAGIC;
    start_header->next = NULL;
    start_header->prev = NULL;
}

void *kmalloc(size_t size)
{
    // 0. Alignment (4 bytes)
    if (size % 4 != 0)
    {
        size += 4 - (size % 4);
    }

    // 1. Iterate list
    HeapHeader *current = start_header;
    while (current)
    {
        // Sanity Check
        if (current->magic != HEAP_MAGIC)
        {
            panic("Heap Corruption Detected during Malloc!");
        }

        if (current->is_free && current->size >= size)
        {
            // Found a fit!

            // 2. Split block if large enough
            // We need enough space for the new header + at least 4 bytes of data
            if (current->size > size + sizeof(HeapHeader) + 4)
            {
                HeapHeader *new_block = (HeapHeader *)((uint32_t)current + sizeof(HeapHeader) + size);

                new_block->size = current->size - size - sizeof(HeapHeader);
                new_block->is_free = 1;
                new_block->magic = HEAP_MAGIC;
                new_block->next = current->next;
                new_block->prev = current;

                if (current->next)
                {
                    current->next->prev = new_block;
                }

                current->next = new_block;
                current->size = size;
            }

            // 3. Mark as used
            current->is_free = 0;

            // Return pointer to DATA (after header)
            return (void *)((uint32_t)current + sizeof(HeapHeader));
        }
        current = current->next;
    }

    return NULL; // OOM (Phase 1: No expansion yet)
}

void kfree(void *ptr)
{
    if (!ptr)
        return;

    // 1. Get Header
    HeapHeader *header = (HeapHeader *)((uint32_t)ptr - sizeof(HeapHeader));

    // 2. Sanity Check
    if (header->magic != HEAP_MAGIC)
    {
        panic("Heap Corruption Detected during Free!");
    }

    // 3. Mark Free
    header->is_free = 1;

    // 4. Coalesce Right (Merge with Next)
    if (header->next && header->next->is_free)
    {
        header->size += sizeof(HeapHeader) + header->next->size;
        header->next = header->next->next;
        if (header->next)
        {
            header->next->prev = header;
        }
    }

    // 5. Coalesce Left (Merge with Prev)
    if (header->prev && header->prev->is_free)
    {
        header->prev->size += sizeof(HeapHeader) + header->size;
        header->prev->next = header->next;
        if (header->next)
        {
            header->next->prev = header->prev;
        }
    }
}