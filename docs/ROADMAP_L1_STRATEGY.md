# Layer 1: Strategic Roadmap (PyramidOS)

**Vision:** A sovereign, monolithic kernel engineered from scratch in C/Assembly. It delivers a user experience inspired by the intuitiveness of Windows 95, but powered by a completely custom, non-proprietary internal architecture.

> **Legend:**
> ✅ = Completed | 🚧 = In Progress | 📅 = Planned | 🔮 = Long Term Vision

---

## 1. 🛤️ Milestone 1: The Bootloader (PyramidBL)

**Goal:** Reliably load the kernel payload into memory and transition the CPU to a usable state.

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
| **Kernel Heap** | 🚧 | **[NEXT PRIORITY]** Dynamic memory (`kmalloc`/`kfree`) for kernel objects. |
| **Multitasking** | 📅 | Custom Process Control Blocks (PCB), Round-Robin Scheduler. |

---

## 3. ⌨️ Milestone 3: Interaction & Drivers (HAL)

**Goal:** Allow the user to interact with the system and persist data.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Keyboard Driver** | ✅ | Scancode translation, Circular Buffer, Shift/Caps support. |
| **Text Shell (KShell)** | ✅ | Interactive CLI, Command parsing, History (Basic). |
| **RTC/CMOS** | ✅ | Real-Time Clock driver for system Date/Time. |
| **System Timer** | ✅ | PIT Driver (100Hz) for uptime and sleep. |
| **Storage Drivers** | 📅 | **[PLANNED]** ATA/PIO driver for reading hard disks. |
| **Filesystem (VFS)** | 📅 | Virtual File System abstraction layer. |

---

## 4. 📦 Milestone 4: Userland & Protected Execution

**Goal:** Securely execute separate programs in Ring 3 with full isolation.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Higher-Half Kernel** | 📅 | **[CRITICAL]** Remap Kernel to `0xC0000000` to free lower memory for apps. |
| **Task State (TSS)** | 📅 | **[CRITICAL]** Hardware structure for Ring 3 -> Ring 0 stack switching. |
| **User Mode (Ring 3)** | 📅 | GDT User Segments, entering User Mode via `IRET`. |
| **System Calls** | 📅 | Custom `INT 0x80` or `SYSENTER` API interface. |
| **PXF Loader** | 📅 | **Pyramid Executable Format**. A custom binary format parser. |
| **Config Database** | 📅 | A custom hierarchical binary configuration store. |

---

## 5. 🖥️ Milestone 5: The Graphical User Interface

**Goal:** A unique desktop environment inspired by the "Classic" 95 feel.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Video Driver** | 📅 | VESA BIOS Extensions (VBE) linear framebuffer. |
| **Graphics Engine** | 📅 | Custom 2D drawing primitives (Line, Rect, Blit). |
| **Window Manager** | 📅 | Custom Compositor, Z-Ordering, Message Passing. |
| **Widget Toolkit** | 📅 | Custom UI Controls (Buttons, Windows, Taskbar). |
| **Desktop Shell** | 📅 | Icons, Wallpaper, Start Menu (Pyramid Style). |

---

## 6. 🌐 Milestone 6: Advanced Features

**Goal:** Connectivity and Optimization.

| Feature | Status | Description |
| :--- | :---: | :--- |
| **Networking** | 🔮 | Network Card Drivers, Custom TCP/IP Stack. |
| **Audio** | 🔮 | AC97 or SoundBlaster drivers. |
| **Pyramid Component Model**| 🔮 | Custom IPC system for object embedding (Replacing OLE/COM). |
| **SMP** | 🔮 | Multi-core support (APIC). |
