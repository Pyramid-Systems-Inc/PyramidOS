// boot/src/legacy/stage2.c

// --- Externs for Assembly Functions ---
extern void bios_print_char_asm(char c);
extern int bios_read_sectors_lba(unsigned char drive_num, void *dap);
extern void enter_protected_mode_and_jump(void);

// --- Typedefs and Structs ---
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
#define KERNEL_SECTOR_COUNT 16
#define KERNEL_LOAD_SEGMENT 0x1000
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

void print_hex_byte(unsigned char value)
{
    const char hex_chars[] = "0123456789ABCDEF";
    bios_print_char_asm(hex_chars[value >> 4]);
    bios_print_char_asm(hex_chars[value & 0x0F]);
}

void print_hex_word(unsigned short value)
{
    print_hex_byte(value >> 8);
    print_hex_byte(value & 0xFF);
}

// --- Main C Entry Point ---

void stage2_main(unsigned char boot_drive)
{
    print_string("Pyramid Bootloader: Stage 2\r\n");
    print_string("Boot drive: 0x");
    print_hex_byte(boot_drive);
    print_string("\r\n");

    // 1. Create the Disk Address Packet (DAP)
    DiskAddressPacket dap;
    dap.packet_size = sizeof(DiskAddressPacket);
    dap.reserved = 0;
    dap.num_blocks = KERNEL_SECTOR_COUNT;
    dap.buffer_offset = KERNEL_LOAD_OFFSET;
    dap.buffer_segment = KERNEL_LOAD_SEGMENT;
    dap.lba_start = KERNEL_LBA_START;

    // Debug: Show DAP details
    print_string("Loading kernel from LBA ");
    print_hex_byte(KERNEL_LBA_START);
    print_string(" to segment:offset ");
    print_hex_word(KERNEL_LOAD_SEGMENT);
    bios_print_char_asm(':');
    print_hex_word(KERNEL_LOAD_OFFSET);
    print_string("\r\n");

    // 2. Call the BIOS to load the kernel
    print_string("Calling BIOS INT 13h...\r\n");
    int result = bios_read_sectors_lba(boot_drive, &dap);

    // 3. Check for errors
    if (result != 0)
    {
        print_string("ERROR: Kernel load FAILED! Error code: 0x");
        print_hex_byte(result);
        print_string("\r\n");
        // Halt the system
        while (1)
        {
            __asm__ volatile("hlt");
        }
    }

    print_string("Kernel loaded successfully.\r\n");

    // Verify kernel signature (check first few bytes)
    unsigned char *kernel_addr = (unsigned char *)(KERNEL_LOAD_SEGMENT * 16);
    print_string("First bytes of kernel: ");
    for (int i = 0; i < 4; i++)
    {
        print_hex_byte(kernel_addr[i]);
        bios_print_char_asm(' ');
    }
    print_string("\r\n");

    print_string("Entering protected mode...\r\n");

    // Small delay so we can see the message
    for (volatile int i = 0; i < 1000000; i++)
        ;

    // 4. Switch to protected mode and jump to kernel
    enter_protected_mode_and_jump();

    // This should never be reached
    print_string("ERROR: Failed to enter protected mode!\r\n");
    while (1)
    {
        __asm__ volatile("hlt");
    }
}