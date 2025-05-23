// =============================================================================
// Pyramid Bootloader - UEFI Application (EDK2 Port)
// =============================================================================
#include <Uefi.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiLib.h>
#include <Library/PrintLib.h> // For Print()

/**
  The user Entry Point for Application. The user code starts with this function
  as the real entry point for the application.

  @param[in] ImageHandle    The firmware allocated handle for the EFI image.
  @param[in] SystemTable    A pointer to the EFI System Table.

  @retval EFI_SUCCESS       The entry point is executed successfully.
  @retval other             Some error occurs when executing this entry point.

**/
EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  // EDK2's UefiApplicationEntryPoint initializes necessary globals like gST, gBS

  // Print startup message
  Print(L"Pyramid Bootloader: UEFI Entry (EDK2 from src/uefi/main.c)\n");

  // TODO: Load kernel payload from ESP (Phase 1 Goal)
  Print(L"Halting system (from src/uefi/main.c).\n");

  // The UefiApplicationEntryPoint library will handle exiting the application
  // after UefiMain returns. No need for an infinite loop here.

  return EFI_SUCCESS;
}
