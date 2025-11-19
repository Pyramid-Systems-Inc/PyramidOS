# ==============================================================================
# PyramidOS Master Makefile (Phase 1 Complete)
# ==============================================================================

# --- Toolchain Configuration ---
CC = i686-elf-gcc
LD = i686-elf-ld
OBJCOPY = i686-elf-objcopy

# Fallback to native GCC with 32-bit flags if cross-compiler is missing
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
# -I$(KERNEL_DIR) allows includes like #include "idt.h" to work
CFLAGS = $(CFLAGS_EXTRA) -ffreestanding -O2 -Wall -Wextra -fno-pie -fno-stack-protector -I$(KERNEL_DIR)
LDFLAGS = $(LDFLAGS_EXTRA) -T $(KERNEL_DIR)/linker.ld

# ==============================================================================
# Build Rules
# ==============================================================================

.PHONY: all clean run

all: $(DISK_IMG)

# Ensure build directory exists
$(BUILD_DIR):
	@mkdir -p $@

# --- Kernel Compilation ---

# 1. Assembly Entry (The Bridge)
$(BUILD_DIR)/entry.o: $(KERNEL_DIR)/entry.asm | $(BUILD_DIR)
	$(ASM) -f elf32 $< -o $@

# 2. Assembly ISR Stubs (IDT)
$(BUILD_DIR)/idt_asm.o: $(KERNEL_DIR)/idt_asm.asm | $(BUILD_DIR)
	$(ASM) -f elf32 $< -o $@

# 3. C Source Files
$(BUILD_DIR)/main.o: $(KERNEL_DIR)/main.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/string.o: $(KERNEL_DIR)/string.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/pmm.o: $(KERNEL_DIR)/pmm.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/idt.o: $(KERNEL_DIR)/idt.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/vmm.o: $(KERNEL_DIR)/vmm.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/pic.o: $(KERNEL_DIR)/pic.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/keyboard.o: $(KERNEL_DIR)/keyboard.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(BUILD_DIR)/shell.o: $(KERNEL_DIR)/shell.c | $(BUILD_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# 4. Link Kernel (Combine ALL Objects)
# CRITICAL: entry.o must be linked, but the linker script handles the order.
OBJECTS = $(BUILD_DIR)/entry.o \
          $(BUILD_DIR)/main.o \
          $(BUILD_DIR)/string.o \
          $(BUILD_DIR)/pmm.o \
          $(BUILD_DIR)/idt.o \
          $(BUILD_DIR)/idt_asm.o \
          $(BUILD_DIR)/vmm.o \
          $(BUILD_DIR)/pic.o \
		  $(BUILD_DIR)/keyboard.o \
		  $(BUILD_DIR)/shell.o

$(KERNEL_BIN): $(OBJECTS)
	$(LD) $(LDFLAGS) -o $(BUILD_DIR)/kernel.elf $^
	$(OBJCOPY) -O binary $(BUILD_DIR)/kernel.elf $@

# 5. Generate Header (Calculates size dynamically)
$(KERNEL_HDR): $(KERNEL_BIN)
	@SIZE=$$(stat -c%s $(KERNEL_BIN) 2>/dev/null || stat -f%z $(KERNEL_BIN)); \
	echo "Kernel Size: $$SIZE bytes"; \
	$(ASM) -f bin $(KERNEL_DIR)/header.asm -o $@ -D KERNEL_SIZE=$$SIZE

# 6. Create Final Kernel Image (Header + Binary)
$(KERNEL_IMG): $(KERNEL_HDR) $(KERNEL_BIN)
	cat $^ > $@

# --- Bootloader Compilation ---

$(STAGE1_BIN): $(BOOT_DIR)/stage1.asm | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@

$(STAGE2_BIN): $(BOOT_DIR)/stage2.asm | $(BUILD_DIR)
	$(ASM) -f bin $< -o $@

# --- Disk Image Construction ---

$(DISK_IMG): $(STAGE1_BIN) $(STAGE2_BIN) $(KERNEL_IMG)
	@echo "--- Assembling Disk Image ---"
	# 1. Create blank 1.44MB image (2880 sectors * 512 bytes)
	dd if=/dev/zero of=$@ bs=512 count=2880 status=none
	
	# 2. Write Stage 1 (Sector 0)
	dd if=$(STAGE1_BIN) of=$@ bs=512 count=1 conv=notrunc status=none
	
	# 3. Write Stage 2 (Sector 1)
	dd if=$(STAGE2_BIN) of=$@ bs=512 seek=1 conv=notrunc status=none
	
	# 4. Write Kernel (Sector 60)
	dd if=$(KERNEL_IMG) of=$@ bs=512 seek=60 conv=notrunc status=none
	
	@echo "Build Complete: $@"

# --- Utilities ---

clean:
	rm -rf $(BUILD_DIR)

run: $(DISK_IMG)
	qemu-system-i386 -drive format=raw,file=$(DISK_IMG),index=0,if=floppy