# PyramidOS

> **Kernel Version:** v0.5 (IRQ Test Build)  
> **Architecture:** x86 (32-bit Protected Mode)  
> **Boot Standard:** Legacy BIOS (Custom Bootloader)

PyramidOS is a monolithic kernel operating system written from scratch in C and Assembly. It features a custom multi-stage bootloader, a robust memory management system (Paging & Bitmap Allocation), and a fully interrupt-driven architecture.

---

## 🚀 Current Status

The system successfully boots into **32-bit Protected Mode** with **Paging enabled** and handles hardware interrupts.

| Component | Status | Description |
|-----------|--------|-------------|
| **Bootloader Stage 1** | ✅ Stable | 512-byte MBR. Probes INT 13h Ext, falls back to CHS. Loads Stage 2. |
| **Bootloader Stage 2** | ✅ Stable | Enables A20, parses E820 memory map, reads custom Kernel Header, switches to 32-bit PM. |
| **Kernel Entry** | ✅ Stable | Sets up stack, resets EFLAGS, jumps to C `k_main`. |
| **GDT** | ✅ Stable | Global Descriptor Table with Ring 0 Code/Data segments. |
| **IDT / ISR** | ✅ Stable | Interrupt Descriptor Table handling CPU Exceptions (Div-by-zero, Page Faults). |
| **PIC Driver** | ✅ Stable | 8259 PIC remapped to vectors 32-47 to avoid CPU exception conflicts. |
| **PMM** | ✅ Stable | Physical Memory Manager using a Bitmap Allocator. Parses E820 map. |
| **VMM** | ✅ Stable | Virtual Memory Manager. Identity maps lower 4MB. Enables Paging (CR0). |
| **Keyboard** | ⚠️ Basic | IRQ1 handler active. Detects key presses (Scancode reading implemented). |
| **VGA Driver** | ✅ Stable | Direct memory access text mode (80x25). |

---

## 🛠️ Building and Running

### Prerequisites

You need a Linux-like environment (WSL2, Ubuntu, or MacOS) with the following tools:

* **Build:** `make`
* **Compiler:** `gcc` (native or cross-compiler `i686-elf-gcc`)
* **Linker:** `ld` (native or cross-linker `i686-elf-ld`)
* **Assembler:** `nasm`
* **Emulator:** `qemu-system-i386`

### Build Instructions

1. **Clean and Build:**

    ```bash
    make clean && make
    ```

    *This produces `build/pyramidos.img` (Floppy Image).*

2. **Run in Emulator:**

    ```bash
    make run
    ```

---

## 📂 Project Structure

```text
/
├── Makefile             # Master build orchestration
├── README.md            # This documentation
├── boot/
│   └── src/
│       └── legacy/
│           ├── stage1.asm  # MBR Bootloader
│           └── stage2.asm  # 16-bit Loader & PM Switch
└── kernel/
    ├── entry.asm        # 32-bit Assembly Entry Point
    ├── header.asm       # Kernel Metadata Header
    ├── linker.ld        # Linker Script (Maps kernel to 1MB)
    ├── main.c           # Kernel Entry (k_main)
    ├── bootinfo.h       # Bootloader -> Kernel Interface
    ├── io.h             # I/O Port Wrappers (inb/outb)
    ├── string.c/h       # Memory utilities (memset, memcpy)
    ├── pmm.c/h          # Physical Memory Manager
    ├── vmm.c/h          # Virtual Memory Manager (Paging)
    ├── idt.c/h          # Interrupt Descriptor Table
    ├── idt_asm.asm      # ISR Assembly Stubs
    └── pic.c/h          # Programmable Interrupt Controller
```

---

## 🧠 Architecture Overview

### 1. The Boot Process

1. **BIOS** loads `stage1.bin` to `0x7C00`.
2. **Stage 1** checks for LBA support. If available, it reads **Stage 2** from disk. If not, it uses CHS geometry. Jumps to `0x8000`.
3. **Stage 2** enables the A20 line, queries the BIOS for the E820 Memory Map, and reads the `kernel.img`.
4. It validates the **Kernel Header** (Magic: `PyrImg01`).
5. It writes a `BootInfo` structure to physical address `0x5000`.
6. It loads the GDT, disables interrupts, sets CR0 bit 0, and jumps to `0x10000` (Protected Mode).

### 2. Kernel Initialization

1. **entry.asm** sets up the stack and calls `k_main`.
2. **k_main** initializes the **PMM** (reading the map at `0x5000`).
3. **IDT** is initialized to catch CPU crashes.
4. **PIC** is remapped (IRQs 0-7 -> INT 32-39).
5. **VMM** creates the first Page Directory, identity maps the first 4MB, and enables Paging.
6. **Interrupts** are enabled (`sti`), allowing the Keyboard IRQ to fire.

---

## 🔮 Roadmap (Next Steps)

* [ ] **Keyboard Driver:** Translate Scancodes to ASCII characters.

* [ ] **Shell:** Implement a basic command-line interface.
* [ ] **Filesystem:** Read-only FAT32 support.
* [ ] **Multitasking:** Implement a simple Round-Robin scheduler.
