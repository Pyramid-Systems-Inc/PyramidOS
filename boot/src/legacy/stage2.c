// boot/src/legacy/stage2.c

// --- Externs for Assembly Functions ---
extern void bios_print_char_asm(char c);
extern int bios_read_sectors_lba(unsigned char drive_num, void *dap);

// --- Typedefs and Structs ---

// Use #pragma pack for broader compatibility with IDEs and compilers.
// This ensures the struct has no padding.
#pragma pack(push, 1)

// Disk Address Packet for BIOS INT 13h, AH=42h
typedef struct
{
    unsigned char packet_size;     // Size of this packet (16)
    unsigned char reserved;        // Always zero
    unsigned short num_blocks;     // Number of sectors to transfer
    unsigned short buffer_offset;  // Offset of transfer buffer
    unsigned short buffer_segment; // Segment of transfer buffer
    unsigned long long lba_start;  // Starting Logical Block Address (LBA)
} DiskAddressPacket;

#pragma pack(pop)

// --- Constants ---
#define KERNEL_LBA_START 60
#define KERNEL_SECTOR_COUNT 16     // Load 16 sectors (8KB), ensure this is enough for your kernel
#define KERNEL_LOAD_SEGMENT 0x1000 // Corresponds to linear address 0x10000
#define KERNEL_LOAD_OFFSET 0x0000

// --- Helper Functions ---

void print_string(const char *str)
{
    while (*str)
    {
        bios_print_char_asm(*str);
        str++;
    }
}

// --- Main C Entry Point ---

void stage2_main(unsigned char boot_drive)
{
    print_string("Pyramid Bootloader: Stage 2\r\n");

    // 1. Create the Disk Address Packet (DAP)
    DiskAddressPacket dap;
    dap.packet_size = sizeof(DiskAddressPacket);
    dap.reserved = 0;
    dap.num_blocks = KERNEL_SECTOR_COUNT;
    dap.buffer_offset = KERNEL_LOAD_OFFSET;
    dap.buffer_segment = KERNEL_LOAD_SEGMENT;
    dap.lba_start = KERNEL_LBA_START;

    // 2. Call the BIOS to load the kernel
    print_string("Loading kernel...\r\n");
    int result = bios_read_sectors_lba(boot_drive, &dap);

    // 3. Check for errors
    if (result != 0)
    {
        print_string("Kernel load FAILED!\r\n");
        // Halt the system
        while (1)
        {
        }
    }

    print_string("Kernel loaded successfully. Jumping to kernel...\r\n");

    // 4. Jump to the kernel's entry point
    // We loaded it at 0x1000:0000 (linear address 0x10000)
    void (*kernel_entry)(void) = (void (*)(void))((unsigned long)KERNEL_LOAD_SEGMENT << 4);
    kernel_entry();
}