#ifndef IO_H
#define IO_H

#include <stdint.h>

// Write a byte to a port
static inline void outb(uint16_t port, uint8_t val) {
    asm volatile ( "outb %0, %1" : : "a"(val), "Nd"(port) );
}

// Read a byte from a port
static inline uint8_t inb(uint16_t port) {
    uint8_t ret;
    asm volatile ( "inb %1, %0" : "=a"(ret) : "Nd"(port) );
    return ret;
}

// Wait a tiny bit (useful for slow hardware like PIC)
static inline void io_wait(void) {
    outb(0x80, 0);
}

// Read 'cnt' words (16-bit) from 'port' into 'addr'
static inline void insw(uint16_t port, void* addr, uint32_t cnt) {
    asm volatile("rep insw" : "+D"(addr), "+c"(cnt) : "d"(port) : "memory");
}

// Write 'cnt' words to 'port' from 'addr'
static inline void outsw(uint16_t port, void* addr, uint32_t cnt) {
    asm volatile("rep outsw" : "+S"(addr), "+c"(cnt) : "d"(port) : "memory");
}

#endif