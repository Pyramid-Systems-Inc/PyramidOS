# Contributing to PyramidOS

## Repository Status (Private / No License)
This repository is currently **private** and **no license is granted**. See `NOTICE`.

Contributions are accepted only from explicitly authorized collaborators.

---

## Philosophy
PyramidOS prioritizes:
- System stability
- Memory safety (especially in Ring 0)
- Hardware correctness
- Clear, readable freestanding C / Assembly

---

## Development Workflow
1. **Small changesets**: Keep commits focused and reviewable.
2. **Build before pushing**:
   - Release: `make clean && make`
   - Debug: `make clean && make debug`
   - Strict warnings (opt-in Werror): `make clean && make STRICT=1`
3. **Boot verification**: Run `make run` and confirm the kernel reaches KShell and `diagnose` succeeds.
4. **No silent failures**: If a state is unrecoverable, use the kernel panic path (don’t “guess and continue”).

---

## Coding Standards

### C (Freestanding)
- Allowed headers: `<stdint.h>`, `<stddef.h>`, `<stdbool.h>`
- Avoid host/libc dependencies (no `<stdio.h>`, `<stdlib.h>`)
- Use explicit-width integer types (`uint32_t`, `uint16_t`, `uint8_t`)
- Avoid magic numbers; prefer `#define` or named constants
- Validate pointers/arguments where practical

### Assembly (i386)
- Comment non-trivial instructions (why registers are preserved/used)
- Mark ELF asm objects as non-executable stack via `.note.GNU-stack`
- Keep interrupt stubs minimal and correct (EOI, stack discipline)

---

## Formatting
- `.editorconfig` is the baseline for indentation and whitespace rules.
- Keep code style consistent with surrounding files.
- Prefer clarity over cleverness.

---

## Project Layout Rules
- `kernel/arch/`: hardware-specific code (IDT/PIC/paging primitives)
- `kernel/core/`: kernel logic (PMM/VMM/heap/shell/debug)
- `kernel/drivers/`: devices and hardware drivers (terminal/keyboard/timer/rtc/ata)
- `kernel/lib/`: minimal freestanding helper routines

---

## Reporting Issues / Debugging
When reporting a bug, include:
- Build command used (release/debug/STRICT)
- The QEMU output/screenshot
- Steps to reproduce (commands typed in KShell, if applicable)
- Any recent code changes

---

## Security / Responsible Disclosure
Kernel bugs can represent serious flaws. Report privately to the project owner if the issue is security-sensitive.