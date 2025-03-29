# Roadmap for Pyramid Bootloader

This document outlines the planned development path for the Pyramid Bootloader project.

## Legacy Bootloader Enhancements

- [x] Keyboard input handling
- [x] Basic disk I/O operations (sector reading)
- [x] Simple command-line interface
- [ ] Memory detection
- [ ] A20 line enabling
- [ ] Error handling and recovery mechanisms

## UEFI Bootloader Implementation

- [ ] Basic UEFI application structure
- [ ] Graphics Output Protocol (GOP) for display
- [ ] File system access using UEFI protocols
- [ ] Memory map retrieval
- [ ] UEFI boot entry management
- [ ] Configuration file parsing

## Hybrid Image Creation

- [ ] Build system for hybrid BIOS/UEFI images
- [ ] Boot sector handling both methods
- [ ] Boot method detection (BIOS vs UEFI)
- [ ] Shared code components
- [ ] Unified configuration system

## Technical Requirements

- [ ] Windows-compatible build process
- [ ] Cross-platform testing capabilities
- [ ] Modular design for maintainability
- [ ] Code documentation
- [ ] Automated testing framework
