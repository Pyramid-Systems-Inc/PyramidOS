# Roadmap for Pyramid Bootloader

This document outlines the planned development path for the Pyramid Bootloader project.

# Roadmap for Pyramid Bootloader

This document outlines the planned development path for the Pyramid Bootloader project, aiming for equal support for Legacy BIOS and UEFI environments.

## Legacy BIOS Bootloader

### Completed
- [x] Keyboard input handling
- [x] Basic disk I/O operations (sector reading)
- [x] Simple command-line interface (`help`, `clear`, `info`, `a20`, `pmode`, `reboot`, `fsinfo`)
- [x] Multi-stage bootloader architecture
- [x] Memory detection (`info` command)
- [x] A20 line enabling (`a20` command)
- [x] Protected mode transition (`pmode` command)
- [x] Boot drive detection and preservation
- [x] User interface enhancements (boot prompt, countdown)
- [x] Error handling enhancements (KBC timeout, A20 fallbacks, basic IDT)
- [x] FAT BPB parsing (`fsinfo` command)

### Planned
- [ ] Loading kernel from filesystem
  - Implement basic FAT16/FAT32 filesystem driver (read-only)
  - Locate kernel file on disk (e.g., via config file or fixed path)
  - Load kernel to appropriate memory address.
- [ ] Graphics mode initialization (optional)
  - VESA BIOS Extensions (VBE) support.
  - Mode enumeration and selection.
  - Framebuffer initialization.
- [ ] Error handling and recovery mechanisms
  - Improved error codes and messages.
  - Recovery options for common failures.
  - Logging system for boot diagnostics (e.g., serial port output).
- [ ] Refactor Stage 2 to C
  - Use Open Watcom C compiler for 16-bit real mode.
  - Separate Stage 1 (assembly) from Stage 2 (C + assembly helpers).
  - Implement CLI, commands, and hardware interactions in C where possible.

## UEFI Bootloader

### Completed
- [x] Basic UEFI application structure (`efi_main` entry point).
- [x] Build system using Clang and `gnu-efi` (`Makefile`).
- [x] Basic console output (`Print` function).

### Planned
- [ ] Graphics Output Protocol (GOP) for display
  - Query available graphics modes.
  - Mode selection and initialization.
  - Basic text output using GOP framebuffer.
- [ ] File system access using UEFI protocols
  - Simple File System Protocol implementation.
  - File I/O operations (reading files).
  - Directory traversal.
- [ ] Memory map retrieval
  - Get system memory map using `GetMemoryMap()`.
  - Identify usable memory regions for the kernel.
  - Exit boot services correctly.
- [ ] Loading kernel from filesystem
  - Locate kernel file on disk (e.g., via config file or fixed path).
  - Load kernel (e.g., PE or ELF format) to appropriate memory address.
- [ ] Configuration file parsing
  - Simple configuration file format (e.g., INI-style).
  - Read boot options (kernel path, parameters).
- [ ] UEFI boot entry management (optional)
  - Create and modify boot entries.
  - Persistent boot configuration.
- [ ] Boot menu implementation (optional)

## Common / Build System / Integration

### Completed
- [x] Build system for legacy bootloader (`Makefile`, `build.ps1`).
- [x] Build system for UEFI bootloader (`Makefile` using Clang).
- [x] Windows-compatible build process for legacy (`build.ps1`).

### Planned
- [ ] Hybrid BIOS/UEFI images
  - Combined El Torito bootable ISO.
  - Protective MBR with GPT support.
  - UEFI System Partition (ESP) integration.
- [ ] Boot method detection (BIOS vs UEFI)
  - Runtime detection of boot environment (if using a shared stage/payload).
  - Environment-specific initialization.
- [ ] Shared code components (Potential, requires C environment for legacy or careful linking)
  - Common filesystem drivers (e.g., FAT).
  - Shared configuration parsing logic.
  - Unified kernel loading mechanism (parsing kernel format).
- [ ] Unified configuration system
  - Common configuration file format usable by both modes.
- [ ] Cross-platform testing capabilities
  - Automated QEMU testing (BIOS and UEFI via OVMF).
  - Testing on different UEFI firmware versions/implementations.
- [ ] Modular design for maintainability
  - Separate core components (BIOS stage 1/2, UEFI app, shared libs).
  - Clear API boundaries.
- [ ] Code documentation
  - Inline documentation.
  - Developer guides.
  - Architecture overview.
- [ ] Automated testing framework (optional)
  - Unit tests for C components (e.g., filesystem, config parser).
  - Integration tests for boot sequences.

## Version Goals (Example - Adjust as needed)

### v0.6.x (Current Focus - Legacy)
- [x] FAT BPB parsing (`fsinfo`).
- [ ] Basic FAT16/FAT32 read support.
- [ ] Load kernel file (e.g., simple binary format) from FAT partition.
- [ ] Pass basic boot information to loaded kernel.

### v0.7.x (Focus - UEFI Basics)
- [ ] GOP initialization and text output.
- [ ] Simple File System Protocol usage (find/read file).
- [ ] Get Memory Map and exit boot services.
- [ ] Load kernel file (e.g., simple binary or PE format) from FAT partition (ESP).
- [ ] Pass basic boot information (memory map, framebuffer) to loaded kernel.

### v0.8.x (Focus - Integration & Features)
- [ ] Hybrid boot image creation (ISO).
- [ ] Shared configuration file parsing.
- [ ] Kernel loading (e.g., ELF format) for both modes.
- [ ] Basic boot menu (optional).
- [ ] Enhanced error handling and diagnostics.

### Future Goals
- [ ] More filesystem support (Ext2, etc.).
- [ ] Network booting (PXE for legacy, UEFI protocols).
- [ ] Security features (Secure Boot support).
- [ ] More sophisticated boot menu / UI.
