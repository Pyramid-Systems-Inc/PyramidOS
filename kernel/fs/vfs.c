#include "fs/vfs.h"

#include "string.h"

#define VFS_BOOL_FALSE 0u
#define VFS_BOOL_TRUE  1u

typedef struct
{
    bool used;
    char mountpoint[VFS_MOUNTPOINT_MAX];
    char fs_name[VFS_FSNAME_MAX];
    const VfsFsOps *ops;
    void *fs_ctx;
} VfsMount;

typedef struct
{
    bool used;
    VfsFile file;
} VfsOpenEntry;

static VfsMount g_mounts[VFS_MAX_MOUNTS];
static VfsOpenEntry g_open[VFS_MAX_OPEN_FILES];

static uint32_t vfs_strnlen(const char *s, uint32_t max_len)
{
    if (!s)
        return 0u;

    for (uint32_t i = 0; i < max_len; i++)
    {
        if (s[i] == '\0')
            return i;
    }

    return max_len;
}

static int vfs_strlcpy(char *dst, uint32_t dst_size, const char *src)
{
    if (!dst || !src || dst_size == 0u)
        return VFS_ERR_INVALID_PARAM;

    uint32_t n = vfs_strnlen(src, dst_size);
    if (n >= dst_size)
        return VFS_ERR_NO_SPACE;

    for (uint32_t i = 0; i < dst_size; i++)
        dst[i] = 0;

    for (uint32_t i = 0; i < n; i++)
        dst[i] = src[i];

    dst[n] = '\0';
    return VFS_OK;
}

static bool vfs_mountpoint_matches(const char *mountpoint, const char *path)
{
    if (!mountpoint || !path)
        return false;

    /* Root mountpoint matches everything beginning with '/'. */
    if (mountpoint[0] == '/' && mountpoint[1] == '\0')
        return (path[0] == '/');

    uint32_t mlen = (uint32_t)strlen(mountpoint);
    if (mlen == 0u)
        return false;

    if (strncmp(path, mountpoint, mlen) != 0)
        return false;

    /* Match boundary: exact match or next char is '/'. */
    if (path[mlen] == '\0')
        return true;

    return (path[mlen] == '/');
}

static int vfs_find_mount(const char *path, uint32_t *out_mount_index, const char **out_rel_path)
{
    if (!path || !out_mount_index || !out_rel_path)
        return VFS_ERR_INVALID_PARAM;

    if (path[0] != '/')
        return VFS_ERR_INVALID_PARAM;

    int best = -1;
    uint32_t best_len = 0u;

    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        if (!g_mounts[i].used)
            continue;

        if (!vfs_mountpoint_matches(g_mounts[i].mountpoint, path))
            continue;

        uint32_t mlen = (uint32_t)strlen(g_mounts[i].mountpoint);
        if (mlen > best_len)
        {
            best = (int)i;
            best_len = mlen;
        }
    }

    if (best < 0)
        return VFS_ERR_NO_MOUNT;

    /* Compute relative path into the mounted filesystem (no leading '/'). */
    const char *rel = path;

    if (best_len == 1u)
    {
        /* mountpoint == "/" */
        rel = path + 1; /* skip leading '/' */
    }
    else
    {
        rel = path + best_len;
        if (*rel == '/')
            rel++;
    }

    *out_mount_index = (uint32_t)best;
    *out_rel_path = rel;
    return VFS_OK;
}

void vfs_init(void)
{
    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        g_mounts[i].used = false;
        g_mounts[i].ops = 0;
        g_mounts[i].fs_ctx = 0;
        g_mounts[i].mountpoint[0] = '\0';
        g_mounts[i].fs_name[0] = '\0';
    }

    for (uint32_t i = 0; i < VFS_MAX_OPEN_FILES; i++)
    {
        g_open[i].used = false;
        g_open[i].file.ops = 0;
        g_open[i].file.file_ctx = 0;
        g_open[i].file.size = 0u;
        g_open[i].file.pos = 0u;
    }
}

