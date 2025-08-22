#include "pic.h"
#include "io.h"
#include "vga.h"

// Initialize the PIC (Programmable Interrupt Controller)
void pic_init(void)
{
    // Save masks (not used in this implementation, but good practice)
    (void)inb(PIC1_DATA);  // Read and discard current mask
    (void)inb(PIC2_DATA);  // Read and discard current mask

    // Start initialization sequence (in cascade mode)
    outb(PIC1_COMMAND, ICW1_INIT | ICW1_ICW4);
    outb(PIC2_COMMAND, ICW1_INIT | ICW1_ICW4);

    // ICW2: Master PIC vector offset (IRQ 0-7 -> interrupts 32-39)
    outb(PIC1_DATA, 32);
    // ICW2: Slave PIC vector offset (IRQ 8-15 -> interrupts 40-47)
    outb(PIC2_DATA, 40);

    // ICW3: Tell master PIC that there is a slave PIC at IRQ2 (0000 0100)
    outb(PIC1_DATA, 4);
    // ICW3: Tell slave PIC its cascade identity (0000 0010)
    outb(PIC2_DATA, 2);

    // ICW4: Set 8086/88 (MCS-80/85) mode
    outb(PIC1_DATA, ICW4_8086);
    outb(PIC2_DATA, ICW4_8086);

    // Restore saved masks (initially mask all interrupts)
    outb(PIC1_DATA, 0xFF);  // Mask all IRQs on master PIC
    outb(PIC2_DATA, 0xFF);  // Mask all IRQs on slave PIC

    vga_writestring("[OK] PIC initialized\n");
}

// Send End of Interrupt signal
void pic_send_eoi(uint8_t irq)
{
    // If IRQ came from slave PIC, send EOI to both PICs
    if (irq >= 8) {
        outb(PIC2_COMMAND, PIC_EOI);
    }
    // Always send EOI to master PIC
    outb(PIC1_COMMAND, PIC_EOI);
}

// Mask (disable) an IRQ
void pic_mask_irq(uint8_t irq)
{
    uint16_t port;
    uint8_t value;

    if (irq < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        irq -= 8;
    }

    value = inb(port) | (1 << irq);
    outb(port, value);
}

// Unmask (enable) an IRQ
void pic_unmask_irq(uint8_t irq)
{
    uint16_t port;
    uint8_t value;

    if (irq < 8) {
        port = PIC1_DATA;
    } else {
        port = PIC2_DATA;
        irq -= 8;
    }

    value = inb(port) & ~(1 << irq);
    outb(port, value);
}

// Disable PIC completely (mask all interrupts)
void pic_disable(void)
{
    outb(PIC1_DATA, 0xFF);
    outb(PIC2_DATA, 0xFF);
}
