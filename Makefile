# ==============================================================================
# PyramidOS Master Makefile (Fixed Directory Logic)
# ==============================================================================

# --- Toolchain Configuration ---
CC = i686-elf-gcc
LD = i686-elf-ld
OBJCOPY = i686-elf-objcopy

ifeq ($(shell which $(CC) 2>/dev/null),)
    CC = gcc
    LD = ld
    OBJCOPY = objcopy
    CFLAGS_EXTRA = -m32
    LDFLAGS_EXTRA = -melf_i386
endif

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

# --- Flags ---
CFLAGS = $(CFLAGS_EXTRA) -ffreestanding -O2 -Wall -Wextra -fno-pie -fno-stack-protector -I$(KERNEL_DIR)
LDFLAGS = $(LDFLAGS_EXTRA) -T $(KERNEL_DIR)/linker.ld

# ==============================================================================
# Build Rules
# ==============================================================================

.PHONY: all clean run

all: $(DISK_IMG)

# Ensure build directory exists before building any file
$(BUILD_DIR):
	@mkdir -p $@

# --- Kernel Compilation ---

# Note: "| $(BUILD_DIR)" means "ensure directory exists, but don't rebuild if dir timestamp changes"

$(BUILD_DIR)/entry.o: $(KERNEL_DIR)/entry.asm | $(BUILD_DIR)
	$(ASM) -f elf32 $< -o $@

$(BUILD_DIR)/main.o: $(KERNEL_DIR)/main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/string.o: $(KERNEL_DIR)/string.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/pmm.o: $(KERNEL_DIR)/pmm.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(KERNEL_BIN): $(BUILD_DIR)/entry.o $(BUILD_DIR)/main.o $(BUILD_DIR)/string.o $(BUILD_DIR)/pmm.o
	$(LD) $(LDFLAGS) -o $(BUILD_DIR)/kernel.elf $^
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $@

$(KERNEL_HDR): $(KERNEL_BIN)
	@SIZE=$$(stat -c%s $(KERNEL_BIN) 2>/dev/null || stat -f%z $(KERNEL_BIN)); \
	echo "Kernel Size: $$SIZE bytes"; \
	$(ASM) -f bin $(KERNEL_DIR)/header.asm -o $@ -D KERNEL_SIZE=$$SIZE

$(KERNEL_IMG): $(KERNEL_HDR) $(KERNEL_BIN)
	cat $^ > $@

# --- Bootloader Compilation ---

$(STAGE1_BIN): $(BOOT_DIR)/stage1.asm | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@

$(STAGE2_BIN): $(BOOT_DIR)/stage2.asm | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@

# --- Disk Image ---

$(DISK_IMG): $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_IMG)
	@echo "--- Assembling Disk Image ---"
	dd if=/dev/zero of=$@ bs=512 count=2880 status=none
	dd if=$(STAGE1_BIN) of=$@ bs=512 count=1 conv=notrunc status=none
	dd if=$(STAGE2_BIN) of=$@ bs=512 seek=1 conv=notrunc status=none
	dd if=$(KERNEL_IMG) of=$@ bs=512 seek=60 conv=notrunc status=none
	@echo "Build Complete: $@"

# --- Utilities ---

clean:
	rm -rf $(BUILD_DIR)

run: $(DISK_IMG)
	qemu-system-i386 -drive format=raw,file=$(DISK_IMG),index=0,if=floppy