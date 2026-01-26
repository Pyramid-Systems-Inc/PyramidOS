#include "block.h"

#include "string.h"

static BlockDevice *g_devices[BLOCK_MAX_DEVICES];
static uint32_t g_device_count = 0u;

void block_init(void)
{
    for (uint32_t i = 0; i < BLOCK_MAX_DEVICES; i++)
        g_devices[i] = 0;

    g_device_count = 0u;
}

int block_register(BlockDevice *dev)
{
    if (!dev)
        return BLOCK_ERROR;

    if (dev->name[0] == '\0')
        return BLOCK_ERROR;

    if (dev->sector_size == 0u)
        return BLOCK_ERROR;

    if (!dev->read)
        return BLOCK_ERROR;

    if (g_device_count >= BLOCK_MAX_DEVICES)
        return BLOCK_BUSY;

    /* Reject duplicate names to keep lookups deterministic. */
    for (uint32_t i = 0; i < g_device_count; i++)
    {
        if (g_devices[i] && strcmp(g_devices[i]->name, dev->name) == 0)
            return BLOCK_ERROR;
    }

    g_devices[g_device_count] = dev;
    g_device_count++;

    return BLOCK_SUCCESS;
}

uint32_t block_count(void)
{
    return g_device_count;
}

BlockDevice *block_get(uint32_t index)
{
    if (index >= g_device_count)
        return 0;

    return g_devices[index];
}

BlockDevice *block_get_by_name(const char *name)
{
    if (!name)
        return 0;

    for (uint32_t i = 0; i < g_device_count; i++)
    {
        if (!g_devices[i])
            continue;

        if (strcmp(g_devices[i]->name, name) == 0)
            return g_devices[i];
    }

    return 0;
}