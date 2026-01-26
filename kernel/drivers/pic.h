#ifndef PIC_H
#define PIC_H

#include <stdint.h>

void pic_remap(void);
void pic_send_eoi(uint8_t irq);

/* Mask control (IRQ 0-15). Mask bit = 1 disables the IRQ line. */
uint16_t pic_get_mask(void);
void pic_set_mask(uint8_t irq);
void pic_clear_mask(uint8_t irq);

/* Mask everything. */
void pic_disable(void);

#endif