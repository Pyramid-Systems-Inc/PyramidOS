#ifndef STRING_H
#define STRING_H

#include "stddef.h"

// String manipulation functions
size_t strlen(const char *str);
int strcmp(const char *str1, const char *str2);
char *strcpy(char *dest, const char *src);
char *strncpy(char *dest, const char *src, size_t n);
void *memset(void *s, int c, size_t n);
void *memcpy(void *dest, const void *src, size_t n);

// Number to string conversion
void itoa(int value, char *str, int base);
void utoa(unsigned int value, char *str, int base);

#endif /* STRING_H */
