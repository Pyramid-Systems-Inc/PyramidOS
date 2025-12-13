#ifndef BLOCK_H
#define BLOCK_H

#include <stdint.h>

// Return Codes
#define BLOCK_SUCCESS 0
#define BLOCK_ERROR   1
#define BLOCK_BUSY    2

// Generic Block Device Structure
typedef struct BlockDevice {
    char name[32];
    uint32_t sector_size;
    
    // Function Pointers for Polymorphism
    int (*read)(struct BlockDevice* dev, uint32_t lba, uint8_t* buffer);
    int (*write)(struct BlockDevice* dev, uint32_t lba, uint8_t* buffer);
} BlockDevice;

#endif