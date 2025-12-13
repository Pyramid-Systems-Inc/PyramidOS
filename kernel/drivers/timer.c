#include "timer.h"
#include "io.h"

// 1.193182 MHz / 100 Hz = 11931 divisor
#define TIMER_FREQ 100
#define TIMER_DIVISOR 11931

volatile uint64_t ticks = 0;

void timer_init(void)
{
    // Send command: Channel 0, Access Lo/Hi byte, Mode 3 (Square Wave), Binary
    outb(0x43, 0x36);

    // Send Divisor Low Byte
    outb(0x40, (uint8_t)(TIMER_DIVISOR & 0xFF));
    // Send Divisor High Byte
    outb(0x40, (uint8_t)((TIMER_DIVISOR >> 8) & 0xFF));
}

void timer_handler(void)
{
    ticks++;
}

uint64_t timer_get_ticks(void)
{
    return ticks;
}

// Naive sleep: waits for X milliseconds
void timer_sleep(uint32_t ms)
{
    // ticks increments 100 times/sec -> 1 tick = 10ms
    // target_ticks = ms / 10
    uint64_t target = ticks + (ms / 10);
    while (ticks < target)
    {
        asm volatile("hlt");
    }
}