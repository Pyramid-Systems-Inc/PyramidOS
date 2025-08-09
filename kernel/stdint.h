#ifndef STDINT_H
#define STDINT_H

// Exact-width integer types
typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef signed short int16_t;
typedef unsigned short uint16_t;
typedef signed int int32_t;
typedef unsigned int uint32_t;
typedef signed long long int64_t;
typedef unsigned long long uint64_t;

// Pointer-width integer types
typedef unsigned int uintptr_t;
typedef signed int intptr_t;

// Maximum width integer types
typedef uint64_t uintmax_t;
typedef int64_t intmax_t;

#endif /* STDINT_H */