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

- **/boot**: Bootloader for both Legacy BIOS and UEFI.
  - Legacy BIOS path is implemented end-to-end: Stage1 → Stage2 → A20 → Protected Mode → jump to kernel.
  - Stage2 loads a kernel image using LBA with retries and CHS fallback, handles 64 KiB boundaries, and validates a kernel header.
- **/kernel**: 32‑bit freestanding kernel that initializes VGA text, IDT/PIC, PIT (100 Hz), and keyboard; includes a tiny text shell.
- **/drivers**: Will house device drivers (keyboard, mouse, disk, etc.).
- **/libc**: A custom implementation of the standard C library.
- **/user**: User-mode applications, including the shell and other utilities.
- **/docs**: Project documentation, including this roadmap and archived bootloader plans.

## Development Roadmap

See `ROADMAP.md` for the detailed, phased development plan.

## Building and Running

A top-level `Makefile` orchestrates the build process.

```bash
# Build kernel image (with 512-byte header) and legacy BIOS boot image
make clean && make

# Run in QEMU (Legacy BIOS)
make -C boot run

# Inspect kernel header fields (magic/size/addresses)
make -C boot header

# Clean all build artifacts
make clean
```

### Kernel Image Header

The kernel image `build/kernel.img` contains:
- 512‑byte header with fields:
  - magic: "PyrImg01"
  - size: 32‑bit little‑endian size of `kernel.bin`
  - load_physical_address: 32‑bit physical load address (default 0x00010000)
  - entry_physical_address: 32‑bit physical entry address (default 0x00010000)
  - checksum32_bytes: sum of all bytes in `kernel.bin` (mod 2^32)
- followed by the raw `kernel.bin`.

Stage2 reads and validates the header, computes the number of sectors to read, loads the kernel to the specified load address, and then enters protected mode and jumps to the entry.

### Boot Information (BootInfo)

Before switching to protected mode, the bootloader writes a small `BootInfo` structure at physical 0x00005000 containing:
- magic "BOOT", version 0x0001
- boot drive number
- kernel load segment:offset and kernel size (bytes)
- E820 memory map: entry count at 0x00005014 and table at 0x00005020 (24‑byte entries)

The kernel reads this to display load address and can be extended to use E820 data.
