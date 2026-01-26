#include "ata.h"
#include "io.h"

/* --------------------------------------------------------------------------
 * ATA Hardening Notes
 * - Avoid relying on PIT ticks here: early boot runs ATA selftest before IRQs
 *   are unmasked, so timer-based timeouts can deadlock.
 * - Use bounded polling with I/O delays and strict status checks instead.
 * -------------------------------------------------------------------------- */

/* Poll iteration bound (tuned for QEMU; still bounded for real HW). */
#define ATA_PIO_TIMEOUT 200000u

typedef struct
{
    bool present;
    uint32_t lba28_sectors;
} AtaDriveState;

static AtaDriveState g_ata_drive[2];

/* 400ns delay after certain ATA register writes (spec requirement). */
static void ata_400ns_delay(void)
{
    /* Reading alternate status is ideal; status read is usually acceptable. */
    (void)inb(ATA_ALT_STATUS);
    (void)inb(ATA_ALT_STATUS);
    (void)inb(ATA_ALT_STATUS);
    (void)inb(ATA_ALT_STATUS);
}

static bool ata_valid_drive(int drive)
{
    return (drive == ATA_DRIVE_MASTER) || (drive == ATA_DRIVE_SLAVE);
}

static uint8_t ata_drive_select_value(int drive, bool lba)
{
    if (lba)
        return (drive == ATA_DRIVE_MASTER) ? ATA_DRIVE_LBA_MASTER : ATA_DRIVE_LBA_SLAVE;

    return (drive == ATA_DRIVE_MASTER) ? ATA_DRIVE_SELECT_MASTER : ATA_DRIVE_SELECT_SLAVE;
}

static void ata_select_drive(int drive, bool lba)
{
    outb(ATA_DRIVE_HEAD, ata_drive_select_value(drive, lba));
    ata_400ns_delay();
}

/* Wait for BSY to clear. Also treat DF/ERR as immediate failure. */
static int ata_wait_not_busy(void)
{
    for (uint32_t i = 0; i < ATA_PIO_TIMEOUT; i++)
    {
        uint8_t status = inb(ATA_STATUS);

        if (status & ATA_SR_ERR)
            return ATA_ERR_DEVICE;

        if (status & ATA_SR_DF)
            return ATA_ERR_DEVICE;

        if ((status & ATA_SR_BSY) == 0u)
            return ATA_OK;
    }

    return ATA_ERR_TIMEOUT_BSY;
}

/* Wait for DRQ to set (data ready). Also treat DF/ERR as immediate failure. */
static int ata_wait_drq(void)
{
    for (uint32_t i = 0; i < ATA_PIO_TIMEOUT; i++)
    {
        uint8_t status = inb(ATA_STATUS);

        if (status & ATA_SR_ERR)
            return ATA_ERR_DEVICE;

        if (status & ATA_SR_DF)
            return ATA_ERR_DEVICE;

        if (status & ATA_SR_DRQ)
            return ATA_OK;
    }

    return ATA_ERR_TIMEOUT_DRQ;
}

/* IDENTIFY (PIO): fills 256 words. Returns ATA_OK, ATA_ERR_NO_DEVICE, or error. */
static int ata_identify_pio(int drive, uint16_t out_ident[256])
{
    if (!ata_valid_drive(drive) || !out_ident)
        return ATA_ERR_INVALID_PARAM;

    /* Select drive, CHS for IDENTIFY (doesn't matter much, but keep spec-friendly). */
    ata_select_drive(drive, false);

    /* Clear regs per spec for IDENTIFY. */
    outb(ATA_SECTOR_CNT, 0u);
    outb(ATA_LBA_LO, 0u);
    outb(ATA_LBA_MID, 0u);
    outb(ATA_LBA_HI, 0u);

    outb(ATA_COMMAND, ATA_CMD_IDENTIFY);
    ata_400ns_delay();

    /* If status is 0, drive does not exist on this bus. */
    uint8_t status = inb(ATA_STATUS);
    if (status == 0u)
        return ATA_ERR_NO_DEVICE;

    int rc = ata_wait_not_busy();
    if (rc != ATA_OK)
        return rc;

    /* ATAPI signature check: if LBA_MID/LBA_HI non-zero, not ATA. */
    {
        uint8_t mid = inb(ATA_LBA_MID);
        uint8_t hi  = inb(ATA_LBA_HI);
        if ((mid != 0u) || (hi != 0u))
            return ATA_ERR_UNSUPPORTED;
    }

    rc = ata_wait_drq();
    if (rc != ATA_OK)
        return rc;

    insw(ATA_DATA, out_ident, 256u);
    (void)inb(ATA_STATUS);

    return ATA_OK;
}

