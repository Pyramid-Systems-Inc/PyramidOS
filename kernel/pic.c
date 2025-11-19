#include "pic.h"
#include "io.h"

// PIC Ports
#define PIC1_COMMAND 0x20
#define PIC1_DATA    0x21
#define PIC2_COMMAND 0xA0
#define PIC2_DATA    0xA1

// Initialization Command Words
#define ICW1_INIT    0x10
#define ICW1_ICW4    0x01
#define ICW4_8086    0x01

// Remap the PICs to 0x20 (32) and 0x28 (40)
void pic_remap(void) {
    uint8_t a1, a2;

    // Save current masks (which IRQs are ignored)
    a1 = inb(PIC1_DATA);
    a2 = inb(PIC2_DATA);

    // Start Initialization Sequence (in cascade mode)
    outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();
    outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);
    io_wait();

    // ICW2: Master PIC vector offset (32)
    outb(PIC1_DATA, 0x20);
    io_wait();
    // ICW2: Slave PIC vector offset (40)
    outb(PIC2_DATA, 0x28);
    io_wait();

    // ICW3: Tell Master about Slave at IRQ2
    outb(PIC1_DATA, 4);
    io_wait();
    // ICW3: Tell Slave its cascade identity (2)
    outb(PIC2_DATA, 2);
    io_wait();

    // ICW4: 8086 mode
    outb(PIC1_DATA, ICW4_8086);
    io_wait();
    outb(PIC2_DATA, ICW4_8086);
    io_wait();

    // Restore masks
    outb(PIC1_DATA, a1);
    outb(PIC2_DATA, a2);
}

// Send End-Of-Interrupt (Must do this after handling an IRQ)
void pic_send_eoi(uint8_t irq) {
    if(irq >= 8)
        outb(PIC2_COMMAND, 0x20);
    
    outb(PIC1_COMMAND, 0x20);
}

// Disable all interrupts
void pic_disable(void) {
    outb(PIC1_DATA, 0xFF);
    outb(PIC2_DATA, 0xFF);
}