# Pyramid Bootloader

A multi-stage bootloader for OS Pyramid with color support and a command-line interface.

## Features

- **Multi-stage bootloader**: Stage 1 fits in 512 bytes, Stage 2 provides more functionality
- **16-color text output**: Supports 16 foreground and background colors using BIOS INT 10h
- **Command-line interface**: Simple CLI for interacting with the bootloader
- **Memory detection**: Reports available system memory
- **A20 line control**: Multiple methods to enable the A20 address line
- **Protected mode support**: Ability to transition to 32-bit protected mode
- **Error handling**: Verifies BIOS operation success and provides error messages
- **Disk operations**: Reads sectors from disk using BIOS INT 13h

## Components

### Stage 1
- Initializes segment registers and stack
- Sets up video mode
- Loads Stage 2 from disk
- Transfers control to Stage 2

### Stage 2
- Provides color text output
- Implements a simple command-line interface
- Supports basic system information display
- Enables A20 address line for memory access above 1MB
- Transitions to 32-bit protected mode when requested
- Has commands: help, clear, info, a20, pmode, reboot

## Prerequisites

### Windows

1. Install [NASM](https://www.nasm.us/)
2. Install [QEMU](https://www.qemu.org/download/)
3. Install [mkisofs](https://sourceforge.net/projects/mkisofs-md5/) (optional, for ISO creation)

### Linux

```bash
sudo apt update
sudo apt install make nasm qemu-system genisoimage
```

## Building

### Using PowerShell (Windows)

```powershell
./build.ps1
```

The script will:
1. Build the bootloader binary
2. Create a 1.44MB floppy disk image
3. Create an ISO image (if mkisofs is available)

### Using Make (Linux)

```bash
make
```

## Running

### QEMU (Windows/Linux)

```bash
# Run from floppy image
qemu-system-i386 -fda build/main_floppy.img

# Run from ISO (if created)
qemu-system-i386 -cdrom build/main.iso
```

Note: Some QEMU versions don't support the `-display win32` parameter directly. If you encounter errors, try running without this parameter.

## Troubleshooting

If you encounter errors when running QEMU:

- **Display type errors**: If you see `Parameter 'type' does not accept value 'win32'`, remove the `-display win32` parameter
- **Missing disk image**: Ensure that you've built the bootloader successfully before running
- **Boot errors**: Check that the bootloader was written correctly to the first sectors of the disk image

## Command-Line Interface

The Stage 2 bootloader provides a simple command-line interface:

- `help` - Display available commands
- `clear` - Clear the screen
- `info` - Display system information
- `a20` - Enable A20 address line
- `pmode` - Enter 32-bit protected mode
- `reboot` - Reboot the system

## Usage Guide

To use the Pyramid Bootloader:

1. Run the bootloader in QEMU or on real hardware
2. When the command prompt (`>`) appears, you can type any available command
3. Use `help` to see the available commands and their descriptions
4. Use `info` to display system information
5. Use `a20` to enable the A20 line (required for accessing memory above 1MB)
6. Use `pmode` to transition to 32-bit protected mode
7. Use `clear` to clear the screen
8. Use `reboot` to restart the system

### Protected Mode Transition

The `pmode` command allows you to switch the CPU to 32-bit protected mode:

1. It automatically enables the A20 line if needed
2. Sets up a Global Descriptor Table (GDT) with code and data segments
3. Enables the PE (Protection Enable) bit in CR0
4. Performs a far jump to the 32-bit code segment
5. Initializes segment registers with proper selectors
6. Displays a welcome message using direct video memory access

**Note:** Once in protected mode, you cannot return to real mode without a system reset.

## Development Status

This is a work in progress with the following roadmap:

- [x] Stage 1 bootloader (fits in 512 bytes)
- [x] Stage 2 with command-line interface
- [x] Memory detection
- [x] A20 line enabling
- [x] Protected mode transition
- [ ] UEFI bootloader implementation

See `ROADMAP.md` for more detailed development plans.

## License

This project is open source. See the LICENSE file for details.

# Using the Pyramid Bootloader Command Line

The Pyramid Bootloader provides a simple command-line interface for interacting with the system. Here's how to use it effectively:

## Getting Started

When you boot with Pyramid Bootloader, after the initial loading messages, you'll be presented with a command prompt that looks like this:

```
Pyramid Bootloader - Stage 2
Version 0.4 - Multi-stage Bootloader
System ready

>
```

This prompt indicates that the bootloader is ready to accept commands.

## Available Commands

### help

Displays a list of all available commands and their descriptions.

```
> help
Available commands:
  help   - Display this help text
  clear  - Clear the screen
  info   - Display system information
  a20    - Enable A20 line
  pmode  - Enter 32-bit protected mode
  reboot - Reboot the system
```

### info

Displays system information, including available memory.

```
> info
Pyramid Bootloader System Information
---------------------------------
Boot drive: 80h (First hard disk)
System memory: 6.4 MB
```

### a20

Enables the A20 address line, which is necessary for accessing memory above 1MB and is a prerequisite for entering protected mode.

```
> a20
Enabling A20 line...
A20 line enabled successfully
```

If the A20 line is already enabled, it will show:

```
> a20
Enabling A20 line...
A20 line is already enabled
```

### pmode

Transitions the CPU to 32-bit protected mode. This command will:
1. Enable the A20 line if it's not already enabled
2. Set up the Global Descriptor Table (GDT)
3. Switch the CPU to protected mode
4. Initialize the 32-bit environment

```
> pmode
Preparing to enter protected mode...
A20 line enabled successfully
Setting up GDT...
```

After this command, the screen will clear and you'll see a protected mode welcome message. Note that once in protected mode, you cannot return to the bootloader command line without rebooting.

### clear

Clears the screen, keeping only the bootloader title at the top.

```
> clear
```

### reboot

Performs a system reboot.

```
> reboot
Rebooting system...
```

## Command Sequence Example

Here's a typical sequence for using the bootloader:

1. Boot the system with Pyramid Bootloader
2. Run `help` to see available commands
3. Run `info` to check system information
4. Run `a20` to enable the A20 line
5. Run `pmode` to enter protected mode

This sequence ensures that you've properly prepared the system before transitioning to protected mode.
