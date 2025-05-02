# Pyramid Bootloader

A multi-stage bootloader for OS Pyramid supporting both Legacy BIOS and UEFI environments.

## Features

- **Dual Boot Support**: Targets both Legacy BIOS and UEFI systems.
- **Legacy BIOS**:
    - Multi-stage bootloader (Stage 1 in 512 bytes, Stage 2 with more features).
    - 16-color text output using BIOS INT 10h.
    - Command-line interface (CLI) with commands for system interaction.
    - Memory detection.
    - A20 line control.
    - Protected mode transition.
    - FAT BPB parsing (`fsinfo` command).
    - Disk operations using BIOS INT 13h.
- **UEFI**:
    - Basic application structure using C and `gnu-efi`.
    - Prints startup message to UEFI console.
    - (Further functionality under development).

## Components

### Legacy BIOS

#### Stage 1 (`src/legacy/main.asm`)
- Fits in 512 bytes (boot sector).
- Initializes 16-bit real mode environment.
- Loads Stage 2 from disk.
- Transfers control to Stage 2.

#### Stage 2 (`src/legacy/main.asm`, loaded at `0x8000`)
- Provides a command-line interface.
- Supports color text output.
- Displays system information (`info`).
- Parses FAT BPB (`fsinfo`).
- Enables A20 line (`a20`).
- Transitions to 32-bit protected mode (`pmode`).
- Other commands: `help`, `clear`, `reboot`.

### UEFI (`src/uefi/uefi_main.c`)
- Standard UEFI application entry point (`efi_main`).
- Uses `gnu-efi` library for UEFI interactions.
- Currently prints a startup message.
- Built using Clang.

## Prerequisites

