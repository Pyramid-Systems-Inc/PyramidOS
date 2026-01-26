#include "fs/pyfs.h"

#include <stdint.h>

#include "heap.h"
#include "string.h"

/* --------------------------------------------------------------------------
 * PyFS on-disk superblock (Phase 1)
 * -------------------------------------------------------------------------- */
#define PYFS_SUPERBLOCK_LBA 0u
#define PYFS_BLOCK_SIZE 512u

#define PYFS_ERR_INVALID_PARAM  1
#define PYFS_ERR_IO             2
#define PYFS_ERR_BAD_SUPERBLOCK 3
#define PYFS_ERR_NO_SPACE       4
#define PYFS_ERR_NOT_FOUND      5

typedef struct
{
    uint32_t magic;
    uint32_t version;
    uint32_t block_size;
    uint32_t reserved0;
} PyfsSuperblock;

struct PyfsCtx
{
    BlockDevice *dev;
    PyfsSuperblock sb;
};

/* Only file currently exposed by PyFS for verification. */
#define PYFS_FILE_SUPERBLOCK 1u

typedef struct
{
    PyfsCtx *fs;
    uint32_t file_id;
    uint8_t *cache; /* 512-byte superblock cache */
} PyfsFileCtx;

static int pyfs_read_superblock(PyfsCtx *fs, uint8_t out_sector[PYFS_BLOCK_SIZE])
{
    if (!fs || !fs->dev || !fs->dev->read || !out_sector)
        return PYFS_ERR_INVALID_PARAM;

    if (fs->dev->read(fs->dev, PYFS_SUPERBLOCK_LBA, out_sector) != BLOCK_SUCCESS)
        return PYFS_ERR_IO;

    return 0;
}

static int pyfs_probe(PyfsCtx *fs)
{
    uint8_t sector[PYFS_BLOCK_SIZE];
    int rc = pyfs_read_superblock(fs, sector);
    if (rc != 0)
        return rc;

    PyfsSuperblock *sb = (PyfsSuperblock *)sector;

    if (sb->magic != PYFS_MAGIC)
        return PYFS_ERR_BAD_SUPERBLOCK;

    if (sb->version != PYFS_VERSION_1)
        return PYFS_ERR_BAD_SUPERBLOCK;

    /* For now we accept only 512-byte blocks (same as sector size). */
    if (sb->block_size != PYFS_BLOCK_SIZE)
        return PYFS_ERR_BAD_SUPERBLOCK;

    fs->sb = *sb;
    return 0;
}

int pyfs_create(BlockDevice *dev, PyfsCtx **out_ctx)
{
    if (!dev || !out_ctx)
        return PYFS_ERR_INVALID_PARAM;

    PyfsCtx *ctx = (PyfsCtx *)kmalloc(sizeof(PyfsCtx));
    if (!ctx)
        return PYFS_ERR_NO_SPACE;

    ctx->dev = dev;
    ctx->sb.magic = 0u;
    ctx->sb.version = 0u;
    ctx->sb.block_size = 0u;
    ctx->sb.reserved0 = 0u;

    int rc = pyfs_probe(ctx);
    if (rc != 0)
    {
        kfree(ctx);
        return rc;
    }

    *out_ctx = ctx;
    return 0;
}

void pyfs_destroy(PyfsCtx *ctx)
{
    if (!ctx)
        return;

    kfree(ctx);
}

static int pyfs_file_read(VfsFile *file, uint32_t offset, void *buffer, uint32_t size, uint32_t *out_read)
{
    if (!file || !buffer || !out_read)
        return VFS_ERR_INVALID_PARAM;

    PyfsFileCtx *fctx = (PyfsFileCtx *)file->file_ctx;
    if (!fctx || !fctx->fs)
        return VFS_ERR_IO;

    if (fctx->file_id != PYFS_FILE_SUPERBLOCK)
        return VFS_ERR_NOT_FOUND;

    /* Lazily allocate and cache the 512-byte sector. */
    if (!fctx->cache)
    {
        fctx->cache = (uint8_t *)kmalloc(PYFS_BLOCK_SIZE);
        if (!fctx->cache)
            return VFS_ERR_NO_SPACE;

        if (fctx->fs->dev->read(fctx->fs->dev, PYFS_SUPERBLOCK_LBA, fctx->cache) != BLOCK_SUCCESS)
            return VFS_ERR_IO;
    }

    if (offset >= PYFS_BLOCK_SIZE)
    {
        *out_read = 0u;
        return VFS_OK;
    }

    uint32_t remaining = PYFS_BLOCK_SIZE - offset;
    uint32_t to_copy = (size < remaining) ? size : remaining;

    memcpy(buffer, fctx->cache + offset, to_copy);
    *out_read = to_copy;
    return VFS_OK;
}

static int pyfs_file_close(VfsFile *file)
{
    if (!file)
        return VFS_ERR_INVALID_PARAM;

    PyfsFileCtx *fctx = (PyfsFileCtx *)file->file_ctx;
    if (fctx)
    {
        if (fctx->cache)
            kfree(fctx->cache);

        kfree(fctx);
    }

    file->file_ctx = 0;
    file->ops = 0;
    file->size = 0u;
    file->pos = 0u;
    return VFS_OK;
}

static const VfsFileOps PYFS_FILE_OPS = {
    .read = pyfs_file_read,
    .close = pyfs_file_close,
};

static int pyfs_open(void *fs_ctx, const char *path, uint32_t flags, VfsFile *out_file)
{
    PyfsCtx *fs = (PyfsCtx *)fs_ctx;

    if (!fs || !path || !out_file)
        return VFS_ERR_INVALID_PARAM;

    if ((flags & VFS_OPEN_WRITE) != 0u)
        return VFS_ERR_NOT_SUPPORTED;

    /* PyFS paths are relative within mount. */
    if (strcmp(path, "superblock") != 0)
        return VFS_ERR_NOT_FOUND;

    PyfsFileCtx *fctx = (PyfsFileCtx *)kmalloc(sizeof(PyfsFileCtx));
    if (!fctx)
        return VFS_ERR_NO_SPACE;

    fctx->fs = fs;
    fctx->file_id = PYFS_FILE_SUPERBLOCK;
    fctx->cache = 0;

    out_file->ops = &PYFS_FILE_OPS;
    out_file->file_ctx = fctx;
    out_file->pos = 0u;
    out_file->size = PYFS_BLOCK_SIZE;

    return VFS_OK;
}

const VfsFsOps PYFS_OPS = {
    .open = pyfs_open,
};