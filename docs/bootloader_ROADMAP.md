# Roadmap for Pyramid Bootloader (Revised)

This document outlines the planned development path for the Pyramid Bootloader project, focusing on building separate, robust bootloaders for Legacy BIOS and UEFI environments before integrating shared components.

## Overall Goal

Create distinct, functional Legacy BIOS and UEFI bootloaders capable of loading a simple kernel payload. Maximize code sharing through common libraries in later phases.

## Phase 1: Minimal Functional Bootloaders (Separate Implementations)

### Legacy BIOS (Target: Load simple payload from fixed location)

- [X] **Stage 1 (Assembly - `src/legacy/stage1.asm`)**
  - [X] Basic 16-bit setup (segments, stack).
  - [X] Load Stage 2 from subsequent disk sectors (using BIOS INT 13h, AH=02h).
  - [X] Jump to Stage 2.
  - [X] **Store boot drive (`DL`)**: Ensure `DL` (boot drive number) is saved by Stage 1 to a known memory location (e.g., `0x7C00 - 1` or a dedicated variable in Stage 1's data area) or passed to Stage 2 in a register that `entry.asm` can retrieve and pass to C. *(Self-correction: `stage1.asm` already saves to `[boot_drive]`, but `stage2.c` doesn't use it yet. This needs to be bridged.)*

- [X] **Stage 2 (C - `src/legacy/stage2.c` + Assembly Helpers - `src/legacy/entry.asm`)**
  - [X] Minimal assembly entry (`src/legacy/entry.asm`) to set up C environment (segments `DS, ES, SS`, stack pointer `SP`).
  - [X] Basic C runtime initialization (handled by `entry.asm` and compiler).
  - [X] Print startup message via BIOS TTY (using `bios_print_char_asm` helper).