int vfs_mount(const char *mountpoint, const char *fs_name, const VfsFsOps *ops, void *fs_ctx)
{
    if (!mountpoint || !fs_name || !ops)
        return VFS_ERR_INVALID_PARAM;
    if (!ops->open)
        return VFS_ERR_INVALID_PARAM;

    if (mountpoint[0] != '/')
        return VFS_ERR_INVALID_PARAM;

    /* Reject duplicates to keep semantics simple. */
    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        if (g_mounts[i].used && strcmp(g_mounts[i].mountpoint, mountpoint) == 0)
            return VFS_ERR_INVALID_PARAM;
    }

    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        if (g_mounts[i].used)
            continue;

        int rc = vfs_strlcpy(g_mounts[i].mountpoint, VFS_MOUNTPOINT_MAX, mountpoint);
        if (rc != VFS_OK)
            return rc;

        rc = vfs_strlcpy(g_mounts[i].fs_name, VFS_FSNAME_MAX, fs_name);
        if (rc != VFS_OK)
            return rc;

        g_mounts[i].ops = ops;
        g_mounts[i].fs_ctx = fs_ctx;
        g_mounts[i].used = true;

        return VFS_OK;
    }

    return VFS_ERR_NO_SPACE;
}

uint32_t vfs_mount_count(void)
{
    uint32_t count = 0u;
    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        if (g_mounts[i].used)
            count++;
    }
    return count;
}

const char *vfs_mountpoint(uint32_t index)
{
    uint32_t n = 0u;
    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        if (!g_mounts[i].used)
            continue;

        if (n == index)
            return g_mounts[i].mountpoint;

        n++;
    }
    return 0;
}

const char *vfs_fs_name(uint32_t index)
{
    uint32_t n = 0u;
    for (uint32_t i = 0; i < VFS_MAX_MOUNTS; i++)
    {
        if (!g_mounts[i].used)
            continue;

        if (n == index)
            return g_mounts[i].fs_name;

        n++;
    }
    return 0;
}

int vfs_open(const char *path, uint32_t flags, uint32_t *out_fd)
{
    if (!path || !out_fd)
        return VFS_ERR_INVALID_PARAM;

    uint32_t mount_index = 0u;
    const char *rel = 0;

    int rc = vfs_find_mount(path, &mount_index, &rel);
    if (rc != VFS_OK)
        return rc;

    /* Find a free file descriptor slot. */
    uint32_t fd = VFS_MAX_OPEN_FILES;
    for (uint32_t i = 0; i < VFS_MAX_OPEN_FILES; i++)
    {
        if (!g_open[i].used)
        {
            fd = i;
            break;
        }
    }

    if (fd == VFS_MAX_OPEN_FILES)
        return VFS_ERR_NO_SPACE;

    VfsFile tmp;
    tmp.ops = 0;
    tmp.file_ctx = 0;
    tmp.size = 0u;
    tmp.pos = 0u;

    rc = g_mounts[mount_index].ops->open(g_mounts[mount_index].fs_ctx, rel, flags, &tmp);
    if (rc != VFS_OK)
        return rc;

    if (!tmp.ops)
        return VFS_ERR_IO;

    g_open[fd].file = tmp;
    g_open[fd].file.pos = 0u;
    g_open[fd].used = true;

    *out_fd = fd;
    return VFS_OK;
}

int vfs_read(uint32_t fd, void *buffer, uint32_t size, uint32_t *out_read)
{
    if (fd >= VFS_MAX_OPEN_FILES)
        return VFS_ERR_BAD_FD;
    if (!g_open[fd].used)
        return VFS_ERR_BAD_FD;

    if (size > 0u && !buffer)
        return VFS_ERR_INVALID_PARAM;

    uint32_t tmp_read = 0u;
    uint32_t *read_ptr = out_read ? out_read : &tmp_read;
    *read_ptr = 0u;

    VfsFile *f = &g_open[fd].file;
    if (!f->ops || !f->ops->read)
        return VFS_ERR_NOT_SUPPORTED;

    int rc = f->ops->read(f, f->pos, buffer, size, read_ptr);
    if (rc != VFS_OK)
        return rc;

    if (*read_ptr > size)
        return VFS_ERR_IO;

    f->pos += *read_ptr;
    return VFS_OK;
}

int vfs_close(uint32_t fd)
{
    if (fd >= VFS_MAX_OPEN_FILES)
        return VFS_ERR_BAD_FD;
    if (!g_open[fd].used)
        return VFS_ERR_BAD_FD;

    VfsFile *f = &g_open[fd].file;

    int rc = VFS_OK;
    if (f->ops && f->ops->close)
        rc = f->ops->close(f);

    g_open[fd].used = false;
    g_open[fd].file.ops = 0;
    g_open[fd].file.file_ctx = 0;
    g_open[fd].file.size = 0u;
    g_open[fd].file.pos = 0u;

    return rc;
}