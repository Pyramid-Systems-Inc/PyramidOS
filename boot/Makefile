# boot/Makefile (Revised and Corrected)

# Directories
SRC_DIR = src
BUILD_DIR = ../build
LEGACY_BUILD_DIR = $(BUILD_DIR)/legacy_boot

# Tools - Check for cross-compiler, fallback to native
ifeq ($(shell which i686-elf-gcc 2>/dev/null),)
    LEGACY_CC = gcc
    LEGACY_LD = ld
    LEGACY_OBJCOPY = objcopy
    LEGACY_AS = nasm
else
    LEGACY_CC = i686-elf-gcc
    LEGACY_LD = i686-elf-ld
    LEGACY_OBJCOPY = i686-elf-objcopy
    LEGACY_AS = nasm
endif

# Check if compiler supports -m16
CC_SUPPORTS_M16 := $(shell $(LEGACY_CC) -m16 -E -x c /dev/null >/dev/null 2>&1 && echo yes || echo no)

# Flags
ifeq ($(CC_SUPPORTS_M16),yes)
    CFLAGS_LEGACY = -m16 -march=i386 -ffreestanding -nostdlib -O2 -Wall -Wextra \
                    -fno-pic -fno-pie -fno-stack-protector -fomit-frame-pointer \
                    -I$(SRC_DIR)/legacy
else
    # Fallback to 32-bit mode with special handling
    CFLAGS_LEGACY = -m32 -march=i386 -ffreestanding -nostdlib -O2 -Wall -Wextra \
                    -fno-pic -fno-pie -fno-stack-protector -fomit-frame-pointer \
                    -I$(SRC_DIR)/legacy -D__REAL_MODE__
endif

ASFLAGS = -f elf32
LDFLAGS = -m elf_i386 -nostdlib

LEGACY_LINKER_SCRIPT = $(SRC_DIR)/legacy/linker.ld

# Source Files & Targets - Legacy
LEGACY_STAGE1_ASM = $(SRC_DIR)/legacy/stage1.asm
LEGACY_ENTRY_ASM = $(SRC_DIR)/legacy/entry.asm
LEGACY_PMODE_ASM = $(SRC_DIR)/legacy/pmode.asm
LEGACY_STAGE2_C = $(SRC_DIR)/legacy/stage2.c

LEGACY_STAGE1_BIN = $(LEGACY_BUILD_DIR)/stage1.bin
LEGACY_ENTRY_OBJ = $(LEGACY_BUILD_DIR)/entry.o
LEGACY_PMODE_OBJ = $(LEGACY_BUILD_DIR)/pmode.o
LEGACY_STAGE2_OBJ = $(LEGACY_BUILD_DIR)/stage2.o
LEGACY_STAGE2_BIN = $(LEGACY_BUILD_DIR)/stage2.bin
KERNEL_BIN = $(BUILD_DIR)/kernel.bin

LEGACY_FINAL_IMG = $(BUILD_DIR)/pyramidos_legacy.img

# Sector where the kernel will be written on the disk image.
KERNEL_LBA_START = 60

.PHONY: all legacy uefi clean info

# Default target
all: legacy

# Info target to debug build settings
info:
	@echo "CC: $(LEGACY_CC)"
	@echo "LD: $(LEGACY_LD)"
	@echo "Compiler supports -m16: $(CC_SUPPORTS_M16)"
	@echo "CFLAGS: $(CFLAGS_LEGACY)"

# --- Legacy BIOS Build ---
legacy: $(LEGACY_FINAL_IMG)

# Create build directory
$(LEGACY_BUILD_DIR):
	mkdir -p $(LEGACY_BUILD_DIR)

