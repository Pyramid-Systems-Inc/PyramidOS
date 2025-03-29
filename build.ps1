#!/usr/bin/env pwsh
# Pyramid Bootloader Build Script for Windows

# Configuration
$SRC_DIR = "src"
$BUILD_DIR = "build"
$EFI_DIR = "gnu-efi"
$EFI_INC = "$EFI_DIR/inc"
$EFI_LIB = "$EFI_DIR/lib"

# Floppy image configuration
$FLOPPY_SIZE = 1474560  # 1.44MB floppy
$STAGE2_SECTORS = 8     # Number of sectors for stage 2

# Ensure build directory exists
if (-not (Test-Path $BUILD_DIR)) {
    New-Item -ItemType Directory -Path $BUILD_DIR | Out-Null
    Write-Host "Created build directory: $BUILD_DIR"
}

# Function to check if a command exists
function Test-CommandExists {
    param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) { return $true }
    }
    catch { return $false }
    finally { $ErrorActionPreference = $oldPreference }
}

# Check for required tools
if (-not (Test-CommandExists "nasm")) {
    Write-Host "Error: NASM assembler not found. Please install NASM." -ForegroundColor Red
    exit 1
}

# Check for QEMU
$qemuInstalled = Test-CommandExists "qemu-system-i386"
if (-not $qemuInstalled) {
    Write-Host "Warning: QEMU not found. You can install it to test the bootloader." -ForegroundColor Yellow
}

# Build Legacy BIOS Bootloader
function Build-LegacyBootloader {
    Write-Host "Building legacy bootloader..." -ForegroundColor Cyan
    
    # Compile main.asm to binary
    $mainBin = "$BUILD_DIR/main.bin"
    $mainAsm = "$SRC_DIR/legacy/main.asm"
    
    nasm $mainAsm -f bin -o $mainBin
    
    if (-not (Test-Path $mainBin)) {
        Write-Host "Error: Failed to build legacy bootloader" -ForegroundColor Red
        return $false
    }
    
    $binSize = (Get-Item $mainBin).Length
    Write-Host "  Binary size: $binSize bytes" -ForegroundColor Gray
    
    # Create floppy image
    $floppyImg = "$BUILD_DIR/main_floppy.img"
    
    # Create a clean 1.44MB floppy image
    $bytes = New-Object byte[] $FLOPPY_SIZE
    [io.file]::WriteAllBytes((Resolve-Path $BUILD_DIR).Path + "/main_floppy.img", $bytes)
    
    # Write bootloader to the floppy image
    $fileStream = [System.IO.File]::OpenWrite((Resolve-Path $floppyImg).Path)
    $bootloaderBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $mainBin).Path)
    $fileStream.Write($bootloaderBytes, 0, $bootloaderBytes.Length)
    $fileStream.Close()
    
    Write-Host "Legacy bootloader built successfully: $floppyImg" -ForegroundColor Green
    
    # Create ISO image if mkisofs is available
    if (Test-CommandExists "mkisofs") {
        Write-Host "Creating bootable ISO image..." -ForegroundColor Cyan
        $isoDir = "$BUILD_DIR/iso"
        $bootDir = "$isoDir/boot"
        
        # Create ISO directory structure
        if (Test-Path $isoDir) { Remove-Item -Recurse -Force $isoDir }
        New-Item -ItemType Directory -Path $bootDir | Out-Null
        
        # Copy bootloader to ISO directory
        Copy-Item $mainBin "$bootDir/main.bin"
        
        # Create ISO image
        $isoFile = "$BUILD_DIR/main.iso"
        mkisofs -R -b boot/main.bin -no-emul-boot -boot-load-size 4 -o $isoFile $isoDir
        
        # Clean up
        Remove-Item -Recurse -Force $isoDir
        
        Write-Host "Bootable ISO created: $isoFile" -ForegroundColor Green
    }
    else {
        Write-Host "Warning: mkisofs not found. ISO image creation skipped." -ForegroundColor Yellow
    }
    
    return $true
}

# Build UEFI Bootloader
function Build-UEFIBootloader {
    Write-Host "UEFI bootloader build not implemented yet." -ForegroundColor Yellow
    Write-Host "This requires a MinGW-w64 GCC toolchain configured for UEFI development." -ForegroundColor Gray
    return $false
}

# Function to get QEMU version and check compatibility
function Get-QemuInfo {
    if (-not $qemuInstalled) { return }
    
    try {
        $qemuVersion = (qemu-system-i386 --version) | Select-Object -First 1
        Write-Host "  QEMU version: $qemuVersion" -ForegroundColor Gray
        
        # Try to detect if the version supports the win32 display parameter
        $supportsWin32 = $true
        try {
            $testOutput = (qemu-system-i386 -display win32 -help 2>&1)
            if ($testOutput -match "Parameter 'type' does not accept value 'win32'") {
                $supportsWin32 = $false
            }
        } catch {
            $supportsWin32 = $false
        }
        
        return $supportsWin32
    } catch {
        Write-Host "  Could not determine QEMU version" -ForegroundColor Gray
        return $false
    }
}

# Run the builds
$legacySuccess = Build-LegacyBootloader
$uefiSuccess = Build-UEFIBootloader

# Output summary
Write-Host "`nBuild Summary:" -ForegroundColor White
Write-Host "  Legacy bootloader: $(if ($legacySuccess) { "Success" } else { "Failed" })" -ForegroundColor $(if ($legacySuccess) { "Green" } else { "Red" })
Write-Host "  UEFI bootloader: $(if ($uefiSuccess) { "Success" } else { "Failed" })" -ForegroundColor $(if ($uefiSuccess) { "Green" } else { "Yellow" })

# Check QEMU compatibility
$supportsWin32 = Get-QemuInfo

# Instructions for running
if ($legacySuccess) {
    Write-Host "`nTo run the legacy bootloader:" -ForegroundColor Cyan
    
    if ($qemuInstalled) {
        if ($supportsWin32) {
            Write-Host "  qemu-system-i386 -fda $BUILD_DIR/main_floppy.img -display win32" -ForegroundColor White
        } else {
            Write-Host "  qemu-system-i386 -fda $BUILD_DIR/main_floppy.img" -ForegroundColor White
            Write-Host "  Note: Your QEMU version doesn't support the win32 display parameter" -ForegroundColor Yellow
        }
        
        if (Test-Path "$BUILD_DIR/main.iso") {
            if ($supportsWin32) {
                Write-Host "  qemu-system-i386 -cdrom $BUILD_DIR/main.iso -display win32" -ForegroundColor White
            } else {
                Write-Host "  qemu-system-i386 -cdrom $BUILD_DIR/main.iso" -ForegroundColor White
            }
        }
    } else {
        Write-Host "  QEMU not found. Please install QEMU to test the bootloader." -ForegroundColor Yellow
    }
}

if ($uefiSuccess) {
    Write-Host "`nTo run the UEFI bootloader:" -ForegroundColor Cyan
    Write-Host "  Not implemented yet" -ForegroundColor Yellow
}