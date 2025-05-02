# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Changed
- Switched UEFI C compiler from GCC to Clang.
- Updated `Makefile` to use `clang`, `lld`, and `llvm-objcopy` for UEFI builds.

## [0.6.0] - YYYY-MM-DD

### Added
- Protected mode transition functionality (`pmode` command).
- Global Descriptor Table (GDT) implementation.
- 32-bit code execution environment setup.
- Basic video memory text output in protected mode.
- FAT BPB parsing functionality (`fsinfo` command).

### Changed
- Updated help text with new `pmode` and `fsinfo` commands.
- Improved A20 line enabling with automatic enablement before protected mode transition.

## [0.5.0] - YYYY-MM-DD

### Added
- A20 line enabling functionality (`a20` command).
- Multiple methods for A20 line control (keyboard controller, Fast A20).
- A20 status detection.

### Changed
- Updated help text with new `a20` command.

## [0.4.1] - YYYY-MM-DD

### Added
- Improved PowerShell build script (`build.ps1`) with better error handling.
- Troubleshooting section in the documentation (`README.md`).
- QEMU compatibility notes.

### Changed
- Increased Stage 2 bootloader size allocation (now 12 sectors).
- Enhanced memory detection output formatting.
- Better error messages for build failures in `build.ps1`.

### Fixed
- Fixed incorrect sector count in Stage 1 loading logic.
- Resolved QEMU display parameter incompatibility in `build.ps1` suggestions.

## [0.4.0] - YYYY-MM-DD

### Added
- Multi-stage bootloader architecture (Legacy BIOS).
- Stage 1 bootloader (fits in 512 bytes).
- Stage 2 with enhanced functionality.
- Command-line interface with multiple commands (`help`, `info`, `clear`, `reboot`).
- Memory detection using BIOS functions (`info` command).
- PowerShell build script for Windows (`build.ps1`).
- System information command (`info`).

### Changed
- Restructured bootloader to use two stages (Legacy BIOS).
- Enhanced color support with different color categories.
- Improved error handling in disk operations.

## [0.3.0] - YYYY-MM-DD

### Added
- Command-line interface with basic commands (`help`, `clear`).
- Custom prompt (`> `).
- Keyboard input handling with backspace support.
- String comparison functionality.
- Screen clearing functionality (`clear` command).

### Changed
- Better organized code with command handlers.
- Enhanced color support.

## [0.2.0] - YYYY-MM-DD

### Added
- Color text support.
- Enhanced error messages.
- Better disk I/O handling.

### Changed
- Improved screen clearing.
- Better organized constants.

## [0.1.0] - YYYY-MM-DD

### Added
- Initial bootloader implementation (Legacy BIOS).
- Basic text output
- Simple disk read operations
- Error checking for BIOS operations
- Basic keyboard input
