#ifndef KEYBOARD_H
#define KEYBOARD_H

#include "stdint.h"

// Keyboard functions
void keyboard_init(void);
void irq_keyboard_handler(void);
void process_command(const char* command);

// Utility functions
int strcmp(const char* str1, const char* str2);

#endif /* KEYBOARD_H */