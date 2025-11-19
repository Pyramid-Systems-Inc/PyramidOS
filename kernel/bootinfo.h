#ifndef BOOTINFO_H
#define BOOTINFO_H

#include <stdint.h>

// The fixed physical address where Stage 2 wrote the structure
#define BOOT_INFO_ADDRESS 0x5000

// E820 Memory Map Entry (Standard x86 BIOS structure)
// Size: 24 bytes
typedef struct __attribute__((packed))
{
    uint64_t base;      // Base address of region
    uint64_t length;    // Length of region
    uint32_t type;      // 1 = Usable RAM, other = Reserved
    uint32_t acpi_attr; // ACPI 3.0 attributes (often ignored)
} E820Entry;

// Boot Information Structure
typedef struct __attribute__((packed))
{
    uint32_t magic;     // "BOOT" (0x54424F4F)
    uint16_t version;   // 1
    uint8_t boot_drive; // e.g., 0x80 (HDD) or 0x00 (Floppy)
    uint8_t reserved;
    uint32_t kernel_load_addr; // Segment:Offset (low 16 seg, high 16 off) -> Adjusted to Linear
    uint32_t kernel_size;
    uint32_t mmap_count; // Number of E820 entries
    uint32_t mmap_addr;  // Physical pointer to the map
} BootInfo;

#endif