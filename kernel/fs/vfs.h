#ifndef VFS_H
#define VFS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

/* --------------------------------------------------------------------------
 * VFS Return Codes
 * -------------------------------------------------------------------------- */
#define VFS_OK                  0
#define VFS_ERR_INVALID_PARAM   1
#define VFS_ERR_NO_SPACE        2
#define VFS_ERR_NOT_FOUND       3
#define VFS_ERR_NOT_SUPPORTED   4
#define VFS_ERR_IO              5
#define VFS_ERR_NO_MOUNT        6
#define VFS_ERR_BAD_FD          7

/* --------------------------------------------------------------------------
 * VFS Limits (fixed-size to avoid early heap coupling)
 * -------------------------------------------------------------------------- */
#define VFS_MAX_MOUNTS          8u
#define VFS_MAX_OPEN_FILES      32u
#define VFS_MOUNTPOINT_MAX      32u
#define VFS_FSNAME_MAX          16u
#define VFS_PATH_MAX            128u

/* Open flags */
#define VFS_OPEN_READ           0x00000001u
#define VFS_OPEN_WRITE          0x00000002u

typedef struct VfsFile VfsFile;

typedef struct VfsFileOps
{
    int (*read)(VfsFile *file, uint32_t offset, void *buffer, uint32_t size, uint32_t *out_read);
    int (*close)(VfsFile *file);
} VfsFileOps;

struct VfsFile
{
    const VfsFileOps *ops;
    void *file_ctx;

    /* Optional metadata (filesystem may leave as 0 if unknown). */
    uint32_t size;

    /* Current read/write cursor (managed by VFS). */
    uint32_t pos;
};

typedef struct VfsFsOps
{
    int (*open)(void *fs_ctx, const char *path, uint32_t flags, VfsFile *out_file);
} VfsFsOps;

void vfs_init(void);

int vfs_mount(const char *mountpoint, const char *fs_name, const VfsFsOps *ops, void *fs_ctx);

uint32_t vfs_mount_count(void);
const char *vfs_mountpoint(uint32_t index);
const char *vfs_fs_name(uint32_t index);

int vfs_open(const char *path, uint32_t flags, uint32_t *out_fd);
int vfs_read(uint32_t fd, void *buffer, uint32_t size, uint32_t *out_read);
int vfs_close(uint32_t fd);

#endif /* VFS_H */