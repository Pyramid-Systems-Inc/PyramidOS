#include "ata.h"
#include "io.h"
#include "timer.h" // For delays

#define ATA_PIO_TIMEOUT 100000u

// Wait for the drive to be ready (Busy bit clear)
static int ata_wait_busy(void)
{
    uint32_t timeout = ATA_PIO_TIMEOUT;
    while (timeout--)
    {
        uint8_t status = inb(ATA_STATUS);
        if (!(status & ATA_SR_BSY))
            return ATA_OK; // Not busy
    }
    return ATA_ERR_TIMEOUT_BSY;
}

// Wait for the drive to be ready to transfer data (DRQ bit set) or error out.
static int ata_wait_drq(void)
{
    uint32_t timeout = ATA_PIO_TIMEOUT;
    while (timeout--)
    {
        uint8_t status = inb(ATA_STATUS);

        if (status & ATA_SR_ERR)
            return ATA_ERR_DEVICE;

        if (status & ATA_SR_DRQ)
            return ATA_OK; // Ready to transfer
    }
    return ATA_ERR_TIMEOUT_DRQ;
}

void ata_init(void) {
    // In a real driver, we would scan PCI buses or check IDENTIFY.
    // For now, we assume standard ISA ports exist.
}

int ata_read_sector(int drive, uint32_t lba, uint8_t *buffer)
{
    if (!buffer)
        return ATA_ERR_INVALID_PARAM;

    // LBA28 supports 28-bit addressing.
    if (lba > ATA_LBA28_MAX)
        return ATA_ERR_LBA_RANGE;

    // 1) Select Drive + LBA mode and set top 4 bits of LBA (bits 24-27).
    uint8_t drive_cmd = (drive == 0) ? ATA_DRIVE_LBA_MASTER : ATA_DRIVE_LBA_SLAVE;
    outb(ATA_DRIVE_HEAD, (uint8_t)(drive_cmd | ((lba >> 24) & 0x0Fu)));

    // 2) Null Byte (Features register)
    outb(ATA_ERROR, 0x00);

    // 3) Sector Count (1 sector)
    outb(ATA_SECTOR_CNT, 1);

    // 4) LBA Address (low/mid/high)
    outb(ATA_LBA_LO, (uint8_t)(lba & 0xFFu));
    outb(ATA_LBA_MID, (uint8_t)((lba >> 8) & 0xFFu));
    outb(ATA_LBA_HI, (uint8_t)((lba >> 16) & 0xFFu));

    // 5) Send Command
    outb(ATA_COMMAND, ATA_CMD_READ_PIO);

    // 6) Wait for drive to process
    int rc = ata_wait_busy();
    if (rc != ATA_OK)
        return rc;

    rc = ata_wait_drq();
    if (rc != ATA_OK)
        return rc;

    // 7) Read Data (256 words = 512 bytes)
    insw(ATA_DATA, buffer, 256);

    // 8) Flush status (also acknowledges IRQ in some cases)
    inb(ATA_STATUS);

    return ATA_OK;
}