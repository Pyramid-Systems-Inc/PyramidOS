# Layer 3: Tactical Roadmap (Current Sprint)

**Focus:** Foundation Hardening & Core Optimization.
**Current Kernel:** v0.7 -> **Target:** v0.7.5 (Hardened).

> **Objective:** Resolve technical debt and improve system stability before implementing Dynamic Memory.

---

## 1. 🛡️ System Debugging (The Panic System)

*Current Status: Basic red text. No register dumps. Hard to debug.*

- [ ] **Refactor:** Move `Registers` struct to a shared header.
- [ ] **Create:** `kernel/debug.c` and `kernel/debug.h`.
- [ ] **Implement:** `panic_on_err(char* msg, Registers* r)` to dump CPU state (EIP, EAX, CS, EFLAGS).
- [ ] **Integrate:** Update IDT `isr_handler` to use the new Panic system on crashes.

## 2. 🧠 PMM Optimization

*Current Status: O(N) Linear Search (First-Fit).*

- [ ] **Next-Fit Algorithm:** Add `last_free_index` tracking to `pmm.c`.
- [ ] **Speed Test:** Verify allocations remain fast as memory fills.

## 3. ⚡ Power Management

*Current Status: Busy waiting 100% CPU.*

- [ ] **Halt Loop:** Replace `while(1)` with `while(1) { asm volatile("hlt"); }`.
- [ ] **Shell Optimization:** Ensure keyboard polling yields to the CPU.

---

## 4. 🐞 Refactoring & Diagnostics
- [ ] **Consolidate Tests:** Move `test_heap` and `test_ata` from `main.c` into a new module `kernel/selftest.c`.
- [ ] **Implement `run_diagnostics()`:** A function called at the end of `k_main` that runs all tests and prints a summary report.
- [ ] **Shell Command:** Add `diagnose` to KShell to re-run hardware checks on demand.

---

## 5. ✅ Completed Tasks (Archive)

- [x] Keyboard Driver & KShell.
- [x] Time/RTC.
- [x] PIC Remapping.
