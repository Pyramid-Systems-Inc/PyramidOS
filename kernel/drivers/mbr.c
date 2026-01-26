#include "mbr.h"

#include "heap.h"
#include "string.h"

/* --------------------------------------------------------------------------
 * Legacy MBR layout (512 bytes)
 * -------------------------------------------------------------------------- */
#define MBR_SECTOR_SIZE               512u
#define MBR_SIGNATURE_OFFSET          510u
#define MBR_SIGNATURE_LO              0x55u
#define MBR_SIGNATURE_HI              0xAAu

#define MBR_PARTITION_TABLE_OFFSET    446u
#define MBR_PARTITION_ENTRY_SIZE      16u
#define MBR_PARTITION_COUNT           4u

/* Partition entry fields */
#define MBR_PART_OFF_TYPE             4u
#define MBR_PART_OFF_LBA_START        8u
#define MBR_PART_OFF_LBA_COUNT        12u

#define MBR_PART_TYPE_EMPTY           0x00u
#define MBR_PART_TYPE_EXTENDED_CHS    0x05u
#define MBR_PART_TYPE_EXTENDED_LBA    0x0Fu

/* Return codes (local to this module) */
#define MBR_OK                        0
#define MBR_ERR_INVALID_PARAM         1
#define MBR_ERR_IO                    2
#define MBR_ERR_BAD_SIGNATURE         3
#define MBR_ERR_NO_SPACE              4

typedef struct
{
    BlockDevice *parent;
    uint32_t base_lba;
    uint32_t sector_count;
} MbrPartitionCtx;

static uint32_t mbr_read_u32_le(const uint8_t *p)
{
    return (uint32_t)p[0]
        | ((uint32_t)p[1] << 8)
        | ((uint32_t)p[2] << 16)
        | ((uint32_t)p[3] << 24);
}

static int mbr_build_partition_name(char out_name[BLOCK_NAME_MAX], const char *disk_name, uint32_t part_index_1based)
{
    if (!out_name || !disk_name)
        return MBR_ERR_INVALID_PARAM;

    if (part_index_1based == 0u || part_index_1based > 9u)
        return MBR_ERR_INVALID_PARAM;

    /* Clear name buffer. */
    for (uint32_t i = 0; i < BLOCK_NAME_MAX; i++)
        out_name[i] = '\0';

    uint32_t base_len = (uint32_t)strlen(disk_name);

    /* Need: disk_name + 'p' + digit + '\0' */
    if (base_len + 3u > BLOCK_NAME_MAX)
        return MBR_ERR_NO_SPACE;

    for (uint32_t i = 0; i < base_len; i++)
        out_name[i] = disk_name[i];

    out_name[base_len] = 'p';
    out_name[base_len + 1u] = (char)('0' + (char)part_index_1based);
    out_name[base_len + 2u] = '\0';

    return MBR_OK;
}

static int mbr_partition_read(BlockDevice *dev, uint32_t lba, uint8_t *buffer)
{
    if (!dev || !buffer)
        return BLOCK_ERROR;

    MbrPartitionCtx *ctx = (MbrPartitionCtx *)dev->ctx;
    if (!ctx || !ctx->parent || !ctx->parent->read)
        return BLOCK_ERROR;

    /* Enforce partition boundary when we know the size. */
    if (ctx->sector_count != 0u)
    {
        if (lba >= ctx->sector_count)
            return BLOCK_ERROR;
    }

    /* Overflow guard: base_lba + lba */
    if (ctx->base_lba > (0xFFFFFFFFu - lba))
        return BLOCK_ERROR;

    uint32_t parent_lba = ctx->base_lba + lba;
    return ctx->parent->read(ctx->parent, parent_lba, buffer);
}

static int mbr_partition_write(BlockDevice *dev, uint32_t lba, uint8_t *buffer)
{
    (void)dev;
    (void)lba;
    (void)buffer;

    /* Read-only for now. */
    return BLOCK_ERROR;
}

int mbr_scan_and_register(BlockDevice *disk, const char *disk_name)
{
    if (!disk || !disk->read)
        return MBR_ERR_INVALID_PARAM;

    if (!disk_name)
        disk_name = disk->name;

    if (!disk_name || disk_name[0] == '\0')
        return MBR_ERR_INVALID_PARAM;

    /* MBR is always 512 bytes; we only support 512-byte logical sectors today. */
    if (disk->sector_size != MBR_SECTOR_SIZE)
        return MBR_ERR_NOT_SUPPORTED;

    uint8_t mbr[MBR_SECTOR_SIZE];
    if (disk->read(disk, 0u, mbr) != BLOCK_SUCCESS)
        return MBR_ERR_IO;

    if (mbr[MBR_SIGNATURE_OFFSET] != MBR_SIGNATURE_LO ||
        mbr[MBR_SIGNATURE_OFFSET + 1u] != MBR_SIGNATURE_HI)
    {
        return MBR_ERR_BAD_SIGNATURE;
    }

    for (uint32_t i = 0; i < MBR_PARTITION_COUNT; i++)
    {
        uint32_t entry_off = MBR_PARTITION_TABLE_OFFSET + (i * MBR_PARTITION_ENTRY_SIZE);

        uint8_t part_type = mbr[entry_off + MBR_PART_OFF_TYPE];
        uint32_t lba_start = mbr_read_u32_le(&mbr[entry_off + MBR_PART_OFF_LBA_START]);
        uint32_t lba_count = mbr_read_u32_le(&mbr[entry_off + MBR_PART_OFF_LBA_COUNT]);

        if (part_type == MBR_PART_TYPE_EMPTY || lba_count == 0u)
            continue;

        /* Skip extended partitions for now (we'll add EBR chain support later). */
        if (part_type == MBR_PART_TYPE_EXTENDED_CHS || part_type == MBR_PART_TYPE_EXTENDED_LBA)
            continue;

        BlockDevice *pdev = (BlockDevice *)kmalloc(sizeof(BlockDevice));
        if (!pdev)
            return MBR_ERR_NO_SPACE;

        MbrPartitionCtx *ctx = (MbrPartitionCtx *)kmalloc(sizeof(MbrPartitionCtx));
        if (!ctx)
        {
            kfree(pdev);
            return MBR_ERR_NO_SPACE;
        }

        ctx->parent = disk;
        ctx->base_lba = lba_start;
        ctx->sector_count = lba_count;

        /* Fill the BlockDevice struct. */
        for (uint32_t z = 0; z < BLOCK_NAME_MAX; z++)
            pdev->name[z] = '\0';

        if (mbr_build_partition_name(pdev->name, disk_name, i + 1u) != MBR_OK)
        {
            kfree(ctx);
            kfree(pdev);
            continue;
        }

        pdev->sector_size = disk->sector_size;
        pdev->ctx = ctx;
        pdev->read = mbr_partition_read;
        pdev->write = mbr_partition_write;

        if (block_register(pdev) != BLOCK_SUCCESS)
        {
            kfree(ctx);
            kfree(pdev);
            return MBR_ERR_NO_SPACE;
        }
    }

    return MBR_OK;
}