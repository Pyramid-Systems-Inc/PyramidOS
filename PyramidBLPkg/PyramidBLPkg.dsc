[Defines]
  PLATFORM_NAME                  = PyramidBLPkg
  PLATFORM_GUID                  = ff5bae77-f5d9-4f0e-8212-b9bc63dd3bd4
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x00010005
  OUTPUT_DIRECTORY               = Build/PyramidBLPkg
  SUPPORTED_ARCHITECTURES        = X64 # Or IA32|X64 if you want both
  BUILD_TARGETS                  = DEBUG RELEASE
  SKUID_IDENTIFIER               = DEFAULT

[LibraryClasses]
  # Common libraries needed by many modules
  PcdLib|MdePkg/Library/BasePcdLibNull/BasePcdLibNull.inf
  MemoryAllocationLib|MdePkg/Library/UefiMemoryAllocationLib/UefiMemoryAllocationLib.inf
  BaseLib|MdePkg/Library/BaseLib/BaseLib.inf
  BaseMemoryLib|MdePkg/Library/BaseMemoryLib/BaseMemoryLib.inf
  DebugLib|MdePkg/Library/BaseDebugLibNull/BaseDebugLibNull.inf # Or a serial port based one
  DevicePathLib|MdePkg/Library/UefiDevicePathLib/UefiDevicePathLib.inf
  UefiBootServicesTableLib|MdePkg/Library/UefiBootServicesTableLib/UefiBootServicesTableLib.inf
  UefiRuntimeServicesTableLib|MdePkg/Library/UefiRuntimeServicesTableLib/UefiRuntimeServicesTableLib.inf
  UefiLib|MdePkg/Library/UefiLib/UefiLib.inf
  PrintLib|MdePkg/Library/BasePrintLib/BasePrintLib.inf

[Components]
  # List your application's INF file
  PyramidBLPkg/UefiApp/PyramidUefiApp.inf