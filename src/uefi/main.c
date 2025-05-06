// =============================================================================
// Pyramid Bootloader - UEFI Application (Minimal)
// =============================================================================
#include <efi.h>
#include <efilib.h>

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    // Initialize gnu-efi library
    InitializeLib(ImageHandle, SystemTable);

    // Print startup message
    Print(L"Pyramid Bootloader: UEFI Entry\n");

    // TODO: Load kernel payload from ESP (Phase 1 Goal)
    Print(L"Halting system.\n");

    // Halt the system for now
    // UEFI doesn't have a simple 'hlt'. Usually achieved by returning
    // an error or entering an infinite loop after cleanup if needed.
    // For now, just loop indefinitely.
    while(1);

    // We shouldn't reach here in this minimal example
    return EFI_SUCCESS; // Or an appropriate error code
}
