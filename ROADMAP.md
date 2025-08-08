# PyramidOS Development Roadmap

This document outlines the high-level development plan for PyramidOS, a hobby OS inspired by Windows 95.

## Phase 1: The Kernel Foundation

The primary goal of this phase is to get a minimal 32-bit kernel running, loaded by our existing bootloader, and to establish a basic development feedback loop.

- **[ ] Kernel Entry & GDT:**
  - Establish a 32-bit C environment for the kernel.
  - Set up a final Global Descriptor Table (GDT) for kernel-mode and user-mode segments.
- **[ ] Interrupt Handling (IDT):**
  - Implement an Interrupt Descriptor Table (IDT).
  - Create handlers for basic CPU exceptions (e.g., divide by zero, general protection fault).
  - Implement a Programmable Interrupt Controller (PIC) driver to handle hardware interrupts.
- **[ ] Basic I/O and Drivers:**
  - Implement a basic PS/2 keyboard driver.
  - Implement a simple VGA text-mode driver for console output.
- **[ ] Physical Memory Management:**
  - Detect available memory (using information from the bootloader).
  - Implement a physical memory manager (frame allocator).
- **[ ] Virtual Memory Management (Paging):**
  - Implement a basic paging system (page directory, page tables).
  - Map the kernel into a higher-half of the address space.
  - Enable paging.
- **[ ] Build System Integration:**
  - Update the `Makefile` to compile the kernel into a binary format.
  - Update the bootloader to load the kernel binary.

## Phase 2: User Mode and Multitasking

This phase focuses on running the first user-mode process and enabling preemptive multitasking.

- **[ ] System Calls:**
  - Implement a basic system call interface.
- **[ ] Kernel Heap:**
  - Create a dynamic memory allocator for the kernel (`kmalloc`).
- **[ ] Preemptive Scheduler:**
  - Implement a Programmable Interval Timer (PIT) driver.
  - Create a basic round-robin scheduler.
- **[ ] Processes & Threads:**
  - Define structures for processes and threads.
  - Implement the `fork` and `exec` concepts (or equivalents).
  - Load and run a simple user-mode program.

## Phase 3: Filesystems and Storage

This phase focuses on reading and writing data from storage devices.

- **[ ] Storage Driver:**
  - Implement an IDE/PATA driver for disk access.
- **[ ] Virtual File System (VFS):**
  - Design and implement a VFS layer to abstract file operations.
- **[ ] FAT32 Filesystem:**
  - Implement a FAT32 filesystem driver.

## Phase 4: Graphical User Interface (GUI)

This phase aims to create a basic graphical environment.

- **[ ] Graphics Driver:**
  - Implement a VESA/VBE graphics driver for a linear framebuffer.
- **[ ] Windowing System:**
  - Implement basic window management (compositing, drawing).
- **[ ] GUI Toolkit:**
  - Create basic UI elements (buttons, text boxes).
- **[ ] Shell/Desktop:**
  - Develop a simple graphical shell.