- [ ] **Implement Payload Loading in Stage 2 (`src/legacy/stage2.c` and new ASM helper)**
  - **1. Define Payload Parameters (`src/legacy/stage2.c`):**
    - Define constants for:
      - `PAYLOAD_LBA_START`: The Logical Block Address where the payload begins on disk (e.g., sector 60, ensuring it's after Stage 1 & 2).
      - `PAYLOAD_SECTOR_COUNT`: Number of sectors the payload occupies (e.g., 1 for a very simple test).
      - `PAYLOAD_LOAD_ADDRESS_SEGMENT`: Segment where the payload will be loaded (e.g., `0x1000`).
      - `PAYLOAD_LOAD_ADDRESS_OFFSET`: Offset where the payload will be loaded (e.g., `0x0000`, so linear address `0x10000`).
  - **2. Access Boot Drive Information (`src/legacy/stage2.c` & `src/legacy/entry.asm`):**
    - Modify `src/legacy/entry.asm` to retrieve the boot drive number saved by Stage 1.
    - Pass this boot drive number as an argument to `stage2_main`.
    - Update `stage2_main` in `src/legacy/stage2.c` to accept the boot drive number.
  - **3. Create Disk Address Packet (DAP) Structure (`src/legacy/stage2.c`):**
    - Define a C `struct` representing the DAP required by BIOS INT 13h Extensions (AH=42h):

          ```c
          typedef struct {
              unsigned char packet_size;       // Size of this packet (16 bytes for basic LBA)
              unsigned char reserved;          // Always zero
              unsigned short num_blocks;       // Number of sectors to transfer
              unsigned short buffer_offset;    // Offset of transfer buffer
              unsigned short buffer_segment;   // Segment of transfer buffer
              unsigned long long lba_start;    // Starting LBA (64-bit)
          } DiskAddressPacket;
          ```

  - **4. Populate DAP Instance (`src/legacy/stage2.c`):**
    - In `stage2_main`, create an instance of `DiskAddressPacket`.
    - Fill it with the defined constants: `packet_size = 16`, `reserved = 0`, `num_blocks = PAYLOAD_SECTOR_COUNT`, `buffer_offset = PAYLOAD_LOAD_ADDRESS_OFFSET`, `buffer_segment = PAYLOAD_LOAD_ADDRESS_SEGMENT`, `lba_start = PAYLOAD_LBA_START`.
  - **5. Create ASM Helper for INT 13h, AH=42h (Extended Read) (new `.asm` file or extend `src/legacy/entry.asm`):**
    - Create a new assembly function, e.g., `bios_read_sectors_lba_asm(DiskAddressPacket* dap, unsigned char drive_num)`.
    - This function will:
      - Save necessary registers.
      - Set `AH = 0x42`.
      - Set `DL = drive_num` (passed as argument).
      - Set `DS:SI` to point to the `dap` (passed as argument).
      - Execute `INT 0x13`.
      - Check the Carry Flag (CF) for errors.
      - Return a status (e.g., 0 for success, 1 for error).
      - Restore registers.
    - Declare this function as `extern` in `src/legacy/stage2.c`.
  - **6. Call LBA Read Helper from C (`src/legacy/stage2.c`):**
    - In `stage2_main`, call `bios_read_sectors_lba_asm(&my_dap, boot_drive)`.
    - Check the return status.
    - Print a success or failure message (e.g., "Payload loaded." or "Payload load FAILED!").
  - **7. Jump to Loaded Payload (`src/legacy/stage2.c`):**
    - If loading was successful:
      - Create a function pointer to the payload's load address:
              `void (*payload_entry)(void) = (void (*)(void))( (PAYLOAD_LOAD_ADDRESS_SEGMENT << 4) + PAYLOAD_LOAD_ADDRESS_OFFSET );`
              *(Note: This assumes a flat 16-bit model for the payload or that the payload sets up its own segments if needed. For a simple raw binary, this direct jump is okay.)*
      - Call the function pointer: `payload_entry();`
    - If loading failed, halt or print an error and then halt.

- [ ] **Create a Simple Test Payload (e.g., `payload.asm` -> `payload.bin`)**
  - **1. Write `payload.asm`:**
    - `bits 16`
    - `org 0x0000` (relative to its load address, e.g., `0x1000:0000`)
    - Minimal code:
      - Print a message like "Payload Executing!" using BIOS INT 10h, AH=0Eh.
      - Infinite loop (`cli; hlt; jmp $`).
  - **2. Assemble `payload.asm`:**
    - Use NASM: `nasm payload.asm -f bin -o build/payload.bin`

- [X] **Build System (Makefile)**
  - [X] Compile/Assemble Stage 1 & 2.
  - [X] Create bootable floppy/disk image (`legacy_floppy.img`).
  - [ ] **Update Makefile for Payload:**
    - Add a rule to assemble `payload.asm` to `build/payload.bin`.
    - Modify the `$(LEGACY_FINAL_IMG)` rule to:
      - First, create an empty 1.44MB floppy image: `truncate -s 1440K $(LEGACY_FINAL_IMG)` (or `dd if=/dev/zero of=$(LEGACY_FINAL_IMG) bs=1K count=1440`).
      - Write Stage 1 to the beginning: `dd if=$(LEGACY_STAGE1_BIN) of=$(LEGACY_FINAL_IMG) conv=notrunc bs=512 count=1`.
      - Write Stage 2 immediately after Stage 1 (or wherever Stage 1 expects it): `dd if=$(LEGACY_STAGE2_BIN) of=$(LEGACY_FINAL_IMG) seek=1 conv=notrunc bs=512` (assuming Stage 2 starts at sector 1, LBA 1). Adjust `seek` based on `STAGE2_START_SECTOR` in `stage1.asm`.
      - Write `payload.bin` to its designated LBA: `dd if=build/payload.bin of=$(LEGACY_FINAL_IMG) seek=PAYLOAD_LBA_START conv=notrunc bs=512`. (Ensure `PAYLOAD_LBA_START` is a variable accessible in the Makefile or hardcoded consistently).

- [ ] **Testing**
  - Test the complete flow in QEMU:
    - Bootloader loads.
    - Stage 1 loads Stage 2.
    - Stage 2 prints its message.
    - Stage 2 attempts to load the payload.
    - Stage 2 prints success/failure for payload load.
    - If successful, the payload's message appears.
    - System halts.

### UEFI (Target: Load simple payload from ESP)

- [ ] **UEFI Application (C - `src/uefi/main.c`)**
  - [X] Standard `efi_main` entry point.
  - [X] Initialize EDK2 environment (handled by `UefiApplicationEntryPoint`).
  - [X] Print startup message using UEFI console services (`Print()`).
  - [ ] Use Simple File System Protocol to locate and read a kernel payload (e.g., binary blob) from a fixed path on the ESP (e.g., `/kernel.bin` or `/EFI/Pyramid/kernel.bin`).
  - [ ] Allocate memory for the payload (e.g., `gBS->AllocatePages`).
  - [ ] Load the payload into memory.
  - [ ] Jump to the loaded payload.
- [X] **Build System (Makefile)**
  - [X] Compile UEFI application using EDK2 build process (Clang/LLD).
  - [X] Produce `PyramidUefiApp.efi` (or similar).

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
