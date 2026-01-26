#include "ata_block.h"

#include "ata.h"
#include "block.h"

/* --------------------------------------------------------------------------
 * ATA -> BlockDevice bridge
 * -------------------------------------------------------------------------- */

static int ata_block_read(BlockDevice *dev, uint32_t lba, uint8_t *buffer)
{
    if (!dev || !buffer)
        return BLOCK_ERROR;

    /* ctx stores drive number (ATA_DRIVE_MASTER / ATA_DRIVE_SLAVE). */
    uint32_t drive = (uint32_t)(uintptr_t)dev->ctx;

    int rc = ata_read_sector((int)drive, lba, buffer);
    return (rc == ATA_OK) ? BLOCK_SUCCESS : BLOCK_ERROR;
}

static int ata_block_write(BlockDevice *dev, uint32_t lba, uint8_t *buffer)
{
    (void)dev;
    (void)lba;
    (void)buffer;

    /* Read-only for now. */
    return BLOCK_ERROR;
}

static BlockDevice g_disk0 = {
    .name = "disk0",
    .sector_size = ATA_SECTOR_SIZE,
    .ctx = (void *)(uintptr_t)ATA_DRIVE_MASTER,
    .read = ata_block_read,
    .write = ata_block_write,
};

static BlockDevice g_disk1 = {
    .name = "disk1",
    .sector_size = ATA_SECTOR_SIZE,
    .ctx = (void *)(uintptr_t)ATA_DRIVE_SLAVE,
    .read = ata_block_read,
    .write = ata_block_write,
};

int ata_block_register_devices(void)
{
    /*
     * Probe hardware first. This is required because `ata_read_sector()` now
     * enforces presence checks based on IDENTIFY (see `ata_is_present()`).
     */
    ata_init();

    bool master = ata_is_present(ATA_DRIVE_MASTER);
    bool slave = ata_is_present(ATA_DRIVE_SLAVE);

    if (!master && !slave)
        return BLOCK_ERROR;

    /*
     * Naming policy:
     * - Prefer master as disk0
     * - If master missing but slave exists, expose slave as disk0 (so the system
     *   still has a canonical "disk0" for early FS bring-up).
     * - If both exist, expose slave as disk1.
     */
    if (master)
    {
        g_disk0.ctx = (void *)(uintptr_t)ATA_DRIVE_MASTER;
        int rc = block_register(&g_disk0);
        if (rc != BLOCK_SUCCESS)
            return rc;

        if (slave)
        {
            rc = block_register(&g_disk1);
            if (rc != BLOCK_SUCCESS)
                return rc;
        }

        return BLOCK_SUCCESS;
    }

    /* master absent, slave present */
    g_disk0.ctx = (void *)(uintptr_t)ATA_DRIVE_SLAVE;
    return block_register(&g_disk0);
}