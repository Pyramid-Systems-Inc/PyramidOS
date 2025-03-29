# Changelog

All notable changes to this project will be documented in this file.

## [0.6.0]

### Added
- Protected mode transition functionality
- Global Descriptor Table (GDT) implementation
- 32-bit code execution environment
- Basic video memory text output in protected mode
- New 'pmode' command in the bootloader CLI

### Changed
- Updated help text with new protected mode command
- Improved A20 line enabling with automatic enablement before protected mode transition

## [0.5.0]

### Added
- A20 line enabling functionality
- Multiple methods for A20 line control (keyboard controller, Fast A20)
- A20 status detection
- New 'a20' command in the bootloader CLI

### Changed
- Updated help text with new A20 command

## [0.4.1]

### Added
- Improved PowerShell build script with better error handling
- Troubleshooting section in the documentation
- QEMU compatibility notes

### Changed
- Increased Stage 2 bootloader size to 3 sectors for additional functionality
- Enhanced memory detection with improved formatting
- Better error messages for build failures

### Fixed
- Fixed incorrect sector count in Stage 2 loading
- Resolved QEMU display parameter incompatibility

## [0.4.0]

### Added
- Multi-stage bootloader architecture
- Stage 1 bootloader (fits in 512 bytes)
- Stage 2 with enhanced functionality
- Command-line interface with multiple commands
- Memory detection using BIOS functions
- PowerShell build script for Windows
- System information command

### Changed
- Restructured bootloader to use two stages
- Enhanced color support with different color categories
- Improved error handling in disk operations

## [0.3.0]

### Added
- Command-line interface with basic commands
- Custom prompt
- Keyboard input handling with backspace support
- String comparison functionality
- Screen clearing functionality

### Changed
- Better organized code with command handlers
- Enhanced color support

## [0.2.0]

### Added
- Color text support
- Enhanced error messages
- Better disk I/O handling

### Changed
- Improved screen clearing
- Better organized constants

## [0.1.0]

### Added
- Initial bootloader implementation
- Basic text output
- Simple disk read operations
- Error checking for BIOS operations
- Basic keyboard input
