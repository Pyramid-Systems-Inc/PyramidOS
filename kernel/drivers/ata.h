#ifndef ATA_H
#define ATA_H

#include <stdbool.h>
#include <stdint.h>

/* --------------------------------------------------------------------------
 * ATA Bus I/O Ports (Primary Bus, legacy ISA)
 * -------------------------------------------------------------------------- */
#define ATA_DATA        0x1F0u
#define ATA_ERROR       0x1F1u
#define ATA_FEATURES    0x1F1u
#define ATA_SECTOR_CNT  0x1F2u
#define ATA_LBA_LO      0x1F3u
#define ATA_LBA_MID     0x1F4u
#define ATA_LBA_HI      0x1F5u
#define ATA_DRIVE_HEAD  0x1F6u
#define ATA_STATUS      0x1F7u
#define ATA_COMMAND     0x1F7u

/* Control / Alternate Status (Primary) */
#define ATA_ALT_STATUS  0x3F6u
#define ATA_DEV_CTRL    0x3F6u

/* --------------------------------------------------------------------------
 * Status Bits
 * -------------------------------------------------------------------------- */
#define ATA_SR_BSY      0x80u    /* Busy */
#define ATA_SR_DRDY     0x40u    /* Device ready */
#define ATA_SR_DF       0x20u    /* Device fault */
#define ATA_SR_DRQ      0x08u    /* Data request ready */
#define ATA_SR_ERR      0x01u    /* Error */

/* --------------------------------------------------------------------------
 * Commands
 * -------------------------------------------------------------------------- */
#define ATA_CMD_READ_PIO     0x20u
#define ATA_CMD_WRITE_PIO    0x30u
#define ATA_CMD_IDENTIFY     0xECu

/* --------------------------------------------------------------------------
 * Drive Select
 * -------------------------------------------------------------------------- */
#define ATA_DRIVE_MASTER 0
#define ATA_DRIVE_SLAVE  1

#define ATA_DRIVE_SELECT_MASTER 0xA0u
#define ATA_DRIVE_SELECT_SLAVE  0xB0u

/* LBA28 constants (no magic numbers) */
#define ATA_LBA28_MAX           0x0FFFFFFFu
#define ATA_DRIVE_LBA_MASTER    0xE0u
#define ATA_DRIVE_LBA_SLAVE     0xF0u

/* ATA sector size (PIO) */
#define ATA_SECTOR_SIZE         512u

/* --------------------------------------------------------------------------
 * Return codes (0 = success)
 * -------------------------------------------------------------------------- */
#define ATA_OK                  0
#define ATA_ERR_TIMEOUT_BSY     1
#define ATA_ERR_TIMEOUT_DRQ     2
#define ATA_ERR_DEVICE          3
#define ATA_ERR_INVALID_PARAM   4
#define ATA_ERR_LBA_RANGE       5
#define ATA_ERR_NO_DEVICE       6
#define ATA_ERR_UNSUPPORTED     7

void ata_init(void);

/* LBA28 PIO read (1 sector). drive: ATA_DRIVE_MASTER / ATA_DRIVE_SLAVE */
int ata_read_sector(int drive, uint32_t lba, uint8_t *buffer);

/* Query helpers (valid after ata_init). */
bool ata_is_present(int drive);
uint32_t ata_get_lba28_sectors(int drive);

#endif /* ATA_H */