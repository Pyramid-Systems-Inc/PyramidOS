#ifndef NULLFS_H
#define NULLFS_H

#include "fs/vfs.h"

/* A minimal filesystem implementation that always returns NOT_FOUND. */
extern const VfsFsOps NULLFS_OPS;

#endif /* NULLFS_H */