#include "timer.h"
#include "vga.h"
#include "stdint.h"

// Timer variables
static uint32_t timer_ticks = 0;
static uint32_t seconds = 0;

// PIT (Programmable Interval Timer) constants
#define PIT_COMMAND_PORT 0x43
#define PIT_DATA_PORT_0  0x40
#define PIT_FREQUENCY    1193180  // Base frequency of PIT
#define TARGET_FREQUENCY 100      // 100 Hz (10ms intervals)

void timer_init(void) {
    // Calculate the divisor for our target frequency
    uint32_t divisor = PIT_FREQUENCY / TARGET_FREQUENCY;
    
    // Send command to PIT
    // Mode 3 (square wave), channel 0, binary mode
    __asm__ volatile("outb %0, %1" : : "a"(0x36), "Nd"(PIT_COMMAND_PORT));
    
    // Send divisor (low byte then high byte)
    __asm__ volatile("outb %0, %1" : : "a"((uint8_t)(divisor & 0xFF)), "Nd"(PIT_DATA_PORT_0));
    __asm__ volatile("outb %0, %1" : : "a"((uint8_t)((divisor >> 8) & 0xFF)), "Nd"(PIT_DATA_PORT_0));
    
    vga_writestring("[OK] Timer initialized (100 Hz)\n");
}

void irq_timer_handler(void) {
    timer_ticks++;
    
    // Update seconds counter every 100 ticks (1 second at 100 Hz)
    if (timer_ticks % 100 == 0) {
        seconds++;
        
        // Optional: Display timer every 5 seconds for debugging
        if (seconds % 5 == 0) {
            // Save current cursor position and color
            static size_t old_row = 0, old_col = 0;
            uint8_t old_color = vga_get_color();
            
            // Display uptime in top-right corner
            vga_set_cursor(65, 0);
            vga_setcolor(vga_entry_color(VGA_COLOR_LIGHT_CYAN, VGA_COLOR_BLACK));
            
            char time_str[16];
            itoa(seconds, time_str, 10);
            vga_writestring("Uptime: ");
            vga_writestring(time_str);
            vga_writestring("s    ");
            
            // Restore cursor and color
            vga_setcolor(old_color);
            // Note: We don't restore cursor position to avoid interfering with output
        }
    }
}

uint32_t timer_get_ticks(void) {
    return timer_ticks;
}

uint32_t timer_get_seconds(void) {
    return seconds;
}

void timer_sleep(uint32_t ticks) {
    uint32_t target = timer_ticks + ticks;
    while (timer_ticks < target) {
        __asm__ volatile("hlt");
    }
}