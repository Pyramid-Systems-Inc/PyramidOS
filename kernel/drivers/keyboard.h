#ifndef KEYBOARD_H
#define KEYBOARD_H

#include <stdint.h>

// Initialize keyboard (if needed in future)
void keyboard_init(void);

// Main interrupt handler called by ISR 33
void keyboard_handler(void);

// Non-blocking: returns 0 if buffer is empty.
char keyboard_try_get_char(void);

// Blocking read: halts the CPU while waiting for the next keypress.
char keyboard_get_char(void);

#endif