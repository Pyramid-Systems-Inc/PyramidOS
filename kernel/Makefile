# kernel/Makefile

# Tools
CC = i686-elf-gcc
ASM = nasm
LD = i686-elf-ld

# Build flags
# -m32: 32-bit
# -ffreestanding: No standard library
# -nostdlib: No standard startup files
# -O2: Optimization
# -Wall -Wextra: Warnings
CFLAGS = -m32 -ffreestanding -nostdlib -O2 -Wall -Wextra
ASMFLAGS = -f elf32
LDFLAGS = -T linker.ld

# Source files and objects
OBJS = main.o entry.o
TARGET_BIN = ../build/kernel.bin
TARGET_ELF = ../build/kernel.elf

.PHONY: all clean

# Default target
all: $(TARGET_BIN)

# Link objects into an ELF file
$(TARGET_ELF): $(OBJS) linker.ld
	$(LD) $(LDFLAGS) $(OBJS) -o $@

# Convert the ELF file to a flat binary
$(TARGET_BIN): $(TARGET_ELF)
	i686-elf-objcopy -O binary $< $@

# Compile C source
main.o: main.c
	$(CC) $(CFLAGS) -c $< -o $@

# Assemble assembly source
entry.o: entry.asm
	$(ASM) $(ASMFLAGS) $< -o $@

# Clean build artifacts
clean:
	rm -f *.o $(TARGET_ELF) $(TARGET_BIN)