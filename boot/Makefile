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
KERNEL_IMG = $(BUILD_DIR)/kernel.img

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

# Build Stage 2 (pure assembly) with kernel params

# Stage2 depends on kernel image to know sector count
$(LEGACY_STAGE2_BIN): $(LEGACY_STAGE2_ASM) $(KERNEL_IMG) | $(LEGACY_BUILD_DIR)
	@echo "Building Stage 2..."
	@KERNEL_SIZE=$$(stat -c%s $(KERNEL_IMG) 2>/dev/null || stat -f%z $(KERNEL_IMG) 2>/dev/null); \
	KERNEL_SECTORS=$$(( ($$KERNEL_SIZE + 511) / 512 )); \
	echo "Kernel size: $$KERNEL_SIZE bytes ($$KERNEL_SECTORS sectors)"; \
	$(LEGACY_AS) $< -f bin -o $@ -D KERNEL_LBA=$(KERNEL_LBA_START) -D KERNEL_SECTOR_COUNT=$$KERNEL_SECTORS
	@SIZE=$$(stat -c%s $@ 2>/dev/null || stat -f%z $@ 2>/dev/null); \
	echo "Stage 2 size: $$SIZE bytes"

# Create the final floppy image
# Create the final floppy image
$(LEGACY_FINAL_IMG): $(LEGACY_STAGE1_BIN) $(LEGACY_STAGE2_BIN) $(KERNEL_IMG) | $(BUILD_DIR)
	@echo "--- Creating Legacy Boot Image ---"
	# Create an empty 1.44MB image
	dd if=/dev/zero of=$@ bs=512 count=2880 status=none
	# Write Stage 1 to first sector
	dd if=$(LEGACY_STAGE1_BIN) of=$@ bs=512 count=1 conv=notrunc status=none
	# Write Stage 2 starting at sector 2 (seek=1 means skip 1 sector)
	dd if=$(LEGACY_STAGE2_BIN) of=$@ bs=512 seek=1 conv=notrunc status=none
	# Write kernel image (header+bin) at sector 60
	dd if=$(KERNEL_IMG) of=$@ bs=512 seek=60 conv=notrunc status=none
	@echo "Disk image created successfully"
	@echo "Stage 1: 512 bytes at sector 0"
	@STAGE2_SIZE=$$(stat -c%s $(LEGACY_STAGE2_BIN) 2>/dev/null || stat -f%z $(LEGACY_STAGE2_BIN)); \
	STAGE2_SECTORS=$$(($$STAGE2_SIZE / 512 + ($$STAGE2_SIZE % 512 != 0))); \
	echo "Stage 2: $$STAGE2_SIZE bytes ($$STAGE2_SECTORS sectors) at sector 1"
	@KERNEL_SIZE=$$(stat -c%s $(KERNEL_IMG) 2>/dev/null || stat -f%z $(KERNEL_IMG)); \
	KERNEL_SECTORS=$$(($$KERNEL_SIZE / 512 + ($$KERNEL_SIZE % 512 != 0))); \
	echo "Kernel: $$KERNEL_SIZE bytes ($$KERNEL_SECTORS sectors) at sector 60"; \
	echo "Stage2 assembled with KERNEL_SECTOR_COUNT=$$KERNEL_SECTORS"


# Add this to boot/Makefile
hexdump: $(LEGACY_FINAL_IMG)
	@echo "=== Disk Image Layout ==="
	@echo "Sector 0 (Stage 1):"
	@hexdump -C $(LEGACY_FINAL_IMG) -n 512
	@echo ""
	@echo "Sector 1-8 (Stage 2):"
	@hexdump -C $(LEGACY_FINAL_IMG) -s 512 -n 64
	@echo ""
	@echo "Sector 60 (Kernel):"
	@hexdump -C $(LEGACY_FINAL_IMG) -s 30720 -n 64
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