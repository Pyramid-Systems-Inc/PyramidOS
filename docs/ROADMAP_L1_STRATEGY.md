# Layer 1: Strategic Roadmap (PyramidOS)

**Vision:** A modern, monolithic kernel engineered from scratch in C/Assembly, recreating the user experience of Windows 95 with modern reliability and security standards.

> **Legend:**
> ✅ = Completed | 🚧 = In Progress | 📅 = Planned | 🔮 = Long Term Vision

---

## 1. 🛤️ Milestone 1: The Bootloader (PyramidBL)

**Goal:** reliably load the kernel payload into memory and transition the CPU to a usable state.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Legacy BIOS (Stage 1)** | ✅ | MBR, 512-byte limit, CHS/LBA disk reading. |
| **Legacy BIOS (Stage 2)** | ✅ | A20 enable, E820 memory map, Kernel Header parsing. |
| **Protected Mode Setup** | ✅ | GDT setup, 32-bit transition, jump to Kernel Entry. |
| **UEFI Support** | 📅 | Modern UEFI bootloader (EDK2) loading from ESP. |
| **Multiboot Compliance** | 🔮 | Standard header for compatibility with GRUB/QEMU. |

---

## 2. 🧠 Milestone 2: Kernel Core Foundation

**Goal:** Establish control over the hardware resources (CPU, RAM, Interrupts).

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Kernel Entry** | ✅ | Stack setup, Environment cleanup, C Runtime handoff. |
| **Physical Memory (PMM)** | ✅ | Bitmap allocator, E820 map parsing, 4KB Page Frame allocation. |
| **Interrupts (IDT)** | ✅ | Exception handling (Page Faults, Div-by-zero) & Hardware IRQs. |
| **Virtual Memory (VMM)** | ✅ | Paging Enabled (CR3/CR0), Identity Mapping, Kernel Higher-Half (Partial). |
| **Hardware Interrupts** | ✅ | 8259 PIC Remapping, IRQ Masking/Unmasking. |
| **Kernel Heap** | 🚧 | Dynamic memory (`kmalloc`/`kfree`) for kernel objects. |
| **Multitasking** | 📅 | Process Control Blocks (PCB), Context Switching, Scheduler. |

---

## 3. ⌨️ Milestone 3: Interaction & Drivers (HAL)

**Goal:** Allow the user to interact with the system and persist data.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Keyboard Driver** | 🚧 | **[CURRENT PRIORITY]** Scancode translation, Buffer management. |
| **Text Shell (KShell)** | 📅 | Basic command interpreter (`help`, `mem`, `clear`). |
| **Storage Drivers** | 📅 | ATA/PIO driver for reading hard disks. |
| **Filesystem (VFS)** | 📅 | Virtual File System abstraction. |
| **FAT32 Support** | 📅 | Read/Write support for the FAT32 filesystem. |
| **RTC/CMOS** | 📅 | Real-Time Clock driver for system time. |

---

## 4. 📦 Milestone 4: Userland & Syscalls

**Goal:** Execute separate programs in Ring 3 protected mode.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **User Mode (Ring 3)** | 📅 | GDT User Segments, TSS (Task State Segment). |
| **System Calls** | 📅 | `INT 0x80` interface or `SYSENTER` implementation. |
| **Program Loader** | 📅 | ELF or PE (Windows) executable parsing and loading. |
| **Standard Library** | 📅 | `libc` implementation for user programs. |

---

## 5. 🖥️ Milestone 5: The Graphical User Interface

**Goal:** The "Windows 95" Experience.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Video Driver** | 📅 | VESA BIOS Extensions (VBE) linear framebuffer. |
| **Graphics Library** | 📅 | Drawing primitives (Line, Rect, Blit). |
| **Window Manager** | 📅 | Compositor, Z-Ordering, Event Loop. |
| **GUI Framework** | 📅 | Controls (Buttons, Windows, Taskbar). |
| **Desktop Shell** | 📅 | Icons, Wallpaper, Start Menu. |

---

## 6. 🌐 Milestone 6: Advanced Features

**Goal:** Connectivity and Optimization.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Networking** | 🔮 | Network Card Drivers, TCP/IP Stack. |
| **Audio** | 🔮 | AC97 or SoundBlaster drivers. |
| **USB Support** | 🔮 | UHCI/EHCI/XHCI controllers. |
| **Symmetric Multi-Processing** | 🔮 | Multi-core support (APIC). |
