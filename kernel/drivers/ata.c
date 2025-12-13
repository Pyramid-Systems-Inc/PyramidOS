#include "ata.h"
#include "io.h"
#include "timer.h" // For delays

// Wait for the drive to be ready (Busy bit clear)
static int ata_wait_busy(void) {
    int timeout = 100000;
    while (timeout--) {
        uint8_t status = inb(ATA_STATUS);
        if (!(status & ATA_SR_BSY)) return 0; // Not busy
    }
    return 1; // Timeout
}

// Wait for the drive to be ready to transfer data (DRQ bit set)
static int ata_wait_drq(void) {
    int timeout = 100000;
    while (timeout--) {
        uint8_t status = inb(ATA_STATUS);
        if (status & ATA_SR_DRQ) return 0; // Ready
        if (status & ATA_SR_ERR) return 1; // Error
    }
    return 1; // Timeout
}

void ata_init(void) {
    // In a real driver, we would scan PCI buses or check IDENTIFY.
    // For now, we assume standard ISA ports exist.
}

int ata_read_sector(int drive, uint8_t* buffer) {
    // 1. Select Drive (Master/Slave)
    // 0xE0 = LBA Mode, Master (0)
    // 0xF0 = LBA Mode, Slave (1)
    // We mask the drive bit (4)
    uint8_t drive_cmd = (drive == 0) ? 0xE0 : 0xF0;
    
    // We need to write the top 4 bits of LBA to this port, but for LBA 0 it's 0.
    outb(ATA_DRIVE_HEAD, drive_cmd | ((0 >> 24) & 0x0F));
    
    // 2. Null Byte (High LBA ignored for now)
    outb(ATA_ERROR, 0x00);
    
    // 3. Sector Count (1 sector)
    outb(ATA_SECTOR_CNT, 1);
    
    // 4. LBA Address (For now hardcoded to Sector 0 for the test)
    // Ideally pass 'lba' argument here
    outb(ATA_LBA_LO, 0); // LBA Low
    outb(ATA_LBA_MID, 0);
    outb(ATA_LBA_HI, 0);
    
    // 5. Send Command
    outb(ATA_COMMAND, ATA_CMD_READ_PIO);
    
    // 6. Wait for drive to process
    if (ata_wait_busy() != 0) return 1; // Error/Timeout
    if (ata_wait_drq() != 0) return 2;  // Error/No Data
    
    // 7. Read Data (256 words = 512 bytes)
    insw(ATA_DATA, buffer, 256);
    
    // 8. Delay/Flush
    // Reading status register resets interrupts
    inb(ATA_STATUS);
    
    return 0; // Success
}