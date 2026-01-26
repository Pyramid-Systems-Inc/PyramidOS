#ifndef MBR_H
#define MBR_H

#include <stdint.h>

#include "block.h"

/*
 * MBR partition discovery (legacy DOS partition table).
 *
 * Reads LBA0 from the provided disk block device, validates 0x55AA, and registers
 * partition block devices named: <disk_name>p1..p4 (e.g. "disk0p1").
 *
 * Return: 0 on success, non-zero on failure.
 */
int mbr_scan_and_register(BlockDevice *disk, const char *disk_name);

#endif /* MBR_H */