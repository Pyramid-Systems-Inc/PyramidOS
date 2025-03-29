# Pyramid Bootloader

A legacy bootloader for OS Pyramid with color support in 16-bit real mode.

## About

This is the legacy bootloader for OS Pyramid. It demonstrates text output with color support in 16-bit real mode using BIOS video services (INT 10h).

## Features

- 16-bit real mode operation
- Color text output using BIOS video services
- Simple string display functionality
- Error handling for BIOS operations
- Keyboard input handling
- Basic disk I/O operations (sector reading)

## Setup

### Prerequisites

Install the necessary requirements:

#### Linux

```bash
sudo apt update
sudo apt install make nasm
sudo apt install qemu-system
sudo apt-get install genisoimage
```

## Building

### To Make an .Img File

```
Make
```

### To make an .Iso File

```
make build/main.iso
```

## Runing On Vitrual Machine

### Linux

- Boots as floppy disk

```
qemu-system-i386 -fda build/floppy.img
```

### Windows

Use The Oracle VirtualBox, VmWare or any simller program.
