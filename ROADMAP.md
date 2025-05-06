# Roadmap for Pyramid Bootloader (Revised)

This document outlines the planned development path for the Pyramid Bootloader project, focusing on building separate, robust bootloaders for Legacy BIOS and UEFI environments before integrating shared components.

## Overall Goal
Create distinct, functional Legacy BIOS and UEFI bootloaders capable of loading a simple kernel payload. Maximize code sharing through common libraries in later phases.

## Phase 1: Minimal Functional Bootloaders (Separate Implementations)

### Legacy BIOS (Target: Load simple payload from fixed location)
- [ ] **Stage 1 (Assembly - `src/legacy/stage1.asm`)**
    - Basic 16-bit setup.
    - Load Stage 2 from subsequent disk sectors.
    - Jump to Stage 2.
- [ ] **Stage 2 (C - `src/legacy/stage2.c` + Assembly Helpers)**
    - Minimal assembly entry (`src/legacy/entry.asm`) to set up C environment.
    - Basic C runtime initialization.
    - Print startup message via BIOS TTY.
    - Load a simple kernel payload (e.g., binary blob) from a fixed LBA sector address using BIOS INT 13h Extensions.
    - Jump to the loaded payload.
- [ ] **Build System (Makefile)**
    - Compile/Assemble Stage 1 & 2.
    - Create bootable floppy/disk image.

### UEFI (Target: Load simple payload from ESP)
- [ ] **UEFI Application (C - `src/uefi/main.c`)**
    - Standard `efi_main` entry point.
    - Initialize `gnu-efi` library.
    - Print startup message using UEFI console services.
    - Use Simple File System Protocol to locate and read a kernel payload (e.g., binary blob) from a fixed path on the ESP (e.g., `/kernel.bin`).
    - Allocate memory for the payload.
    - Load the payload into memory.
    - Jump to the loaded payload.
- [ ] **Build System (Makefile)**
    - Compile UEFI application using Clang/LLD and `gnu-efi`.
    - Produce `bootx64.efi` (or other target architecture).

## Phase 2: Core OS Loading Features (Separate Implementations)

### Legacy BIOS
- [ ] Implement basic FAT16/FAT32 read-only driver (C).
- [ ] Load kernel from a specified file path (e.g., `/boot/kernel.elf`).
- [ ] Parse kernel format (e.g., ELF).
- [ ] Retrieve memory map (E820).
- [ ] Enter 32-bit Protected Mode (or 64-bit Long Mode).
- [ ] Prepare and pass Boot Information structure to kernel.

### UEFI
- [ ] Enhance filesystem interaction (error handling, directory navigation).
- [ ] Parse kernel format (e.g., ELF).
- [ ] Retrieve final memory map (`GetMemoryMap()`).
- [ ] Set up graphics mode using GOP (optional, basic framebuffer info).
- [ ] Exit Boot Services.
- [ ] Prepare and pass Boot Information structure to kernel.

## Phase 3: Code Sharing & Integration

- [ ] Refactor FAT driver into a shared library.
- [ ] Refactor ELF loader (or other kernel format parser) into a shared library.
- [ ] Develop shared library for configuration file parsing.
- [ ] Define a common Boot Information structure format.
- [ ] Create hybrid boot media (ISO/Disk Image) using El Torito and Hybrid MBR/GPT.
- [ ] Implement shared utility functions (string manipulation, memory management helpers).

## Phase 4: Advanced Features & Polish

- [ ] Implement Boot Menu (Text-based or Graphical).
- [ ] Enhanced error handling and reporting (both environments).
- [ ] ACPI table parsing (shared library).
- [ ] Support for other filesystems (optional).
- [ ] Security considerations (e.g., Secure Boot for UEFI).
- [ ] Code documentation and cleanup.
