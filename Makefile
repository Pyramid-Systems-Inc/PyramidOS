# ==============================================================================
# PyramidOS Master Makefile
# ==============================================================================

# --- Toolchain Configuration ---
# Attempt to detect cross-compiler, fall back to native GCC if not found.
CC = i686-elf-gcc
LD = i686-elf-ld
OBJCOPY = i686-elf-objcopy

# If i686-elf-gcc is not in PATH, try standard gcc with 32-bit flags
ifeq ($(shell which $(CC) 2>/dev/null),)
    CC = gcc
    LD = ld
    OBJCOPY = objcopy
    # Force 32-bit mode for native tools
    CFLAGS_EXTRA = -m32
    LDFLAGS_EXTRA = -melf_i386
endif

# Assembler
ASM = nasm

# --- Directories ---
BUILD_DIR = build
BOOT_DIR = boot/src/legacy
KERNEL_DIR = kernel

# --- Targets ---
KERNEL_BIN = $(BUILD_DIR)/kernel.bin
KERNEL_HDR = $(BUILD_DIR)/kernel.hdr
KERNEL_IMG = $(BUILD_DIR)/kernel.img
STAGE1_BIN = $(BUILD_DIR)/stage1.bin
STAGE2_BIN = $(BUILD_DIR)/stage2.bin
DISK_IMG   = $(BUILD_DIR)/pyramidos.img

# --- Compiler Flags ---
# -ffreestanding: No standard library
# -fno-pie: No Position Independent Executable (we need absolute addresses)
CFLAGS = $(CFLAGS_EXTRA) -ffreestanding -O2 -Wall -Wextra -fno-pie -fno-stack-protector
LDFLAGS = $(LDFLAGS_EXTRA) -T $(KERNEL_DIR)/linker.ld

# ==============================================================================
# Build Rules
# ==============================================================================

.PHONY: all clean run dirs

all: dirs $(DISK_IMG)

dirs:
	@mkdir -p $(BUILD_DIR)

# 1. Build Kernel Object Files
$(BUILD_DIR)/entry.o: $(KERNEL_DIR)/entry.asm
	$(ASM) -f elf32 $< -o $@

$(BUILD_DIR)/main.o: $(KERNEL_DIR)/main.c
	$(CC) $(CFLAGS) -c $< -o $@

# 2. Link Kernel (ELF -> Binary)
$(KERNEL_BIN): $(BUILD_DIR)/entry.o $(BUILD_DIR)/main.o
	$(LD) $(LDFLAGS) -o $(BUILD_DIR)/kernel.elf $^
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $@

# 3. Generate Kernel Header (Depends on Kernel Bin Size)
$(KERNEL_HDR): $(KERNEL_BIN)
	@SIZE=$$(stat -c%s $(KERNEL_BIN) 2>/dev/null || stat -f%z $(KERNEL_BIN)); \
	echo "Kernel Size: $$SIZE bytes"; \
	$(ASM) -f bin $(KERNEL_DIR)/header.asm -o $@ -D KERNEL_SIZE=$$SIZE

# 4. Combine Header + Kernel
$(KERNEL_IMG): $(KERNEL_HDR) $(KERNEL_BIN)
	cat $^ > $@

# 5. Build Bootloaders
$(STAGE1_BIN): $(BOOT_DIR)/stage1.asm
	$(ASM) -f bin $< -o $@

$(STAGE2_BIN): $(BOOT_DIR)/stage2.asm
	$(ASM) -f bin $< -o $@

# 6. Create Final Disk Image
# Layout:
# Sector 0 (LBA 0): Stage 1 (512 bytes)
# Sector 1 (LBA 1): Stage 2 (4KB / 8 Sectors)
# Sector 60 (LBA 60): Kernel Image
$(DISK_IMG): $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_IMG)
	@echo "--- Assembling Disk Image ---"
	# Create blank 1.44MB image
	dd if=/dev/zero of=$@ bs=512 count=2880 status=none
	
	# Write Stage 1
	dd if=$(STAGE1_BIN) of=$@ bs=512 count=1 conv=notrunc status=none
	
	# Write Stage 2 (Seek 1 = LBA 1)
	dd if=$(STAGE2_BIN) of=$@ bs=512 seek=1 conv=notrunc status=none
	
	# Write Kernel (Seek 60 = LBA 60)
	dd if=$(KERNEL_IMG) of=$@ bs=512 seek=60 conv=notrunc status=none
	
	@echo "Build Complete: $@"

# --- Utilities ---

clean:
	rm -rf $(BUILD_DIR)

run: $(DISK_IMG)
	qemu-system-i386 -drive format=raw,file=$(DISK_IMG),index=0,if=floppy

# Debug mode (pauses CPU at start, connects to GDB on port 1234)
debug: $(DISK_IMG)
	qemu-system-i386 -s -S -drive format=raw,file=$(DISK_IMG),index=0,if=floppy