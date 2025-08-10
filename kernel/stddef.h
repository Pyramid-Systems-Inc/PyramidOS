#ifndef STDDEF_H
#define STDDEF_H

// NULL pointer constant
#define NULL ((void *)0)

// Size type
typedef unsigned int size_t;

// Pointer difference type
typedef int ptrdiff_t;

// Offset of member in structure
#define offsetof(type, member) ((size_t)&((type *)0)->member)

// Common utility functions
extern void itoa(int value, char *str, int base);
extern size_t strlen(const char *str);

#endif /* STDDEF_H */