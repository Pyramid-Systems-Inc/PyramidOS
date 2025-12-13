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
#include "heap.h"
#include "ata.h"      // Added for Storage
#include "string.h"   // Added for strcpy

// --- Function Prototypes (Forward Declarations) ---
void term_clear(void);
void term_print(const char* str, uint8_t color);
void term_print_hex(uint32_t n, uint8_t color);
void update_cursor(int x, int y);

// --- VGA State ---
volatile uint16_t* vga_buffer = (uint16_t*)0xB8000;
const int VGA_COLS = 80;
const int VGA_ROWS = 25;
const uint8_t COLOR_GREEN = 0x0A;
const uint8_t COLOR_WHITE = 0x0F;
const uint8_t COLOR_RED   = 0x0C;
int cursor_x = 0;
int cursor_y = 0;

// --- Test Suites ---

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
    int ret = ata_read_sector(0, buffer); 

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

// --- Helper Implementations ---

void update_cursor(int x, int y) {
    uint16_t pos = y * VGA_COLS + x;

    // Send Low Byte
    outb(0x3D4, 0x0F);
    outb(0x3D5, (uint8_t)(pos & 0xFF));

    // Send High Byte
    outb(0x3D4, 0x0E);
    outb(0x3D5, (uint8_t)((pos >> 8) & 0xFF));
}

void term_clear(void) {
    for (int i = 0; i < VGA_COLS * VGA_ROWS; i++) {
        vga_buffer[i] = ((uint16_t)0x0F << 8) | ' ';
    }
    cursor_x = 0;
    cursor_y = 0;
    update_cursor(0, 0);
}

void term_print(const char* str, uint8_t color) {
    for (int i = 0; str[i] != '\0'; i++) {
        if (str[i] == '\n') {
            cursor_x = 0;
            cursor_y++;
        } else if (str[i] == '\b') {
            if (cursor_x > 0) {
                cursor_x--; 
                int index = (cursor_y * VGA_COLS) + cursor_x;
                vga_buffer[index] = ((uint16_t)0x0F << 8) | ' '; 
            }
        } else {
            int index = (cursor_y * VGA_COLS) + cursor_x;
            vga_buffer[index] = ((uint16_t)color << 8) | str[i];
            cursor_x++;
        }

        if (cursor_x >= VGA_COLS) {
            cursor_x = 0;
            cursor_y++;
        }
        if (cursor_y >= VGA_ROWS) {
            cursor_y = 0;
            term_clear();
        }
    }
    update_cursor(cursor_x, cursor_y);
}

void term_print_hex(uint32_t n, uint8_t color) {
    term_print("0x", color);
    char hex_chars[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) {
        char c = hex_chars[(n >> i) & 0xF];
        char str[2] = {c, '\0'};
        term_print(str, color);
    }
}

// --- Main Entry ---

void k_main(void) {
    term_clear();
    term_print("PyramidOS Kernel v0.8 - Storage Test\n", COLOR_GREEN);
    term_print("------------------------------------\n", COLOR_WHITE);

    // Core Init
    pmm_init((BootInfo*)BOOT_INFO_ADDRESS);
    idt_init(); 
    pic_remap();
    vmm_init();
    
    // Subsystem Init
    term_print("Initializing Heap...\n", COLOR_WHITE);
    heap_init();

    // Run Tests
    test_heap();
    test_ata();  // <--- Run the Disk Test

    // Interaction
    outb(0x21, 0xFD); // Unmask Keyboard
    asm volatile("sti");

    shell_init();
    shell_run();

    while(1) {
        asm volatile("hlt");
    }
}