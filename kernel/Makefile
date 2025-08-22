# kernel/Makefile

# Check for cross-compiler, fallback to regular gcc
ifeq ($(shell which i686-elf-gcc 2>/dev/null),)
    CC = gcc
    LD = ld
    OBJCOPY = objcopy
    $(info Note: Using native gcc. Make sure you have 32-bit support installed.)
else
    CC = i686-elf-gcc
    LD = i686-elf-ld
    OBJCOPY = i686-elf-objcopy
endif

ASM = nasm

# Build flags
CFLAGS = -m32 -ffreestanding -nostdlib -O2 -Wall -Wextra -fno-builtin -fno-stack-protector -I.
ASMFLAGS = -f elf32
LDFLAGS = -melf_i386 -T linker.ld

# Source files and objects
C_SOURCES = main.c vga.c idt.c exceptions.c timer.c keyboard.c string.c pic.c
ASM_SOURCES = entry.asm idt_asm.asm
OBJS = $(C_SOURCES:.c=.o) $(ASM_SOURCES:.asm=.o)

TARGET_BIN = ../build/kernel.bin
TARGET_ELF = ../build/kernel.elf

.PHONY: all clean

# Default target
all: $(TARGET_BIN)
	@echo "Kernel built successfully!"
	@stat -c "Size: %s bytes" $(TARGET_BIN) 2>/dev/null || stat -f "Size: %z bytes" $(TARGET_BIN) 2>/dev/null || echo "Size: unknown"

# Link objects into an ELF file
$(TARGET_ELF): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) $(OBJS) -o $@

# Convert the ELF file to a flat binary
$(TARGET_BIN): $(TARGET_ELF)
	$(OBJCOPY) -O binary $< $@

# Pattern rule for C files
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Pattern rule for assembly files
%.o: %.asm
	$(ASM) $(ASMFLAGS) $< -o $@

# Dependencies
main.o: main.c vga.h stdint.h stddef.h idt.h timer.h keyboard.h string.h
vga.o: vga.c vga.h stdint.h stddef.h
idt.o: idt.c idt.h vga.h pic.h stdint.h
exceptions.o: exceptions.c idt.h vga.h string.h stddef.h stdint.h
timer.o: timer.c timer.h vga.h io.h pic.h string.h stdint.h
keyboard.o: keyboard.c keyboard.h vga.h io.h pic.h string.h timer.h stdint.h
string.o: string.c string.h stddef.h
pic.o: pic.c pic.h io.h vga.h stdint.h

# Clean build artifacts
clean:
	rm -f *.o $(TARGET_ELF) $(TARGET_BIN)