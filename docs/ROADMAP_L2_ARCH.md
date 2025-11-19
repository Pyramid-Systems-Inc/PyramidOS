# Layer 2: Architectural Design (PyramidOS)

This document details the internal design of the kernel subsystems. It bridges the gap between the Strategic Roadmap (Layer 1) and the actual Code (Layer 3).

---

## 1. 🧠 Memory Management Architecture

### 1.1 Physical Memory Manager (PMM)

* **Algorithm:** Bitmap Allocator (Optimized with Next-Fit).
* **Granularity:** 4KiB Blocks (Frames).
* **Metadata Storage:** Physical `0x00020000`.

### 1.2 Virtual Memory Manager (VMM)

* **Mechanism:** x86 Paging (CR3).
* **Architecture Goal (Milestone 4): Higher-Half Kernel**
  * **User Space:** `0x00000000` to `0xBFFFFFFF` (3GB).
  * **Kernel Space:** `0xC0000000` to `0xFFFFFFFF` (1GB).
  * **Implementation:**
    * Linker moves symbols to `0xC0000000`.
    * Bootloader (or `entry.asm`) sets up a Page Table mapping `0xC00...` -> `0x001...` (Physical).
    * This prevents User Mode apps from ever seeing Kernel code (protected by Supervisor bit).

### 1.3 Kernel Heap

* **Goal:** Dynamic memory allocation (`kmalloc`/`kfree`).
* **Algorithm:** Doubly Linked List with Safety Canaries.
* **Location:** Placed in Kernel Space (e.g., starting at `0xD0000000`).

---

## 2. ⚡ Interrupt & Exception Model

### 2.1 Interrupt Descriptor Table (IDT)

* **Vector Assignment:** 0-31 (Exceptions), 32-47 (IRQs), 0x80 (Syscalls).
* **Handling Flow:** CPU -> ASM Stub -> C Handler -> Driver -> EOI -> IRET.

### 2.2 Task State Segment (TSS) - Required for Ring 3

* **Role:** The x86 CPU needs to know where the **Kernel Stack** is when an interrupt occurs inside a User App.
* **Implementation:**
  * One TSS entry in the GDT.
  * `ESP0` field updated by the Scheduler on every context switch.
  * Without this, a User Mode interrupt causes a Double Fault (Stack Fault).

## 3. 🔌 Hardware Abstraction Layer (HAL)

### 3.1 Input Subsystem

* **Keyboard:** PS/2 Scancode translation (Set 1) -> ASCII Buffer.
* **Mouse:** PS/2 Packet parsing (3-byte packets) -> Event Queue.

### 3.2 System Timer

* **PIT:** 8253/8254 (Channel 0, Mode 3) @ 100 Hz.
* **Usage:** Preemptive Scheduler quantum & System Uptime.

### 3.3 Storage (ATA/PIO)

* **Mode:** PIO (Programmed I/O) initially, DMA later.
* **Addressing:** LBA28 (28-bit Logical Block Addressing).

---

## 4. 🔄 Process Management & Executable Format

### 4.1 Pyramid Executable Format (PXF)

* **Concept:** A lightweight, custom binary format designed for fast loading and simple parsing, replacing complex ELF/PE structures.
* **Header Structure:**

    ```c
    struct PXF_Header {
        uint32_t magic;       // 'PYRX' (0x58525950)
        uint32_t version;     // Format version
        uint32_t entry_point; // Virtual address of entry
        uint32_t text_offset; // Offset to code section
        uint32_t text_size;   // Size of code
        uint32_t data_offset; // Offset to data section
        uint32_t data_size;   // Size of data
        uint32_t bss_size;    // Size of uninitialized data
    };
    ```

* **Loading Strategy:**
    1. Validate Magic.
    2. VMM allocates pages for Text, Data, and BSS.
    3. Loader reads bytes from disk into allocated RAM.
    4. Loader zeros out BSS.
    5. Jump to `entry_point` (Ring 3).

### 4.2 Process Control Block (PCB)

* **Data:**
  * `pid`: Process ID.
  * `esp`: Kernel Stack Pointer.
  * `cr3`: Page Directory (Memory Context).
  * `state`: READY, RUNNING, BLOCKED, ZOMBIE.
  * `file_handles`: Array of open resource pointers.

### 4.3 Scheduler

* **Algorithm:** Round Robin (Time Slicing).
* **Context Switch:** Save registers -> Swap CR3 -> Swap ESP -> Restore registers.

---

## 5. 💾 Filesystem Architecture

### 5.1 Virtual File System (VFS)

* **Role:** Abstract interface for file operations (`open`, `read`, `write`, `close`).
* **Mount Points:** Root `/` mapped to primary partition.

### 5.2 Pyramid File System (PyFS)

* **Design Goal:** A custom, journaled filesystem optimized for the kernel.
* **Structure:**
  * **Superblock:** FS Geometry and Magic.
  * **Inode Table:** Metadata (Permissions, Size, Block Pointers).
  * **Block Bitmap:** Allocation tracking.
  * **Data Blocks:** Raw content.
* *(Note: FAT32 support will be maintained for boot interoperability).*

---

## 6. ⚙️ Configuration Subsystem

### 6.1 Pyramid Configuration Database (PyDB)

* **Concept:** A custom, binary, hierarchical key-value store replacing text-based `.ini` files and the proprietary Windows Registry.
* **Storage:** Memory-mapped binary tree.
* **Node Structure:**

    ```c
    struct PyDB_Node {
        char name[32];
        uint8_t type;    // INT, STRING, BINARY, LIST
        uint32_t size;
        void* data;
        struct PyDB_Node* children;
        struct PyDB_Node* next;
    };
    ```

* **Persistence:** Serialized to `SYSTEM.PDB` on shutdown, loaded on boot.
