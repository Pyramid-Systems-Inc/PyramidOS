#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "stdint.h"

// Keyboard functions
void keyboard_init(void);
void irq_keyboard_handler(void);
void process_command(const char* command);

// strcmp is now in string.h

#endif /* KEYBOARD_H */