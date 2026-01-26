#ifndef ATA_BLOCK_H
#define ATA_BLOCK_H

#include <stdint.h>

/* Register ATA PIO drives as generic block devices (e.g., "disk0"). */
int ata_block_register_devices(void);

#endif /* ATA_BLOCK_H */