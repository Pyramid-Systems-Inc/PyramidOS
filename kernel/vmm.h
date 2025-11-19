#ifndef VMM_H
#define VMM_H

#include <stdint.h>

// Paging Constants
#define PAGE_SIZE 4096
#define PAGES_PER_TABLE 1024
#define TABLES_PER_DIRECTORY 1024

// Page Table Entry Flags
#define PTE_PRESENT 0x01
#define PTE_READ_WRITE 0x02
#define PTE_USER 0x04
#define PTE_WRITE_THROUGH 0x08
#define PTE_CACHE_DISABLE 0x10
#define PTE_ACCESSED 0x20
#define PTE_DIRTY 0x40
#define PTE_FRAME 0xFFFFF000 // Mask to get the physical address

// Page Directory Entry Flags
#define PDE_PRESENT 0x01
#define PDE_READ_WRITE 0x02
#define PDE_USER 0x04
#define PDE_WRITE_THROUGH 0x08
#define PDE_CACHE_DISABLE 0x10
#define PDE_ACCESSED 0x20
#define PDE_FRAME 0xFFFFF000

// API
void vmm_init(void);
void vmm_map(uint32_t vaddr, uint32_t paddr);
int vmm_alloc_page(uint32_t vaddr); // Allocates new PMM frame and maps it

#endif