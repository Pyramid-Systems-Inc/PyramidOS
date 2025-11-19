# Layer 3: Tactical Roadmap (Current Sprint)

**Focus:** Input Subsystem & Command Shell.
**Current Version:** v0.5 -> Target v0.6.

---

## 1. ⌨️ Keyboard Driver Implementation

*Current Status: IRQ fires, but we only print "KEY". We need actual characters.*

### Task 1.1: Scancode Translation Table

- [ ] Define `scancode_set1` array mapping indices `0x00`-`0x58` to ASCII characters.
- [ ] Handle **Printable Characters** (a-z, 0-9, symbols).
- [ ] Handle **Control Keys** (Enter `\n`, Backspace `\b`, Tab `\t`).

### Task 1.2: Shift & Caps Lock Logic

- [ ] Create state variables: `bool shift_pressed`, `bool caps_lock`.
- [ ] Define `scancode_set1_shifted` array (for `!` instead of `1`, `A` instead of `a`).
- [ ] Update ISR to toggle state on `0x2A`/`0x36` (Shift Press) and `0xAA`/`0xB6` (Shift Release).

### Task 1.3: The Keyboard Buffer (Ring Buffer)

- [ ] Implement a **Circular Buffer** (FIFO) of size 256 bytes.
- [ ] **Producer (ISR):** Writes ASCII char to buffer if not full.
- [ ] **Consumer (Kernel):** `keyboard_get_char()` reads from buffer (blocking or non-blocking).

---

## 2. 🧵 String Library Expansion

*Current Status: Minimal functions. Need parsing tools for the shell.*

- [ ] `strcmp` (String Compare) - For checking commands ("help" vs "clear").
- [ ] `strcpy` (String Copy) - For buffer management.
- [ ] `strlen` (String Length) - Already implemented? Verify.
- [ ] `strcat` (String Concatenate) - For building output paths.
- [ ] `memset` / `memcpy` - Already implemented.

---

## 3. 🐚 The Kernel Shell (KShell)

*Current Status: Infinite loop in `k_main`.*

### Task 3.1: Command Line Interface

- [ ] Create `shell_init()` and `shell_update()`.
- [ ] Implement **Prompt**: `PyramidOS>`
- [ ] Implement **Input Line Buffer**: Store characters as typed.
- [ ] Implement **Backspace handling**: Visually remove char and update buffer.

### Task 3.2: Command Parser

- [ ] On `ENTER` press:
  - [ ] Null-terminate the input buffer.
  - [ ] Compare against known commands.

### Task 3.3: Basic Commands

- [ ] `help`: List commands.
- [ ] `clear`: Clear screen (reset cursor).
- [ ] `mem`: Print PMM stats (Total/Free RAM).
- [ ] `reboot`: Triple fault the CPU to restart.

---

## 4. 🐞 Cleanup & Refactoring

- [ ] Move `isr_handler` code from `idt.c` to specific drivers (call `keyboard_handler` from `idt.c`).
- [ ] Ensure all `outb`/`inb` calls use the `io.h` wrapper.
