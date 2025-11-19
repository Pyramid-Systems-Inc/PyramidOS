#ifndef HEAP_H
#define HEAP_H

#include <stddef.h>
#include <stdint.h>

// Magic Canary to detect corruption
#define HEAP_MAGIC 0xDEADBEEF

// Where the heap starts in Virtual Memory (3.25 GB mark)
#define HEAP_START_ADDR 0xD0000000
// Initial Heap Size (1 MB)
#define HEAP_INITIAL_SIZE 0x100000

typedef struct HeapHeader
{
    size_t size;             // Size of data block (excluding header)
    uint8_t is_free;         // 1 = Free, 0 = Used
    uint32_t magic;          // Safety check
    struct HeapHeader *next; // Next block
    struct HeapHeader *prev; // Previous block
} HeapHeader;

void heap_init(void);
void *kmalloc(size_t size);
void kfree(void *ptr);

#endif