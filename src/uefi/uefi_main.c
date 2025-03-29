#include <efi.h>
#include <efilib.h>

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    InitializeLib(ImageHandle, SystemTable);

    // Basic initialization
    Print(L"Pyramid Bootloader (UEFI) starting...\n");

    // TODO: Implement memory map retrieval
    // TODO: Implement graphics output protocol initialization

    return EFI_SUCCESS;
}