# PyramidOS (Working Title)

Welcome to the PyramidOS project! This is an ambitious endeavor to build a complete, 32-bit operating system from scratch, with features and a user experience inspired by classic systems like Windows 95. The project encompasses a custom bootloader, kernel, standard C library, drivers, and a graphical user interface (GUI).

## Project Goal

To create a monolithic kernel-based operating system for the x86 architecture, featuring:

- Preemptive multitasking
- A virtual memory system
- A hierarchical file system (FAT32)
- A modular driver architecture
- A graphical user interface with a windowing system, basic widgets, and a shell.

## Current State

The project has recently pivoted from being a standalone bootloader. The initial structure for the operating system has been established.

- **/boot**: Contains the bootloader code (both Legacy BIOS and UEFI) responsible for loading the PyramidOS kernel.
- **/kernel**: The heart of the OS. Will contain core components like the scheduler, memory manager, and system call interface.
- **/drivers**: Will house device drivers (keyboard, mouse, disk, etc.).
- **/libc**: A custom implementation of the standard C library.
- **/user**: User-mode applications, including the shell and other utilities.
- **/docs**: Project documentation, including this roadmap and archived bootloader plans.

## Development Roadmap

See `ROADMAP.md` for the detailed, phased development plan.

## Building and Running

A top-level `Makefile` orchestrates the build process.

```bash
# To build the bootloader (for now)
make boot

# To build the entire OS (eventually)
make all

# To clean all build artifacts
make clean
