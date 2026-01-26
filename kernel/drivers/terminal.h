#ifndef TERMINAL_H
#define TERMINAL_H

#include <stdint.h>

/* VGA text-mode color attributes */
#define TERM_COLOR_BLACK        0x00u
#define TERM_COLOR_BLUE         0x01u
#define TERM_COLOR_GREEN        0x02u
#define TERM_COLOR_CYAN         0x03u
#define TERM_COLOR_RED          0x04u
#define TERM_COLOR_MAGENTA      0x05u
#define TERM_COLOR_BROWN        0x06u
#define TERM_COLOR_LIGHT_GREY   0x07u
#define TERM_COLOR_DARK_GREY    0x08u
#define TERM_COLOR_LIGHT_BLUE   0x09u
#define TERM_COLOR_LIGHT_GREEN  0x0Au
#define TERM_COLOR_LIGHT_CYAN   0x0Bu
#define TERM_COLOR_LIGHT_RED    0x0Cu
#define TERM_COLOR_LIGHT_MAGENTA 0x0Du
#define TERM_COLOR_YELLOW       0x0Eu
#define TERM_COLOR_WHITE        0x0Fu

void term_init(void);
void term_clear(void);
void term_print(const char *str, uint8_t color);
void term_print_hex(uint32_t n, uint8_t color);

#endif /* TERMINAL_H */