# Create the final floppy image
$(LEGACY_FINAL_IMG): $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) $(KERNEL_BIN) | $(BUILD_DIR)
	@echo "--- Creating Legacy Boot Image ---"
	# Create an empty 1.44MB image file filled with zeros
	dd if=/dev/zero of=$@ bs=1K count=1440 2>/dev/null
	# Write Stage 1 to the first sector (boot sector)
	dd if=$(LEGACY_STAGE1_BIN) of=$@ conv=notrunc bs=512 count=1 2>/dev/null
	# Write Stage 2 starting at the second sector
	dd if=$(LEGACY_STAGE2_BIN) of=$@ conv=notrunc seek=1 bs=512 2>/dev/null
	# Write kernel at sector 60
	@echo "Writing kernel to LBA $(KERNEL_LBA_START) (sector 60)"
	dd if=$(KERNEL_BIN) of=$@ conv=notrunc seek=$(KERNEL_LBA_START) bs=512 2>/dev/null
	@echo "Legacy image created at $@"
	@echo "Stage 1 size: $$(stat -c%s $(LEGACY_STAGE1_BIN) 2>/dev/null || stat -f%z $(LEGACY_STAGE1_BIN) 2>/dev/null) bytes"
	@echo "Stage 2 size: $$(stat -c%s $(LEGACY_STAGE2_BIN) 2>/dev/null || stat -f%z $(LEGACY_STAGE2_BIN) 2>/dev/null) bytes"
	@echo "Kernel size: $$(stat -c%s $(KERNEL_BIN) 2>/dev/null || stat -f%z $(KERNEL_BIN) 2>/dev/null) bytes"

# Create build directory if needed
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Compile C source file
$(LEGACY_STAGE2_OBJ): $(LEGACY_STAGE2_C) | $(LEGACY_BUILD_DIR)
	$(LEGACY_CC) $(CFLAGS_LEGACY) -c $< -o $@

# Assemble entry.asm as 32-bit ELF object
$(LEGACY_ENTRY_OBJ): $(LEGACY_ENTRY_ASM) | $(LEGACY_BUILD_DIR)
	$(LEGACY_AS) $(ASFLAGS) $< -o $@

# Assemble Stage 1 (special case, direct to .bin)
$(LEGACY_STAGE1_BIN): $(LEGACY_STAGE1_ASM) | $(LEGACY_BUILD_DIR)
	$(LEGACY_AS) $< -f bin -o $@

# Assemble pmode.asm
$(LEGACY_PMODE_OBJ): $(LEGACY_PMODE_ASM) | $(LEGACY_BUILD_DIR)
	$(LEGACY_AS) $(ASFLAGS) $< -o $@

# Link Stage 2
$(LEGACY_STAGE2_BIN): $(LEGACY_ENTRY_OBJ) $(LEGACY_PMODE_OBJ) $(LEGACY_STAGE2_OBJ) $(LEGACY_LINKER_SCRIPT)
	$(LEGACY_LD) $(LDFLAGS) -T $(LEGACY_LINKER_SCRIPT) $(LEGACY_ENTRY_OBJ) $(LEGACY_PMODE_OBJ) $(LEGACY_STAGE2_OBJ) -o $(LEGACY_BUILD_DIR)/stage2.elf
	$(LEGACY_OBJCOPY) -O binary $(LEGACY_BUILD_DIR)/stage2.elf $@
	@echo "Stage 2 linked successfully"

# Create a dummy kernel for testing
$(KERNEL_BIN): | $(BUILD_DIR)
	@echo "Creating dummy kernel for testing..."
	@echo -n "KERNEL HERE!" > $@
	@dd if=/dev/zero bs=512 count=16 2>/dev/null | tr '\0' 'K' >> $@

# --- UEFI Build (Placeholder) ---
uefi:
	@echo "UEFI build not yet integrated."

# --- Clean Target ---
clean:
	rm -rf $(LEGACY_BUILD_DIR)
	rm -f $(LEGACY_FINAL_IMG)

# --- Run Target ---
run: $(LEGACY_FINAL_IMG)
	qemu-system-i386 -fda $(LEGACY_FINAL_IMG)

# --- Debug Target ---
debug: $(LEGACY_FINAL_IMG)
	qemu-system-i386 -fda $(LEGACY_FINAL_IMG) -s -S &
	@echo "QEMU started in debug mode. Connect with: gdb -ex 'target remote :1234'"