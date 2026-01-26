# PyramidOS

> **Kernel Version:** v0.8.1 (Hardened)
> **Architecture:** x86 (32-bit Protected Mode)  
> **Boot Standard:** Legacy BIOS (Custom Bootloader)

PyramidOS is a sovereign, monolithic kernel operating system written from scratch in C and Assembly. It features a custom multi-stage bootloader, a robust memory management system, and a command-line interface inspired by the responsiveness of classic systems.

---

## 🚀 Current Status

The system boots into a **Protected Mode Shell** with memory management, hardware interrupts, and timekeeping capabilities.

| Component | Status | Description |
|-----------|--------|-------------|
| **Bootloader (Stage 1/2)** | ✅ Stable | MBR, A20 Enable, E820 Map, Kernel Header Parsing, PM Switch. |
| **Kernel Entry** | ✅ Stable | Stack setup, GDT, IDT (Exception Handling), ISR Stubs. |
| **Memory (PMM/VMM)** | ✅ Stable | Bitmap Allocator, Paging Enabled (Identity Mapped). |
| **PIC Driver** | ✅ Stable | 8259 PIC Remapped to vectors 32-47. |
| **Keyboard Driver** | ✅ Stable | Scancode Set 1 translation, Shift/Caps state, Circular Input Buffer. |
| **System Timer (PIT)** | ✅ Stable | 8253 PIT configured at 100Hz for system ticks and sleep. |
| **Real-Time Clock (RTC)** | ✅ Stable | CMOS register parsing for Wall Clock Time (Y/M/D H:M:S). |
| **KShell** | ✅ Stable | Interactive command interpreter with history and backspace support. |
| **Terminal (VGA Text Mode)** | ✅ Stable | Text Mode (80x25) with hardware cursor support. |
| **CPU Idle / Power Management** | ✅ Stable | Uses STI+HLT (`cpu_idle()`) to avoid busy-waiting when idle. |
| **Kernel Heap** | ✅ Stable | Doubly-linked list allocator with `kmalloc`/`kfree` and coalescing. |
| **VMM** | ✅ Stable | Paging enabled; Heap mapped to `0xD0000000`. |
| **Storage (ATA/PIO)** | 🚧 In Progress | ATA PIO LBA28 sector reads (Read-Only); validated by `diskread` + diagnostics. |

---

## 🛠️ Building and Running

### Prerequisites

* **System:** Linux, WSL2, or MacOS.
* **Toolchain:** `gcc`, `ld`, `make`, `nasm`.
* **Emulator:** `qemu-system-i386`.

### Quick Start

1. **Clean and Build (Release default):**

    ```bash
    make clean && make
    ```

    *Generates `build/pyramidos.img` and `build/kernel.map`.*

2. **Optional: Debug Build:**

    ```bash
    make clean && make debug
    ```

3. **Optional: Strict Warnings (Werror):**

    ```bash
    make clean && make STRICT=1
    ```

4. **Run:**

    ```bash
    make run
    ```

## 🔒 Repository Notice

This repository is currently private / all-rights-reserved. See `NOTICE`.

## 🧹 Project Hygiene

- Formatting baseline: `.editorconfig`
- Contribution guidance: `CONTRIBUTING.md`
- Ownership / review routing: `.github/CODEOWNERS`

---

## 💻 Kernel Shell Commands

Once booted, the **KShell** accepts the following commands:

* `help`    : List available commands.
* `clear`   : Clear the screen and reset cursor.
* `mem`     : Display Physical Memory stats (Total/Free RAM).
* `time`    : Display current Date and Time (from RTC).
* `uptime`  : Show system running time (ticks/seconds).
* `sleep`   : Pause execution for 1 second (Busy-wait test).
* `reboot`  : Restart the system (via Keyboard Controller).
* `diskread`: Read and hex-dump a disk sector by LBA (e.g., `diskread 0`, `diskread 60`).
* `diagnose`: Run kernel diagnostics (PMM/Heap/ATA).
* `crash`   : Force a kernel crash (for testing the panic/exception path).

---

## 📂 Project Structure

```text
/
├── Makefile                  # Master build orchestration (release/debug/strict)
├── NOTICE                    # Private / all-rights-reserved notice (no license granted)
├── docs/                     # Strategic, Architectural, and Tactical roadmaps
├── boot/
│   └── src/legacy/           # 16-bit Assembly Bootloader (MBR + Loader)
└── kernel/
    ├── arch/
    │   └── i386/             # Architecture-specific code (x86)
    │       ├── entry.asm     # Kernel entry (stack + handoff to C)
    │       ├── idt.c/h       # Interrupt Descriptor Table
    │       ├── idt_asm.asm   # ISR/IRQ stubs
    │       └── cpu.h         # Registers + CPU helpers (cli/sti/hlt/idle)
    ├── core/                 # Kernel Core Logic
    │   ├── main.c            # Entry point / init ordering
    │   ├── pmm.c/h           # Physical Memory Manager
    │   ├── vmm.c/h           # Virtual Memory Manager
    │   ├── heap.c/h          # Kernel Heap Allocator
    │   ├── debug.c/h         # Panic system
    │   ├── shell.c/h         # KShell logic
    │   └── selftest.c/h      # Diagnostics
    ├── drivers/              # Hardware drivers
    │   ├── pic.c/h           # 8259 PIC (remap + mask control)
    │   ├── keyboard.c/h      # PS/2 keyboard (buffered input)
    │   ├── timer.c/h         # PIT driver
    │   ├── rtc.c/h           # RTC/CMOS wall-clock time
    │   ├── ata.c/h           # ATA PIO (read-only)
    │   └── terminal.c/h      # VGA text-mode terminal
    └── lib/                  # Freestanding libc-like helpers
        └── string.c/h        # Memory/string ops + atoi
```

---

## 🧠 Architecture Overview

1. **Boot Sequence:** BIOS -> MBR (Stage 1) -> Loader (Stage 2) -> Protected Mode -> Kernel (`0x10000`).
2. **Initialization:**
    * **PMM:** Reads E820 map, initializes Bitmap at `0x20000`.
    * **IDT:** Sets up 256 interrupt vectors (Exceptions + IRQs).
    * **PIC:** Remaps IRQs to avoid CPU conflicts.
    * **VMM:** Identity maps lower 4MB, enables Paging (CR0).
    * **HAL:** Initializes Timer (100Hz) and Keyboard.
3. **Runtime:** The kernel yields control to `shell_run()`, which blocks on buffered keyboard input while the CPU idles via `cpu_idle()` (STI+HLT).

---

## 🔮 Roadmap Snapshot

* **Current:** Dynamic Memory (Heap).
* **Next Up:** Storage Drivers (ATA/PIO) and Filesystem.

*See `docs/` for detailed Roadmap Layers.*
