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

#define PIC_EOI      0x20

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
void pic_send_eoi(uint8_t irq)
{
    if (irq >= 8)
        outb(PIC2_COMMAND, PIC_EOI);

    outb(PIC1_COMMAND, PIC_EOI);
}

// Disable all interrupts
uint16_t pic_get_mask(void)
{
    uint8_t master = inb(PIC1_DATA);
    uint8_t slave  = inb(PIC2_DATA);
    return (uint16_t)master | ((uint16_t)slave << 8);
}

void pic_set_mask(uint8_t irq)
{
    uint16_t port;
    uint8_t value;

    if (irq < 8u)
    {
        port = PIC1_DATA;
    }
    else
    {
        port = PIC2_DATA;
        irq = (uint8_t)(irq - 8u);
    }

    value = (uint8_t)(inb(port) | (uint8_t)(1u << irq));
    outb(port, value);
}

void pic_clear_mask(uint8_t irq)
{
    uint16_t port;
    uint8_t value;

    if (irq < 8u)
    {
        port = PIC1_DATA;
    }
    else
    {
        port = PIC2_DATA;
        irq = (uint8_t)(irq - 8u);
    }

    value = (uint8_t)(inb(port) & (uint8_t)~(uint8_t)(1u << irq));
    outb(port, value);
}

void pic_disable(void)
{
    outb(PIC1_DATA, 0xFF);
    outb(PIC2_DATA, 0xFF);
}