void ata_init(void)
{
    for (int d = 0; d < 2; d++)
    {
        g_ata_drive[d].present = false;
        g_ata_drive[d].lba28_sectors = 0u;
    }

    /* Probe master + slave on the primary bus. */
    for (int d = 0; d < 2; d++)
    {
        uint16_t ident[256];
        int rc = ata_identify_pio(d, ident);
        if (rc == ATA_OK)
        {
            /* Words 60-61: total number of user-addressable LBA28 sectors. */
            uint32_t sectors = (uint32_t)ident[60] | ((uint32_t)ident[61] << 16);

            g_ata_drive[d].present = true;
            g_ata_drive[d].lba28_sectors = sectors;
        }
        else
        {
            /* Not fatal here; leave drive marked absent. */
            g_ata_drive[d].present = false;
            g_ata_drive[d].lba28_sectors = 0u;
        }
    }
}

bool ata_is_present(int drive)
{
    if (!ata_valid_drive(drive))
        return false;

    return g_ata_drive[drive].present;
}

uint32_t ata_get_lba28_sectors(int drive)
{
    if (!ata_valid_drive(drive))
        return 0u;

    return g_ata_drive[drive].lba28_sectors;
}

int ata_read_sector(int drive, uint32_t lba, uint8_t *buffer)
{
    if (!buffer)
        return ATA_ERR_INVALID_PARAM;

    if (!ata_valid_drive(drive))
        return ATA_ERR_INVALID_PARAM;

    if (!g_ata_drive[drive].present)
        return ATA_ERR_NO_DEVICE;

    /* LBA28 supports 28-bit addressing. */
    if (lba > ATA_LBA28_MAX)
        return ATA_ERR_LBA_RANGE;

    /* If IDENTIFY gave us a size, enforce it. */
    if (g_ata_drive[drive].lba28_sectors != 0u)
    {
        if (lba >= g_ata_drive[drive].lba28_sectors)
            return ATA_ERR_LBA_RANGE;
    }

    /* 1) Select Drive + LBA mode and set top 4 bits of LBA (bits 24-27). */
    outb(ATA_DRIVE_HEAD, (uint8_t)(ata_drive_select_value(drive, true) | ((lba >> 24) & 0x0Fu)));
    ata_400ns_delay();

    /* 2) Features */
    outb(ATA_FEATURES, 0x00u);

    /* 3) Sector Count (1 sector) */
    outb(ATA_SECTOR_CNT, 1u);

    /* 4) LBA Address (low/mid/high) */
    outb(ATA_LBA_LO,  (uint8_t)(lba & 0xFFu));
    outb(ATA_LBA_MID, (uint8_t)((lba >> 8) & 0xFFu));
    outb(ATA_LBA_HI,  (uint8_t)((lba >> 16) & 0xFFu));

    /* 5) Command */
    outb(ATA_COMMAND, ATA_CMD_READ_PIO);
    ata_400ns_delay();

    /* 6) Wait for drive */
    int rc = ata_wait_not_busy();
    if (rc != ATA_OK)
        return rc;

    rc = ata_wait_drq();
    if (rc != ATA_OK)
        return rc;

    /* 7) Read Data (256 words = 512 bytes) */
    insw(ATA_DATA, buffer, 256u);

    /* 8) Flush status */
    (void)inb(ATA_STATUS);

    return ATA_OK;
}