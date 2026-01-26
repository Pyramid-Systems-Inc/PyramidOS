#ifndef BLOCK_H
#define BLOCK_H

#include <stdint.h>

/* --------------------------------------------------------------------------
 * Block device return codes
 * 0 = success; non-zero = error
 * -------------------------------------------------------------------------- */
#define BLOCK_SUCCESS 0
#define BLOCK_ERROR   1
#define BLOCK_BUSY    2

/* --------------------------------------------------------------------------
 * Block device registry limits
 * -------------------------------------------------------------------------- */
#define BLOCK_MAX_DEVICES 8u
#define BLOCK_NAME_MAX    32u

/* Generic Block Device Structure */
typedef struct BlockDevice
{
    char name[BLOCK_NAME_MAX];
    uint32_t sector_size;

    /* Optional per-device context pointer (driver-specific). */
    void *ctx;

    /* Function pointers (1 sector operations for now). */
    int (*read)(struct BlockDevice *dev, uint32_t lba, uint8_t *buffer);
    int (*write)(struct BlockDevice *dev, uint32_t lba, uint8_t *buffer);
} BlockDevice;

/* --------------------------------------------------------------------------
 * Block device registry API
 * -------------------------------------------------------------------------- */
void block_init(void);
int block_register(BlockDevice *dev);

uint32_t block_count(void);
BlockDevice *block_get(uint32_t index);
BlockDevice *block_get_by_name(const char *name);

#endif /* BLOCK_H */