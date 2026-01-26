# Layer 3: Tactical Roadmap (Current Sprint)

**Focus:** Foundation Hardening & Core Optimization.
**Current Kernel:** v0.8 -> **Target:** v0.8.1 (Hardened).

> **Objective:** Resolve technical debt and improve system stability before implementing Filesystem/VFS and Userland.

---

## 1. 🛡️ System Debugging (The Panic System)

*Current Status: Basic red text. No register dumps. Hard to debug.*

- [x] **Refactor:** Move `Registers` struct to a shared header.
- [x] **Create:** `kernel/debug.c` and `kernel/debug.h`.
- [x] **Implement:** `panic_with_regs(const char* msg, Registers* r)` to dump CPU state (EIP/EAX/CS/EFLAGS/etc).
- [x] **Integrate:** Update IDT `isr_handler` to use the new Panic system on crashes.

## 2. 🧠 PMM Optimization

*Current Status: O(N) Linear Search (First-Fit).*

- [x] **Next-Fit Algorithm:** Add `last_free_index` tracking to `pmm.c`.
- [x] **Speed Test:** Verify allocations remain fast as memory fills (validated via diagnostics / fragmentation test).

## 3. ⚡ Power Management

*Current Status: Busy waiting 100% CPU.*

- [x] **Idle Loop:** Standardize idle path via `cpu_idle()` (STI+HLT) wrapper (no busy wait).
- [x] **Shell/Input Yield:** Keyboard blocking read halts CPU until IRQ (race-free, no polling burn).

---

## 4. 🐞 Refactoring & Diagnostics
- [x] **Consolidate Tests:** Move `test_heap` and `test_ata` from `main.c` into a new module `kernel/core/selftest.c`.
- [x] **Implement `run_diagnostics()`:** Implement `selftest_run_all()` called at the end of `k_main` that runs all tests and prints a summary report.
- [x] **Shell Command:** Add `diagnose` to KShell to re-run hardware checks on demand.
- [x] **Terminal Driver:** Extract VGA console into `kernel/drivers/terminal.c/.h` and remove cross-module `extern term_*` coupling.

---

## 5. 💾 Storage Hardening (ATA)

- [x] **LBA28 Read:** Implement real LBA sector reads end-to-end (driver API + `diskread` command + diagnostics validation).

---

## 6. 🔧 Driver Hardening Notes

- [x] **Keyboard Buffer Policy:** When the ring buffer is full, the newest keypress is dropped (non-blocking overflow behavior).
- [x] **RTC Robustness:** CMOS reads wait for update-in-progress to clear before sampling.

---

## 7. 📁 Filesystem / VFS Foundation (Phase 1)

- [x] **Define VFS API:** Static mount table + FD table (`open/read/close`).
- [x] **Implement VFS Core:** Longest-prefix mount resolution + safe bounds validation.
- [x] **Block Device Registry:** Generic `BlockDevice` registry API.
- [x] **ATA Block Wrapper:** Register primary master as `disk0` via block layer.
- [x] **Shell Visibility:** Add `blkinfo` and `mounts` commands.

---

## 8. ✅ Completed Tasks (Archive)

- [x] Keyboard Driver & KShell.
- [x] Time/RTC.
- [x] PIC Remapping.
