#include "ata_block.h"

#include "ata.h"
#include "block.h"
#include "string.h"

/* ATA PIO sector size */
#define ATA_SECTOR_SIZE 512u

static int ata_block_read(BlockDevice *dev, uint32_t lba, uint8_t *buffer)
{
    if (!dev || !buffer)
        return BLOCK_ERROR;

    /* ctx stores drive number (0 = master, 1 = slave) */
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

static BlockDevice g_ata0_dev = {
    .name = "disk0",
    .sector_size = ATA_SECTOR_SIZE,
    .ctx = (void *)(uintptr_t)0u,
    .read = ata_block_read,
    .write = ata_block_write,
};

int ata_block_register_devices(void)
{
    /* ata_init() is currently a no-op but keeps the contract future-proof. */
    ata_init();

    return block_register(&g_ata0_dev);
}