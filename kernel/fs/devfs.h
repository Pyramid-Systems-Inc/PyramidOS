#ifndef DEVFS_H
#define DEVFS_H

#include "fs/vfs.h"

/*
 * DevFS: a virtual filesystem that exposes kernel devices as file nodes.
 * Example targets:
 *   /dev/null
 *   /dev/zero
 *   /dev/disk0   (backed by the BlockDevice registry)
 */
extern const VfsFsOps DEVFS_OPS;

#endif /* DEVFS_H */