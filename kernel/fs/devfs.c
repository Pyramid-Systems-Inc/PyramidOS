#include "fs/devfs.h"

#include <stdint.h>

#include "block.h"
#include "heap.h"
#include "string.h"

/* --------------------------------------------------------------------------
 * DevFS internal file contexts
 * -------------------------------------------------------------------------- */

#define DEVFS_KIND_NULL 0u
#define DEVFS_KIND_ZERO 1u
#define DEVFS_KIND_BLOCK 2u

typedef struct
{
    uint32_t kind;
    BlockDevice *blk;
} DevFsFileCtx;

static int devfs_read_null(VfsFile *file, uint32_t offset, void *buffer, uint32_t size, uint32_t *out_read)
{
    (void)file;
    (void)offset;
    (void)buffer;
    (void)size;

    if (!out_read)
        return VFS_ERR_INVALID_PARAM;

    *out_read = 0u;
    return VFS_OK;
}

static int devfs_read_zero(VfsFile *file, uint32_t offset, void *buffer, uint32_t size, uint32_t *out_read)
{
    (void)file;
    (void)offset;

    if (!buffer && size > 0u)
        return VFS_ERR_INVALID_PARAM;

    if (!out_read)
        return VFS_ERR_INVALID_PARAM;

    /* Fill with zeros. */
    memset(buffer, 0, size);
    *out_read = size;
    return VFS_OK;
}

static int devfs_read_block(VfsFile *file, uint32_t offset, void *buffer, uint32_t size, uint32_t *out_read)
{
    if (!file || !buffer || !out_read)
        return VFS_ERR_INVALID_PARAM;

    DevFsFileCtx *ctx = (DevFsFileCtx *)file->file_ctx;
    if (!ctx || ctx->kind != DEVFS_KIND_BLOCK || !ctx->blk)
        return VFS_ERR_IO;

    if (!ctx->blk->read)
        return VFS_ERR_IO;

    /* Require sector-aligned I/O for phase 1. */
    if ((offset % ctx->blk->sector_size) != 0u)
        return VFS_ERR_NOT_SUPPORTED;

    if ((size % ctx->blk->sector_size) != 0u)
        return VFS_ERR_NOT_SUPPORTED;

    uint32_t sector_size = ctx->blk->sector_size;
    uint32_t sectors = size / sector_size;

    uint8_t *dst = (uint8_t *)buffer;
    uint32_t lba = offset / sector_size;

    for (uint32_t i = 0; i < sectors; i++)
    {
        int rc = ctx->blk->read(ctx->blk, lba + i, dst + (i * sector_size));
        if (rc != BLOCK_SUCCESS)
        {
            *out_read = i * sector_size;
            return VFS_ERR_IO;
        }
    }

    *out_read = size;
    return VFS_OK;
}

static int devfs_close(VfsFile *file)
{
    if (!file)
        return VFS_ERR_INVALID_PARAM;

    if (file->file_ctx)
    {
        kfree(file->file_ctx);
        file->file_ctx = 0;
    }

    file->ops = 0;
    file->size = 0u;
    file->pos = 0u;

    return VFS_OK;
}

static const VfsFileOps DEVFS_NULL_FILE_OPS = {
    .read = devfs_read_null,
    .close = devfs_close,
};

static const VfsFileOps DEVFS_ZERO_FILE_OPS = {
    .read = devfs_read_zero,
    .close = devfs_close,
};

static const VfsFileOps DEVFS_BLOCK_FILE_OPS = {
    .read = devfs_read_block,
    .close = devfs_close,
};

static int devfs_open(void *fs_ctx, const char *path, uint32_t flags, VfsFile *out_file)
{
    (void)fs_ctx;

    if (!path || !out_file)
        return VFS_ERR_INVALID_PARAM;

    /* Only read supported for now. */
    if ((flags & VFS_OPEN_WRITE) != 0u)
        return VFS_ERR_NOT_SUPPORTED;

    /* DevFS paths are relative inside the mount. No leading slash expected. */
    if (strcmp(path, "null") == 0)
    {
        DevFsFileCtx *ctx = (DevFsFileCtx *)kmalloc(sizeof(DevFsFileCtx));
        if (!ctx)
            return VFS_ERR_NO_SPACE;

        ctx->kind = DEVFS_KIND_NULL;
        ctx->blk = 0;

        out_file->ops = &DEVFS_NULL_FILE_OPS;
        out_file->file_ctx = ctx;
        out_file->size = 0u;
        out_file->pos = 0u;
        return VFS_OK;
    }

    if (strcmp(path, "zero") == 0)
    {
        DevFsFileCtx *ctx = (DevFsFileCtx *)kmalloc(sizeof(DevFsFileCtx));
        if (!ctx)
            return VFS_ERR_NO_SPACE;

        ctx->kind = DEVFS_KIND_ZERO;
        ctx->blk = 0;

        out_file->ops = &DEVFS_ZERO_FILE_OPS;
        out_file->file_ctx = ctx;
        out_file->size = 0u;
        out_file->pos = 0u;
        return VFS_OK;
    }

    /* diskN nodes (raw block device) */
    if (strncmp(path, "disk", 4u) == 0)
    {
        BlockDevice *dev = block_get_by_name(path);
        if (!dev)
            return VFS_ERR_NOT_FOUND;

        DevFsFileCtx *ctx = (DevFsFileCtx *)kmalloc(sizeof(DevFsFileCtx));
        if (!ctx)
            return VFS_ERR_NO_SPACE;

        ctx->kind = DEVFS_KIND_BLOCK;
        ctx->blk = dev;

        out_file->ops = &DEVFS_BLOCK_FILE_OPS;
        out_file->file_ctx = ctx;
        out_file->size = 0u;
        out_file->pos = 0u;
        return VFS_OK;
    }

    return VFS_ERR_NOT_FOUND;
}

const VfsFsOps DEVFS_OPS = {
    .open = devfs_open,
};