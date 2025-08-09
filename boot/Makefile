# boot/Makefile

# Directories
SRC_DIR = src
BUILD_DIR = ../build
LEGACY_BUILD_DIR = $(BUILD_DIR)/legacy_boot

# Tools - Check for cross-compiler, fallback to native
ifeq ($(shell which i686-elf-gcc 2>/dev/null),)
	LEGACY_AS = nasm
else
	LEGACY_AS = nasm
endif

# Source Files & Targets - Legacy
LEGACY_STAGE1_ASM = $(SRC_DIR)/legacy/stage1.asm
LEGACY_STAGE2_ASM = $(SRC_DIR)/legacy/stage2.asm

LEGACY_STAGE1_BIN = $(LEGACY_BUILD_DIR)/stage1.bin
LEGACY_STAGE2_BIN = $(LEGACY_BUILD_DIR)/stage2.bin
KERNEL_BIN = $(BUILD_DIR)/kernel.bin

LEGACY_FINAL_IMG = $(BUILD_DIR)/pyramidos_legacy.img

# Sector where the kernel will be written on the disk image
KERNEL_LBA_START = 60

.PHONY: all legacy clean info run debug

# Default target
all: legacy

# Info target to debug build settings
info:
	@echo "SRC_DIR: $(SRC_DIR)"
	@echo "BUILD_DIR: $(BUILD_DIR)"
	@echo "LEGACY_BUILD_DIR: $(LEGACY_BUILD_DIR)"
	@echo "LEGACY_STAGE1_ASM: $(LEGACY_STAGE1_ASM)"
	@echo "LEGACY_STAGE1_BIN: $(LEGACY_STAGE1_BIN)"

# Legacy BIOS Build
legacy: $(LEGACY_FINAL_IMG)

# Create build directory
$(LEGACY_BUILD_DIR):
	mkdir -p $(LEGACY_BUILD_DIR)

# Build Stage 1
$(LEGACY_STAGE1_BIN): $(LEGACY_STAGE1_ASM) | $(LEGACY_BUILD_DIR)
	@echo "Building Stage 1..."
	$(LEGACY_AS) $< -f bin -o $@
	@SIZE=$$(stat -c%s $@ 2>/dev/null || stat -f%z $@ 2>/dev/null); \
	if [ $$SIZE -ne 512 ]; then \
		echo "ERROR: Stage 1 must be exactly 512 bytes (is $$SIZE)"; \
		exit 1; \
	fi
	@echo "Stage 1 built successfully (512 bytes)"

# Build Stage 2 (pure assembly)
$(LEGACY_STAGE2_BIN): $(LEGACY_STAGE2_ASM) | $(LEGACY_BUILD_DIR)
	@echo "Building Stage 2..."
	$(LEGACY_AS) $< -f bin -o $@
	@SIZE=$$(stat -c%s $@ 2>/dev/null || stat -f%z $@ 2>/dev/null); \
	echo "Stage 2 size: $$SIZE bytes"

# Create the final floppy image
$(LEGACY_FINAL_IMG): $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) $(KERNEL_BIN) | $(BUILD_DIR)
	@echo "--- Creating Legacy Boot Image ---"
	dd if=/dev/zero of=$@ bs=1K count=1440 2>/dev/null
	dd if=$(LEGACY_STAGE1_BIN) of=$@ conv=notrunc bs=512 count=1 2>/dev/null
	dd if=$(LEGACY_STAGE2_BIN) of=$@ conv=notrunc seek=1 bs=512 2>/dev/null
	@echo "Writing kernel to LBA $(KERNEL_LBA_START)"
	dd if=$(KERNEL_BIN) of=$@ conv=notrunc seek=$(KERNEL_LBA_START) bs=512 2>/dev/null
	@echo "Legacy image created at $@"
	@echo "Stage 1 size: 512 bytes"
	@SIZE2=$$(stat -c%s $(LEGACY_STAGE2_BIN) 2>/dev/null || stat -f%z $(LEGACY_STAGE2_BIN) 2>/dev/null); \
	echo "Stage 2 size: $$SIZE2 bytes"
	@SIZEK=$$(stat -c%s $(KERNEL_BIN) 2>/dev/null || stat -f%z $(KERNEL_BIN) 2>/dev/null); \
	echo "Kernel size: $$SIZEK bytes"

# Create build directory if needed
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

# Clean Target
clean:
	rm -rf $(LEGACY_BUILD_DIR)
	rm -f $(LEGACY_FINAL_IMG)

# Run Target
run: $(LEGACY_FINAL_IMG)
	qemu-system-i386 -fda $(LEGACY_FINAL_IMG)

# Debug Target
debug: $(LEGACY_FINAL_IMG)
	qemu-system-i386 -fda $(LEGACY_FINAL_IMG) -s -S &
	@echo "QEMU started in debug mode. Connect with: gdb -ex 'target remote :1234'"