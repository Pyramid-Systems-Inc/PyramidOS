#include "fs/nullfs.h"

static int nullfs_open(void *fs_ctx, const char *path, uint32_t flags, VfsFile *out_file)
{
    (void)fs_ctx;
    (void)path;
    (void)flags;

    if (!out_file)
        return VFS_ERR_INVALID_PARAM;

    return VFS_ERR_NOT_FOUND;
}

const VfsFsOps NULLFS_OPS = {
    .open = nullfs_open,
};