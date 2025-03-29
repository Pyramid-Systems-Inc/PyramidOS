# Roadmap for Pyramid Bootloader

This document outlines the planned development path for the Pyramid Bootloader project.

## Legacy Bootloader Enhancements

- [x] Keyboard input handling
- [x] Basic disk I/O operations (sector reading)
- [x] Simple command-line interface
- [x] Multi-stage bootloader architecture
- [x] Memory detection
- [x] A20 line enabling
  - Enable the A20 line via keyboard controller
  - Add fallback methods (BIOS, Fast A20, System Control Port)
  - Verify A20 line status
- [x] Protected mode transition
  - Implement GDT setup
  - Create minimal segment descriptors
  - Switch to protected mode
  - Initialize 32-bit environment
- [ ] Loading kernel from filesystem
  - Implement basic FAT16/32 filesystem driver
  - Locate kernel file on disk
  - Load kernel to appropriate memory address
- [ ] Graphics mode initialization
  - VESA BIOS Extensions support
  - Mode enumeration and selection
  - Framebuffer initialization
- [ ] Error handling and recovery mechanisms
  - Improved error codes and messages
  - Recovery options for common failures
  - Logging system for boot diagnostics

## UEFI Bootloader Implementation

- [ ] Basic UEFI application structure
  - Complete minimal EFI application framework
  - EFI system table initialization
  - Boot services access
- [ ] Graphics Output Protocol (GOP) for display
  - Query available graphics modes
  - Mode selection and initialization
  - Basic text output using GOP
- [ ] File system access using UEFI protocols
  - Simple File System Protocol implementation
  - File I/O operations
  - Directory traversal
- [ ] Memory map retrieval
  - Get system memory map
  - Identify usable memory regions
  - Reserve bootloader regions
- [ ] UEFI boot entry management
  - Create and modify boot entries
  - Persistent boot configuration
  - Boot menu implementation
- [ ] Configuration file parsing
  - INI-style configuration parser
  - Boot options configuration
  - Boot menu customization

## Hybrid Image Creation

- [x] Build system for legacy bootloader
- [ ] Build system for UEFI bootloader
  - Implement GNU-EFI compilation chain
  - Generate proper PE32+ executables
  - Ensure compatibility with common UEFI firmware
- [ ] Hybrid BIOS/UEFI images
  - Combined El Torito bootable ISO
  - Protective MBR with GPT support
  - UEFI System Partition integration
- [ ] Boot sector handling both methods
  - Detection of boot environment
  - Appropriate redirection based on boot method
  - Shared second-stage resources
- [ ] Boot method detection (BIOS vs UEFI)
  - Runtime detection of boot environment
  - Environment-specific initialization
  - Common boot path after initialization
- [ ] Shared code components
  - Common filesystem drivers
  - Shared configuration parsing
  - Unified kernel loading mechanism
- [ ] Unified configuration system
  - Common configuration format
  - Environment-specific extensions
  - UEFI variable storage support

## Technical Requirements

- [x] Windows-compatible build process (PowerShell)
- [ ] Cross-platform testing capabilities
  - Automated QEMU testing
  - Multiple UEFI firmware testing (OVMF, TianoCore)
  - Hardware compatibility testing
- [ ] Modular design for maintainability
  - Separate core components
  - Clear API boundaries
  - Well-defined interfaces
- [ ] Code documentation
  - Inline documentation
  - Developer guides
  - Architecture documentation
- [ ] Automated testing framework
  - Unit tests for core functions
  - Integration tests for boot sequence
  - UEFI compliance tests

## Version Goals

### v0.5.0 (Next Release)
- [x] Implement A20 line enabling
  - Keyboard controller method
  - FastA20 method
- [x] Add protected mode transition
  - Basic GDT setup
  - Initial protected mode entry
  - Basic 32-bit initialization
- [ ] Add basic memory management
  - Memory map generation
  - Simple memory allocation
  - Memory region tracking

### v0.6.0
- [ ] Add filesystem support (FAT16/FAT32)
  - Basic directory traversal
  - File reading capabilities
  - Boot configuration file support
- [ ] Implement basic kernel loading
  - ELF parser for 32-bit binaries
  - Memory mapping for kernel
  - Parameter passing to kernel
- [ ] Add configuration file support
  - Boot options configuration
  - Hardware detection settings
  - Boot menu customization

### v0.7.0
- [ ] Basic UEFI bootloader implementation
  - Minimal UEFI application
  - GOP text output
  - Simple boot services usage
- [ ] Graphics mode support
  - VESA BIOS Extensions for legacy
  - GOP for UEFI
  - Basic graphics primitives
- [ ] Enhanced command-line interface
  - More system commands
  - Improved user feedback
  - Better error handling
