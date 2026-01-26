#ifndef PYFS_H
#define PYFS_H

#include <stdint.h>

#include "block.h"
#include "fs/vfs.h"

/*
 * PyFS (Pyramid File System) - Phase 1 (Read-Only Bring-up)
 *
 * Current goal:
 * - Probe a partition block device for a PyFS superblock (LBA0).
 * - If valid, allow mounting it into the VFS.
 * - Provide minimal file access needed for verification (starting with a
 *   synthetic "superblock" file to read raw superblock bytes).
 */

#define PYFS_MAGIC 0x53465950u /* "PYFS" in little-endian */
#define PYFS_VERSION_1 1u

typedef struct PyfsCtx PyfsCtx;

/* Create/destroy a PyFS context over a block device (read-only). */
int pyfs_create(BlockDevice *dev, PyfsCtx **out_ctx);
void pyfs_destroy(PyfsCtx *ctx);

/* VFS ops table for mounting PyFS. */
extern const VfsFsOps PYFS_OPS;

#endif /* PYFS_H */