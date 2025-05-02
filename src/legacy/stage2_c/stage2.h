// Placeholder for Stage 2 C Header File
#ifndef STAGE2_H
#define STAGE2_H

// Define constants (e.g., colors, buffer sizes)
#define COLOR_TITLE     0x1F    // Blue background, white text
#define COLOR_NORMAL    0x07    // Black background, light gray text
#define COLOR_SUCCESS   0x0A    // Black background, light green text
#define COLOR_ERROR     0x0C    // Black background, light red text
#define COLOR_PROMPT    0x0B    // Black background, light cyan text

#define BUFFER_SIZE     64      // Command buffer size

// Function prototypes for C functions
void stage2_main(unsigned char boot_drive);
void process_command(const char *command);
void read_line(char *buffer, int max_len);
void clear_screen_c(void);
void print_string_c(const char *str, unsigned char color);
void print_char_c(char c, unsigned char color);
void print_newline_c(unsigned char color);
void print_hex_word_c(unsigned short val, unsigned char color);

// Prototypes for assembly helper functions (callable from C)
// Using -zc compiler flag, names should match assembly 'global' names directly.
extern void bios_print_char(char c, unsigned char color, unsigned short page);
extern void bios_set_cursor(unsigned char row, unsigned char col, unsigned short page);
extern unsigned short bios_read_key(void); // Returns AH=scan code, AL=ASCII
extern void bios_scroll_up(unsigned char lines, unsigned char attr, unsigned char r1, unsigned char c1, unsigned char r2, unsigned char c2);
extern unsigned short bios_get_memory_size(void); // Returns KB extended memory or 0xFFFF on error
extern void reboot_system(void); // Should not return
extern int check_a20_asm(void); // Returns 1 if enabled, 0 if disabled
extern int enable_a20_kbc_asm(void); // Returns 0 on success, 1 on failure
extern void enable_a20_fast_asm(void);
extern int copy_bpb_to(void *buffer); // Returns 1 on success, 0 on fail
// extern void enter_pmode_asm(void); // Placeholder for pmode switch

// Function prototypes for C functions that use helpers
void enable_a20_line(void);
void display_fsinfo(void);
unsigned short get_memory_size_kb(void); // Gets extended memory size in KB
void enter_protected_mode_c(void);


#endif // STAGE2_H
