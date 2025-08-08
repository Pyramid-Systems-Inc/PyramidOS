# boot/Makefile (Revised and Corrected)

# Directories
SRC_DIR = src
BUILD_DIR = ../build
LEGACY_BUILD_DIR = $(BUILD_DIR)/legacy_boot

# Tools
LEGACY_ASM = nasm
LEGACY_CC = i686-elf-gcc
LEGACY_LD = i686-elf-ld
LEGACY_OBJCOPY = i686-elf-objcopy

# Flags
CFLAGS_LEGACY = -m16 -march=i386 -ffreestanding -nostdlib -O2 -Wall -Wextra \
                -I$(SRC_DIR)/legacy
LEGACY_LINKER_SCRIPT = $(SRC_DIR)/legacy/linker.ld

# Source Files & Targets - Legacy
LEGACY_STAGE1_ASM = $(SRC_DIR)/legacy/stage1.asm
LEGACY_ENTRY_ASM = $(SRC_DIR)/legacy/entry.asm
LEGACY_STAGE2_C = $(SRC_DIR)/legacy/stage2.c

LEGACY_STAGE1_BIN = $(LEGACY_BUILD_DIR)/stage1.bin
LEGACY_ENTRY_OBJ = $(LEGACY_BUILD_DIR)/entry.o
LEGACY_STAGE2_OBJ = $(LEGACY_BUILD_DIR)/stage2.o
LEGACY_STAGE2_BIN = $(LEGACY_BUILD_DIR)/stage2.bin
KERNEL_BIN = $(BUILD_DIR)/kernel.bin

LEGACY_FINAL_IMG = $(BUILD_DIR)/pyramidos_legacy.img

# Sector where the kernel will be written on the disk image.
KERNEL_LBA_START = 60

.PHONY: all legacy uefi clean

# Default target
all: legacy

# --- Legacy BIOS Build ---
legacy: $(LEGACY_FINAL_IMG)

# Create the final floppy image
$(LEGACY_FINAL_IMG): $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) $(KERNEL_BIN)
	@echo "--- Creating Legacy Boot Image ---"
	# Create an empty 1.44MB image file filled with zeros
	dd if=/dev/zero of=$@ bs=1K count=1440
	# Write Stage 1 to the first sector (boot sector)
	dd if=$(LEGACY_STAGE1_BIN) of=$@ conv=notrunc bs=512 count=1
	# Write Stage 2 starting at the second sector
	dd if=$(LEGACY_STAGE2_BIN) of=$@ conv=notrunc seek=1 bs=512
	# Write the kernel to its designated LBA
	dd if=$(KERNEL_BIN) of=$@ conv=notrunc seek=$(KERNEL_LBA_START) bs=512
	@echo "Legacy image created at $@"

# Rule for building any object file from a C source file.
# Ensures the build directory exists before compiling.
$(LEGACY_BUILD_DIR)/%.o: $(SRC_DIR)/legacy/%.c
	mkdir -p $(LEGACY_BUILD_DIR)
	$(LEGACY_CC) $(CFLAGS_LEGACY) -c $< -o $@

# Rule for building any object file from an assembly source file.
$(LEGACY_BUILD_DIR)/%.o: $(SRC_DIR)/legacy/%.asm
	mkdir -p $(LEGACY_BUILD_DIR)
	$(LEGACY_ASM) -f elf $< -o $@

# Assemble Stage 1 (special case, direct to .bin)
$(LEGACY_STAGE1_BIN): $(LEGACY_STAGE1_ASM)
	mkdir -p $(LEGACY_BUILD_DIR)
	$(LEGACY_ASM) $< -f bin -o $@

# Link Stage 2
$(LEGACY_STAGE2_BIN): $(LEGACY_ENTRY_OBJ) $(LEGACY_STAGE2_OBJ)
	$(LEGACY_LD) -T $(LEGACY_LINKER_SCRIPT) $^ -o $(LEGACY_BUILD_DIR)/stage2.elf
	$(LEGACY_OBJCOPY) -O binary $(LEGACY_BUILD_DIR)/stage2.elf $@

# --- UEFI Build (Placeholder) ---
uefi:
	@echo "UEFI build not yet integrated."

# --- Clean Target ---
clean:
	rm -rf $(LEGACY_BUILD_DIR)