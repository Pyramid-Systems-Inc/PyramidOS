#ifndef KEYBOARD_H
#define KEYBOARD_H

#include <stdint.h>

// Initialize keyboard (if needed in future)
void keyboard_init(void);

// Main interrupt handler called by ISR 33
void keyboard_handler(void);

#endif