#ifndef TIMER_H
#define TIMER_H

#include "stdint.h"

// Timer functions
void timer_init(void);
void irq_timer_handler(void);
uint32_t timer_get_ticks(void);
uint32_t timer_get_seconds(void);
void timer_sleep(uint32_t ticks);

#endif /* TIMER_H */