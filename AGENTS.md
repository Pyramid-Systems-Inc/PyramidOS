# Repository Guidelines

## Project Structure & Module Organization
- `boot/src/legacy/` contains the BIOS bootloader (`stage1.asm`, `stage2.asm`).
- `kernel/arch/i386/` holds architecture-specific bring-up (entry, linker script, IDT/ISR glue).
- `kernel/core/` contains kernel subsystems such as PMM/VMM, heap, shell, panic/debug, and self-tests.
- `kernel/drivers/` contains hardware drivers (PIC, PIT, keyboard, ATA, terminal, block/MBR).
- `kernel/fs/` implements VFS-related filesystems (`nullfs`, `devfs`, `pyfs`), and `kernel/lib/` is freestanding utility code.
- `docs/` stores setup and roadmap docs; `build/` is generated output and should not be hand-edited.

## Build, Test, and Development Commands
- `make clean && make` builds the default release image (`build/pyramidos.img`).
- `make clean && make debug` builds a debug profile with symbols.
- `make clean && make STRICT=1` enables strict warnings (`-Werror`).
- `make run` boots the image in QEMU (`qemu-system-i386`).
- Toolchain: prefer `i686-elf-gcc`; the Makefile falls back to native `gcc -m32` when unavailable.

## Coding Style & Naming Conventions
- Follow `.editorconfig`: 4 spaces for `*.c`, `*.h`, `*.asm`; tabs in `Makefile`; 2 spaces in docs/YAML/JSON.
- Write freestanding C (`-ffreestanding`, C11): avoid host libc usage (`stdio/stdlib`).
- Use explicit-width integer types (`uint32_t`, `uint16_t`, etc.) and named constants instead of magic numbers.
- Keep naming consistent with the codebase: lowercase `snake_case` for files/functions, `UPPER_SNAKE_CASE` for macros/constants.

## Testing Guidelines
- There is no host-side unit test framework yet; validation is boot/runtime based.
- Minimum check for each change: build (`make` or `make debug`) and boot (`make run`).
- At KShell, run `diagnose`; for storage/VFS changes also verify `blkinfo`, `mounts`, `pyfs_sb`, and `diskread 0`.
- Include exact reproduction steps and observed output when reporting regressions.

## Commit & Pull Request Guidelines
- Match existing history style: imperative, capitalized subject lines (example: `Add DevFS virtual filesystem and mount at /dev`).
- Keep commits focused and bisectable; avoid mixing unrelated refactors.
- PRs should include: scope summary, commands run, boot verification result, and QEMU output/screenshot for behavior changes.
- Request review from the relevant `CODEOWNERS` group for touched areas.

## Security & Repository Status
- This repository is private and all-rights-reserved (see `NOTICE`).
- Report security-sensitive kernel issues privately to maintainers instead of filing public issues.
