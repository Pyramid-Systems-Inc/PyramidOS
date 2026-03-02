# Baa + Takween Plan for Building PyramidOS

## Objective
Enable PyramidOS to be built with **Baa (language/compiler)** and **Takween (build system)** for real bare-metal OS workflows (bootloader, freestanding kernel, disk image, QEMU run), not just user-space apps.

## Current Gap Summary
- PyramidOS is currently **32-bit i386 freestanding** (`i686-elf-*`, custom linker, raw disk image).
- Baa currently focuses on **x86_64 Windows/Linux user-space targets**.
- Takween MVP is **Windows-first** and uses `cmd /c` + `.exe` assumptions.

## Required Work in Baa
1. Add target: `i386-elf-baremetal`.
2. Add freestanding mode flags:
   - `--freestanding`
   - `--no-startup` (no `main`/CRT assumptions)
   - `--no-rt` (no hosted runtime/stdlib linkage)
3. Support custom entry symbol (example: `k_main` / `_start`).
4. Emit i386-compatible objects (`ELF32`) and assembly (`-m32` semantics).
5. Implement i386 ABI details (cdecl, stack alignment, callee/caller-saved rules).
6. Preserve low-level control needed by kernels (inline asm stability, volatile semantics, no hidden host dependencies).
7. Add regression suite for freestanding/kernel cases (no libc calls, no forbidden runtime refs).

## Required Work in Takween
1. Add Linux/WSL-first support in addition to Windows.
2. Remove hardcoded Windows command patterns (`cmd /c`, forced `.exe`).
3. Add OS profile type in config (example: `النوع: نواة`).
4. Add pipeline stages:
   - assemble bootloader
   - compile kernel objects
   - link with linker script
   - build raw image
   - run in QEMU
5. Add toolchain detection (`i686-elf-gcc`, `i686-elf-ld`, `nasm`, `qemu-system-i386`).
6. Add deterministic build graph + dependency tracking.

## Required Work in PyramidOS
1. Define Baa-safe kernel coding subset (no hosted assumptions).
2. Start with a mixed build (C + Baa), then migrate module-by-module.
3. Suggested migration order:
   - `kernel/lib` helpers
   - pure logic in `kernel/core`
   - selected `kernel/fs` pieces
   - drivers last (ATA/interrupt-sensitive paths)
4. Keep bootloader + linker script authoritative during early migration.

## Milestones (Execution Order)
1. **M0: Spec Freeze**  
   Define ABI, entrypoint, sections, forbidden runtime behavior.
2. **M1: Baa Freestanding Prototype**  
   Compile one minimal kernel function to `ELF32 .o` and link into current PyramidOS.
3. **M2: Takween OS Pipeline MVP**  
   Build + image + run (`qemu-system-i386`) in one command.
4. **M3: Mixed-Kernel Bring-up**  
   Boot PyramidOS with at least one production module compiled from Baa.
5. **M4: Expansion + QA Gates**  
   Determinism, cross-host reproducibility, panic/diagnostic parity checks.

## Definition of Done (First Real Success)
- `takween build-os` (or equivalent) produces `build/pyramidos.img`.
- `takween run-os` boots to KShell in QEMU.
- At least one non-trivial kernel module is built from Baa and passes `diagnose`.
- No CRT/libc dependency appears in final kernel link.

## Immediate Next Actions
1. Finalize the `i386-elf-baremetal` target spec (registers, calling convention, object format).
2. Add Baa freestanding flags and negative tests.
3. Extend Takween config schema for kernel projects.
4. Implement a pilot mixed build in PyramidOS (single Baa module linked with existing C kernel).
