# Pyramid Bootloader (Under Development)

A multi-stage bootloader for OS Pyramid supporting both Legacy BIOS and UEFI environments. This project is currently undergoing a refactor, starting with minimal implementations for each environment.

## Goal

To create separate, functional bootloaders for Legacy BIOS and UEFI systems, capable of eventually loading a kernel payload (like OS Pyramid). Development follows the plan outlined in `ROADMAP.md`.

## Current Status (Phase 1 In Progress)

- **Separate Implementations:** Building distinct bootloaders for BIOS and UEFI.
- **Legacy BIOS:**
  - `src/legacy/stage1.asm`: 512B MBR; probes INT 13h extensions and loads Stage2 via LBA (fallback CHS).
  - `src/legacy/stage2.asm`: Robust loader that:
    - Reads a 512B kernel header (magic "PyrImg01", size, load/entry addresses)
    - Verifies a checksum32 of the kernel data before transfer
    - Loads `kernel.img` via LBA with retries and CHS fallback
    - Honors 64 KiB ES:BX boundary constraints
    - Enables A20 (Fast A20 + KBC fallback)
    - Enters protected mode and jumps to kernel
  - Writes a `BootInfo` structure at 0x00005000 (boot drive, kernel load seg:off, size) and collects an E820 memory map (table at 0x00005020).
- **UEFI:**
  - `src/uefi/main.c`: EDK2 skeleton that prints a startup message (payload loading TBD).
- **Next Steps:** Implement kernel loading from ESP for UEFI (see `ROADMAP.md`).

## Prerequisites

The tools required for building and testing remain the same:

### Common
- [QEMU](https://www.qemu.org/download/) (for testing both BIOS and UEFI with OVMF)

### Legacy BIOS Build
- [NASM](https://www.nasm.us/) (Assembler)
- A C compiler suitable for 16-bit real mode (e.g., Open Watcom, GCC with specific targets - **Note:** Build system needs configuration for this).
- Linker compatible with the chosen C compiler and NASM output (e.g., `wlink` for Watcom, `ld` for GCC).
- `mkisofs` or `xorriso` (optional, for ISO creation).

### UEFI Build
- [Clang](https://clang.llvm.org/) (C compiler)
- [LLD](https://lld.llvm.org/) (Linker, usually included with Clang/LLVM)
- [llvm-objcopy](https://llvm.org/docs/CommandGuide/llvm-objcopy.html) (usually included with Clang/LLVM)
- `make` (Build utility)
- `gnu-efi` library (Source included in `gnu-efi/` directory, needs building as part of the process).

### Environment Setup Guidance (See Below)

## Building

Use the top-level Makefile from the repo root.

```bash
# Build kernel image (with header) and legacy BIOS boot image
make clean && make

# Run (Legacy BIOS)
make -C boot run

# Inspect kernel header
make -C boot header
```

## Running (Example QEMU Commands)

### QEMU (Legacy BIOS)

```bash
qemu-system-i386 -fda build/pyramidos_legacy.img
```

### QEMU (UEFI - Once build produces bootx64.efi)

You need OVMF firmware files.

```bash
# Example using OVMF firmware (adjust paths as needed)
# 1. Create a FAT directory for QEMU
mkdir -p build_uefi/EFI/BOOT
cp build/bootx64.efi build_uefi/EFI/BOOT/BOOTX64.EFI

# 2. Run QEMU with the directory as a drive
qemu-system-x86_64 \
  -bios /path/to/OVMF.fd \
  -hda fat:rw:build_uefi
```
*(You might need to navigate the UEFI shell to run the application if it's not placed at the default path `EFI/BOOT/BOOTX64.EFI`)*

## Development Roadmap

See `ROADMAP.md` for the detailed, phased development plan.

## License

This project is open source. (Assuming MIT or similar - add LICENSE file later).

---

# Environment Setup Guide

Setting up the correct environment is crucial for building both the Legacy BIOS and UEFI versions of the bootloader.

**1. Common Tool: QEMU**

You need QEMU for testing. It allows emulating both legacy PC hardware and UEFI firmware (using OVMF).

*   **Linux (Debian/Ubuntu):**
    ```bash
    sudo apt update
    sudo apt install qemu-system-x86 ovmf
    ```
*   **Windows:** Download from the [QEMU website](https://www.qemu.org/download/). Ensure it's added to your system's PATH. You might need to find OVMF firmware files separately or use a package manager like Chocolatey (`choco install qemu ovmf`).
*   **macOS:** Use Homebrew: `brew install qemu` (OVMF might be included or require separate installation).

**2. Legacy BIOS Tools**

*   **NASM (Assembler):**
    *   **Linux:** `sudo apt install nasm`
    *   **Windows:** Download from the [NASM website](https://www.nasm.us/). Add to PATH.
    *   **macOS:** `brew install nasm`
*   **16-bit C Compiler/Linker:** This is the trickiest part for the legacy target.
    *   **Option A: GCC Cross-Compiler (Recommended for Linux/macOS/WSL):** You need a GCC toolchain targeting `i386-elf` or similar, configured for 16-bit code generation. Building such a toolchain can be complex. Pre-built toolchains might be available. *This project's Makefile will need to be configured to use this.*
    *   **Option B: Open Watcom v2 (Works on Windows/Linux):** A C/C++ compiler that explicitly supports 16-bit DOS/real-mode targets. Download from [Open Watcom v2 GitHub Releases](https://github.com/open-watcom/open-watcom-v2/releases). Add its `bin` directory to your PATH. *The Makefile would need significant changes to use Watcom's compiler (`wcc`) and linker (`wlink`).*
    *   **Option C: DJGPP (via DOS emulator):** Less common now, involves running a DOS compiler within DOSBox or similar. Not recommended for modern development.
    *   **Current Plan:** The `Makefile` will likely need to be adapted based on the chosen C compiler for the 16-bit target. Let's assume a GCC cross-compiler (`i686-elf-gcc`, `i686-elf-ld`) for now, but this might need adjustment.
*   **Build Utility (`make`):**
    *   **Linux/macOS:** Usually pre-installed or available via package manager (`sudo apt install build-essential` or Xcode Command Line Tools).
    *   **Windows:** Install via MSYS2, Chocolatey (`choco install make`), or use within WSL.

**3. UEFI Tools**

*   **Clang/LLVM Toolchain:** Required for compiling C code for UEFI using `gnu-efi`.
    *   **Linux:** `sudo apt install clang lld llvm`
    *   **Windows:** Install LLVM from the [LLVM website](https://releases.llvm.org/). Ensure `clang`, `lld`, and `llvm-objcopy` are in your PATH.
    *   **macOS:** Install via Xcode Command Line Tools or Homebrew (`brew install llvm`). You might need to explicitly add the Homebrew LLVM tools to your PATH.
*   **`make`:** (See Legacy section).
*   **`gnu-efi`:** The source is included in the repository. The `Makefile` should handle building it as needed.

**Summary for Windows (using MSYS2/MinGW or WSL):**

1.  Install QEMU (+ OVMF).
2.  Install NASM.
3.  Install Clang/LLVM.
4.  Install `make`.
5.  Decide on and install a 16-bit C compiler solution (GCC cross-compiler within WSL/MSYS2 is often preferred if feasible).
6.  Ensure all necessary tools are in your PATH within the chosen environment (WSL, MSYS2, or native PowerShell/CMD if tools support it).

**Next Steps:**

Once the tools are installed, the next step would be to update the `Makefile` to correctly build the new source files using these tools.