### Common
- [QEMU](https://www.qemu.org/download/) (for testing both BIOS and UEFI with OVMF)

### Legacy BIOS Build
- [NASM](https://www.nasm.us/)
- `mkisofs` or `xorriso` (optional, for ISO creation, e.g., `genisoimage` on Debian/Ubuntu)

### UEFI Build (using `Makefile`)
- [Clang](https://clang.llvm.org/) (C compiler)
- [LLD](https://lld.llvm.org/) (Linker, usually included with Clang/LLVM)
- [llvm-objcopy](https://llvm.org/docs/CommandGuide/llvm-objcopy.html) (usually included with Clang/LLVM)
- `make`

### Linux (Combined Example for Debian/Ubuntu)

```bash
sudo apt update
sudo apt install make nasm qemu-system-x86 ovmf genisoimage clang lld llvm
```

### Windows
- Install NASM.
- Install QEMU.
- Install Clang/LLVM (ensure `clang`, `lld`, `llvm-objcopy` are in PATH).
- Install `mkisofs` (optional).
- Use `make` via MSYS2/MinGW or WSL, or use the PowerShell script for legacy-only builds.

## Building

### Using PowerShell (Windows - Legacy BIOS Only)

```powershell
./build.ps1
```
This script builds only the legacy BIOS bootloader (`main_floppy.img`, `main.iso`).

### Using Make (Linux/MSYS2/WSL - Legacy & UEFI)

```bash
# Clean previous builds (optional)
make clean

# Build both legacy and UEFI targets
make all
# Or build specific targets
# make legacy
# make uefi
```
This uses `nasm` for the legacy target and `clang` for the UEFI target (`build/bootx64.efi`).

## Running

### QEMU (Legacy BIOS)

```bash
# Run from floppy image
qemu-system-i386 -fda build/main_floppy.img

# Run from ISO (if created)
qemu-system-i386 -cdrom build/main.iso
```

### QEMU (UEFI)

You need OVMF firmware files for UEFI emulation. The path might vary based on your installation.

```bash
# Example using OVMF firmware (adjust paths as needed)
qemu-system-x86_64 \
  -bios /usr/share/ovmf/OVMF.fd \
  -hda fat:rw:build
```
This command creates a virtual FAT drive containing the `build` directory contents. You can then navigate to `bootx64.efi` in the UEFI shell and execute it. Alternatively, copy `build/bootx64.efi` to `EFI/BOOT/BOOTX64.EFI` on a FAT-formatted image/drive recognized by QEMU.

## Troubleshooting

- **QEMU Display Errors**: If you see `Parameter 'type' does not accept value 'win32'`, remove the `-display win32` parameter (often used in older guides).
- **Missing Disk Image**: Ensure the build completed successfully before running.
- **UEFI Boot Issues**: Verify OVMF path. Ensure `bootx64.efi` is correctly placed for UEFI firmware to find it (e.g., `EFI/BOOT/BOOTX64.EFI` on a FAT partition). Check `make uefi` build logs for errors.

## Command-Line Interface (Legacy BIOS Stage 2)

The Stage 2 bootloader provides a simple command-line interface:

- `help` - Display available commands.
- `clear` - Clear the screen.
- `info` - Display system information (boot drive, memory).
- `fsinfo` - Display parsed FAT BPB information from the boot sector.
- `a20` - Enable A20 address line.
- `pmode` - Enter 32-bit protected mode.
- `reboot` - Reboot the system.

## Usage Guide (Legacy BIOS)

1. Run the legacy bootloader in QEMU or on real hardware.
2. When the command prompt (`>`) appears, type commands.
3. Use `help` to see commands.
4. Use `info` or `fsinfo` to view system/filesystem details.
5. Use `a20` to enable the A20 line (required for `pmode`).
6. Use `pmode` to transition to 32-bit protected mode.
7. Use `clear` to clear the screen.
8. Use `reboot` to restart the system.

### Protected Mode Transition (`pmode`)

The `pmode` command switches the CPU to 32-bit protected mode:
1. Enables the A20 line if needed.
2. Sets up a Global Descriptor Table (GDT).
3. Enables the PE (Protection Enable) bit in CR0.
4. Jumps to 32-bit code.
5. Initializes segment registers.
6. Displays a welcome message using direct video memory access.

**Note:** Once in protected mode, you cannot return to the bootloader CLI without a system reset.

## Development Status

This is a work in progress aiming for both Legacy BIOS and UEFI support.

- [x] Legacy Stage 1 bootloader (fits in 512 bytes)
- [x] Legacy Stage 2 with command-line interface
- [x] Legacy Memory detection
- [x] Legacy A20 line enabling
- [x] Legacy Protected mode transition
- [x] Legacy FAT BPB parsing (`fsinfo` command)
- [x] Basic UEFI application structure (`src/uefi/uefi_main.c`)
- [x] UEFI build system using Clang (`Makefile`)
- [ ] UEFI Graphics Output Protocol (GOP) support
- [ ] UEFI Filesystem access
- [ ] UEFI Memory map retrieval
- [ ] Kernel loading (both BIOS and UEFI)

See `ROADMAP.md` for more detailed development plans.

## License

This project is open source. See the LICENSE file for details.

# Using the Pyramid Bootloader Command Line (Legacy BIOS)

The Pyramid Bootloader (when booted in Legacy BIOS mode) provides a simple command-line interface in its second stage for interacting with the system. Here's how to use it effectively:

## Getting Started

When you boot with Pyramid Bootloader in Legacy mode, after the initial loading messages, you'll be presented with a command prompt:

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
  fsinfo - Show FAT filesystem info
  a20    - Enable A20 line
  pmode  - Enter 32-bit protected mode
  reboot - Reboot the system
```

### info

Displays system information, including boot drive and available memory.

```
> info
Pyramid Bootloader System Information
---------------------------------
Boot drive: 0x80
System memory: 6.4 MB
```

### fsinfo

Parses the FAT BIOS Parameter Block (BPB) from the boot sector (Sector 0) of the boot drive and displays key filesystem parameters.

```
> fsinfo
Parsing FAT BPB...
FAT BPB parsed successfully.
  Bytes/Sector: 0x0200
  Sectors/Cluster: 0x01
  Reserved Sectors: 0x0001
  Num FATs: 0x02
  Root Entries: 0x00E0
  Sectors/FAT: 0x0009
```
*(Note: Output values depend on the formatting of the boot disk)*

### a20

Enables the A20 address line, necessary for accessing memory above 1MB and required for protected mode.

```
> a20
Enabling A20 line...
A20 line enabled successfully
```

If already enabled:
```
> a20
Enabling A20 line...
A20 line is already enabled
```

### pmode

Transitions the CPU to 32-bit protected mode. This command will:
1. Enable the A20 line if needed.
2. Set up the Global Descriptor Table (GDT).
3. Switch the CPU to protected mode.
4. Initialize the 32-bit environment.

```
> pmode
Preparing to enter protected mode...
A20 line enabled successfully
Setting up GDT...
Setting up IDT...
```
*(Screen clears, protected mode message appears)*

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

## Command Sequence Example (Legacy BIOS)

Here's a typical sequence for using the bootloader:

1. Boot the system with Pyramid Bootloader (Legacy).
2. Run `help` to see available commands.
3. Run `info` and `fsinfo` to check system/filesystem details.
4. Run `a20` to enable the A20 line.
5. Run `pmode` to enter protected mode (if desired).

This sequence ensures proper system preparation before transitioning modes.
