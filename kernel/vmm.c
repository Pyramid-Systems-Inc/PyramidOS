#include "vmm.h"
#include "pmm.h"
#include "string.h"

// External print for debugging
extern void term_print(const char *str, uint8_t color);

// The Kernel's Page Directory (Physical Address)
static uint32_t *page_directory = 0;

// Helper: Get or Create Page Table for a Virtual Address
static uint32_t *vmm_get_page_table(uint32_t vaddr, int create)
{
    uint32_t pd_index = vaddr >> 22;

    // Check if Page Table exists
    if (page_directory[pd_index] & PDE_PRESENT)
    {
        return (uint32_t *)(page_directory[pd_index] & PDE_FRAME);
    }

    if (create)
    {
        // Create new Page Table
        uint32_t *new_table = (uint32_t *)pmm_alloc_page();
        memset(new_table, 0, PAGE_SIZE);

        // Add to Directory
        page_directory[pd_index] = ((uint32_t)new_table) | PDE_PRESENT | PDE_READ_WRITE;
        return new_table;
    }

    return 0;
}

// Map a Virtual Address to a Physical Address
void vmm_map(uint32_t vaddr, uint32_t paddr)
{
    uint32_t *table = vmm_get_page_table(vaddr, 1);
    uint32_t pt_index = (vaddr >> 12) & 0x3FF;

    table[pt_index] = paddr | PTE_PRESENT | PTE_READ_WRITE;

    // Flush TLB (Translation Lookaside Buffer) for this address
    asm volatile("invlpg (%0)" ::"r"(vaddr) : "memory");
}

// Allocate a new page at virtual address
int vmm_alloc_page(uint32_t vaddr)
{
    void *phys = pmm_alloc_page();
    if (!phys)
        return 0; // OOM

    vmm_map(vaddr, (uint32_t)phys);
    return 1;
}

void vmm_init(void)
{
    // 1. Allocate a Page Directory (4KB)
    page_directory = (uint32_t *)pmm_alloc_page();
    if (!page_directory)
    {
        term_print("PANIC: VMM - Cannot alloc Page Directory!\n", 0x0C);
        while (1)
            ;
    }

    // Clear it (Mark all PDEs as Not Present)
    memset(page_directory, 0, PAGE_SIZE);

    // 2. Create the FIRST Page Table (covers 0MB - 4MB)
    // We need this because the Kernel is sitting at 0x10000,
    // and VGA buffer is at 0xB8000.
    uint32_t *first_page_table = (uint32_t *)pmm_alloc_page();
    if (!first_page_table)
    {
        term_print("PANIC: VMM - Cannot alloc Page Table!\n", 0x0C);
        while (1)
            ;
    }

    // 3. Identity Map the first 4MB
    // Virtual Addr 0x00000000 -> Physical Addr 0x00000000
    // Virtual Addr 0x00001000 -> Physical Addr 0x00001000
    // ...
    for (int i = 0; i < 1024; i++)
    {
        // Address = Index * 4096
        uint32_t phys_addr = i * 4096;

        // Entry = Address | Present | ReadWrite
        first_page_table[i] = phys_addr | PTE_PRESENT | PTE_READ_WRITE;
    }

    // 4. Put the Page Table into the Page Directory (Entry 0)
    // Entry 0 covers Virtual 0x00000000 to 0x003FFFFF
    page_directory[0] = ((uint32_t)first_page_table) | PDE_PRESENT | PDE_READ_WRITE;

    // 5. Load Page Directory Address into CR3 Register
    // CR3 holds the PHYSICAL address of the directory
    asm volatile("mov %0, %%cr3" ::"r"(page_directory));

    // 6. Enable Paging (Set Bit 31 of CR0)
    uint32_t cr0;
    asm volatile("mov %%cr0, %0" : "=r"(cr0));
    cr0 |= 0x80000000;
    asm volatile("mov %0, %%cr0" ::"r"(cr0));

    term_print("VMM Initialized. Paging ENABLED.\n", 0x0F);
}