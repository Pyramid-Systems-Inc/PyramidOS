# Layer 3: Tactical Roadmap (Current Sprint)

**Focus:** Input Subsystem & Command Shell.
**Current Kernel:** v0.5 (IRQ Test) -> **Target:** v0.6 (Interactive Shell).

---

## 1. ⌨️ Keyboard Driver Implementation

*Current Status: IRQ fires and prints "KEY", but no data is processed.*

### Task 1.1: Scancode Translation

- [x] Create `kernel/keyboard.c` and `kernel/keyboard.h`.
- [x] Define `scancode_set1` array mapping indices `0x00`-`0x58` to ASCII characters.
- [x] Handle **Printable Characters** (a-z, 0-9, symbols).
- [x] Handle **Control Keys** (Enter `\n`, Backspace `\b`).

### Task 1.2: State Management

- [ ] Implement state variables: `static bool shift_pressed`, `static bool caps_lock`.
- [ ] Define `scancode_set1_shifted` array (mapping `1` -> `!`, `a` -> `A`).
- [ ] Logic to toggle state on `0x2A`/`0x36` (Shift Press) and `0xAA`/`0xB6` (Shift Release).

### Task 1.3: The Input Buffer

- [ ] Implement a **Circular Buffer** (Ring Buffer) of size 256 bytes to decouple the ISR from the Shell.
- [ ] **Producer (ISR):** Writes valid ASCII char to buffer (if not full).
- [ ] **Consumer (Shell):** `keyboard_get_char()` reads from buffer (blocking).

---

## 2. 🧵 String & Memory Utilities

*Current Status: Basic `memset`/`memcpy` exist. Need string parsing tools.*

- [ ] `strcmp` (String Compare) - Critical for checking commands ("help" vs "reboot").
- [ ] `strcpy` (String Copy) - For buffer management.
- [ ] `strlen` (String Length) - For buffer bounds checking.
- [ ] `strcat` (String Concatenate) - For formatting output.
- [ ] `strtok` (String Tokenizer) - For parsing arguments (e.g., `echo hello`).

---

## 3. 🐚 KShell (Pyramid Command Interface)

*Current Status: Infinite loop in `main.c`.*

### Task 3.1: The Prompt Loop

- [ ] Create `kernel/shell.c`.
- [ ] Implement `shell_init()`: Prints the welcome banner and `PyramidOS>` prompt.
- [ ] Implement `shell_run()`: The main infinite loop processing input.

### Task 3.2: Line Buffering

- [ ] Create a local buffer `char input_buffer[128]`.
- [ ] As keys arrive from Keyboard Driver:
  - [ ] Echo character to screen.
  - [ ] Add to `input_buffer`.
  - [ ] Handle **Backspace**: Decrement index, print `\b \b` to erase visually.
- [ ] On **Enter**: Null-terminate buffer and pass to parser.

### Task 3.3: Built-in Commands

- [ ] `help`: List available commands.
- [ ] `clear`: Clear VGA screen and reset cursor.
- [ ] `mem`: Query PMM for Total/Free RAM stats.
- [ ] `reboot`: Trigger CPU reset (via Keyboard Controller pulse or Triple Fault).
- [ ] `halt`: Stop the CPU (HLT loop).

---

## 4. 🐞 Refactoring & Cleanup

- [ ] **Move Logic:** Extract the `isr_handler` logic currently inside `idt.c` and properly route it to `keyboard_handler` in `keyboard.c`.
- [ ] **Header Cleanup:** Ensure `io.h` is consistently used for all Port I/O.
- [ ] **VGA Scroll:** Implement basic text scrolling when the terminal hits the bottom row (currently it wraps to top or stops).
