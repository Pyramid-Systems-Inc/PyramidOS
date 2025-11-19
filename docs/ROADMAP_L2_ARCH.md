# Layer 2: Architectural Design (PyramidOS)

This document details the internal design of the kernel subsystems. It bridges the gap between the Strategic Roadmap (Layer 1) and the actual Code (Layer 3).

---

## 1. 🧠 Memory Management Architecture

### 1.1 Physical Memory Manager (PMM)

* **Algorithm:** Bitmap Allocator.
* **Granularity:** 4KiB Blocks (Frames).
* **Metadata Storage:**
  * Location: Physical `0x00020000` (128KB mark).
  * Structure: Bit array where `1 bit = 1 Page`.
  * Overhead: 1 bit per 4096 bytes (~0.003% of RAM).
* **Region Locking:**
  * `0x0000 - 0x1000`: BIOS Data Area & Null Pointer protection (Locked).
  * `0x1000 - 0x9FC00`: Kernel Code/Data & Stack (Locked).
  * `0x9FC00 - 0xFFFFF`: Video RAM & BIOS ROMs (Locked).
  * `0x100000+`: Extended Memory (Free for allocation).

### 1.2 Virtual Memory Manager (VMM)

* **Mechanism:** x86 Paging (CR3 Register).
* **Structure:** Two-Level Paging (Page Directory -> Page Table -> Physical Frame).
* **Current Mapping Strategy:**
  * **Identity Mapping:** Virtual `0x00000000` -> Physical `0x00000000` (First 4MB).
  * **Future Goal:** Higher-Half Kernel (Kernel mapped to `0xC0000000`).
* **Protection:**
  * Kernel Pages: `Supervisor | Read/Write`.
  * User Pages: `User | Read/Write` (Future).

### 1.3 Kernel Heap (Planned)

* **Goal:** Dynamic memory allocation (`kmalloc`/`kfree`).
* **Algorithm:** Linked List Allocator with Coalescing.
* **Structure:**

    ```c
    struct BlockHeader {
        size_t size;
        bool is_free;
        struct BlockHeader* next;
    };
    ```

* **Strategy:**
  * VMM allocates a large block of virtual pages for the heap.
  * Allocator manages chunks within that block.

---

## 2. ⚡ Interrupt & Exception Model

### 2.1 Interrupt Descriptor Table (IDT)

* **Vector Assignment:**
  * `0 - 31`: CPU Exceptions (Faults/Traps).
  * `32 - 47`: Hardware Interrupts (Remapped PIC).
  * `128 (0x80)`: System Calls (Future).
* **Handling Flow:**
    1. **CPU** triggers interrupt -> Jumps to IDT Entry.
    2. **ASM Stub** (`idt_asm.asm`): Pushes context (Registers) -> Calls C handler.
    3. **C Handler** (`isr_handler`): Dispatches to specific driver or error routine.
    4. **EOI**: Sends "End of Interrupt" to PIC for IRQs.
    5. **IRET**: Restores context and resumes execution.

### 2.2 Programmable Interrupt Controller (PIC)

* **Chip:** 8259A (Master/Slave cascading).
* **Remapping:**
  * Master Base: `0x20` (Vector 32).
  * Slave Base: `0x28` (Vector 40).
* **Masking:** All IRQs masked by default, explicitly unmasked by drivers.

---

## 3. 🔌 Hardware Abstraction Layer (HAL)

### 3.1 Keyboard Driver (Next Priority)

* **Input:** Port `0x60` (Data), Port `0x64` (Status).
* **Protocol:** PS/2 Controller.
* **Data Flow:**
    1. IRQ 1 Fired.
    2. Driver reads Raw Scancode (Set 1).
    3. **Translation Layer:** Converts Scancode -> ASCII char using Shift/Caps state machine.
    4. **Buffer:** Circular buffer (FIFO) stores keystrokes for the Shell to read.

### 3.2 Programmable Interval Timer (PIT)

* **Chip:** 8253/8254.
* **Configuration:** Channel 0, Mode 3 (Square Wave).
* **Frequency:** 100 Hz (10ms tick).
* **Usage:** System Uptime, Preemptive Scheduler quantum.

### 3.3 Storage (ATA/PIO) (Planned)

* **Mode:** PIO (Programmed I/O) initially, DMA later.
* **Bus:** Primary & Secondary IDE channels.
* **Addressing:** LBA28 (28-bit Logical Block Addressing).

---

## 4. 🔄 Process Management Architecture (Planned)

### 4.1 Process Control Block (PCB)

* **Concept:** A C structure representing a running program.
* **Data:**
  * `pid`: Process ID.
  * `esp`: Kernel Stack Pointer (Saved context).
  * `cr3`: Page Directory (Memory Context).
  * `state`: READY, RUNNING, BLOCKED.

### 4.2 Scheduler

* **Algorithm:** Round Robin (Simple Time Slicing).
* **Mechanism:**
    1. PIT Timer fires IRQ 0.
    2. Scheduler saves current task state (`pusha`).
    3. Scheduler picks next task from queue.
    4. Scheduler switches stacks (`esp`) and address space (`cr3`).
    5. Restores state (`popa`) and returns.

---

## 5. 💾 Filesystem Architecture (Planned)

### 5.1 Virtual File System (VFS)

* **Role:** Abstract interface for file operations.
* **Nodes:** `FS_Node` struct (Name, Size, Type, Read/Write Function Pointers).
* **Mount Points:** Root `/` mapped to a specific driver.

### 5.2 FAT32 Driver

* **Structure:**
  * Boot Sector (BPB).
  * File Allocation Table (FAT).
  * Data Region (Clusters).
* **Operation:**
  * Parse BPB to find Root Directory.
  * Follow Cluster Chains in FAT to read files.
