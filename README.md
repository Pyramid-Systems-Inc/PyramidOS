# Pyramid Bootloader

A legacy bootloader for OS Pyramid with color support in 16-bit real mode.

## About

This bootloader demonstrates text output with color support in 16-bit real mode using BIOS video services (INT 10h). It provides:

- 16-color text output (foreground and background)
- BIOS error checking
- Basic disk I/O operations
- Keyboard input handling

## Features

- **16-bit real mode operation**: Compatible with legacy BIOS systems
- **Color text output**: Supports 16 foreground and background colors using BIOS INT 10h
- **String display**: Prints formatted strings with color attributes
- **Error handling**: Verifies BIOS operation success via carry flag
- **Keyboard input**: Basic keyboard input handling via BIOS
- **Disk operations**: Reads sectors from disk using BIOS INT 13h

## Prerequisites

### Linux

```bash
sudo apt update
sudo apt install make nasm qemu-system genisoimage
```

### Windows

1. Install [NASM](https://www.nasm.us/)
2. Install [QEMU](https://www.qemu.org/download/)
3. Install [mkisofs](https://sourceforge.net/projects/mkisofs-md5/) or use WSL

## Building

### Build Targets

- `make` or `make build/main.bin`: Creates raw binary
- `make build/main_floppy.img`: Creates 1.44MB floppy image
- `make build/main.iso`: Creates bootable ISO image

### Clean

```bash
make clean  # Removes build artifacts
```

## Running

### QEMU (Linux/Windows)

```bash
qemu-system-i386 -fda build/main_floppy.img  # Floppy mode
qemu-system-i386 -cdrom build/main.iso      # CD-ROM mode
```

### Other Virtual Machines

- **VirtualBox**: Create VM with floppy or CD-ROM pointing to image
- **VMware**: Similar to VirtualBox setup

## Development

The bootloader is written in NASM assembly (`src/main.asm`) and supports:

- 16 color attributes (foreground + background)
- BIOS error checking
- Sector reading (LBA addressing)

See `CHANGELOG.md` for version history and `ROADMAP.md` for future plans.
