// Placeholder for Filesystem Info Logic
#include "stage2.h"

// Define structure for BPB (matches layout in assembly)
// Ensure packing is correct for direct memory access if used
#pragma pack(push, 1) // Watcom pragma for byte alignment
typedef struct {
    unsigned char   jmp[3];
    char            oem_id[8];
    unsigned short  bytes_per_sector;
    unsigned char   sectors_per_cluster;
    unsigned short  reserved_sectors;
    unsigned char   num_fats;
    unsigned short  root_entries;
    unsigned short  total_sectors16;
    unsigned char   media_descriptor;
    unsigned short  sectors_per_fat16;
    // ... other fields if needed ...
} BiosParameterBlock;
#pragma pack(pop)

// Function to parse and display BPB info
void display_fsinfo(void) {
    // BPB is located at 0x0000:0x7C00 (where Stage 1 was loaded)
    // We need a far pointer to access it from Stage 2's segment.
    // Watcom uses __far pointers or segment:offset notation.
    // Let's assume Stage 2 C code runs with DS pointing to its own segment.
    // We need an assembly helper or direct memory access with segment override.

    // Option 1: Use a far pointer (syntax might vary slightly with Watcom version)
    // Requires setting up DS or ES temporarily, or using segment override prefixes if possible inline.
    // This is complex and error-prone from C directly.

    // Option 2: Assembly helper `read_bpb_field(offset)` that sets DS=0 and reads. (Safer)
    
    // Option 3: Copy BPB data to Stage 2's data segment using assembly helper. (Simplest for C)
    // Let's assume Option 3 for this placeholder.
    
    static BiosParameterBlock bpb_local; // Static storage in Stage 2's data segment
    int success; 

    print_string_c("Parsing FAT BPB...\r\n", COLOR_NORMAL);
    
    // Call assembly helper to copy BPB data into our local struct
    // Need to pass a far pointer to bpb_local. Watcom uses MK_FP(seg, off)
    // Assuming _DATA is the segment for static data in compact model.
    // This requires including <dos.h> for MK_FP.
    // Alternatively, modify the assembly helper to assume ES is already _DATA
    // and just pass the offset. Let's try the latter for simplicity.
    // Need to modify copy_bpb_to in assembly first.
    
    // Assuming copy_bpb_to is modified to take only offset relative to ES:
    // success = copy_bpb_to_es(&bpb_local); // Need to rename/modify helper
    
    // For now, let's call the existing helper, assuming C can form the far pointer
    // This might require <dos.h> and compiler specifics.
    // Placeholder call:
    success = copy_bpb_to(&bpb_local); 


    if (success) { 
        print_string_c("FAT BPB parsed successfully.\r\n", COLOR_SUCCESS);
        print_string_c("  Bytes/Sector: 0x", COLOR_NORMAL);
        print_hex_word_c(bpb_local.bytes_per_sector, COLOR_NORMAL);
        print_newline_c(COLOR_NORMAL);
        print_string_c("  Sectors/Cluster: 0x", COLOR_NORMAL);
        print_hex_word_c((unsigned short)bpb_local.sectors_per_cluster, COLOR_NORMAL);
        print_newline_c(COLOR_NORMAL);
        print_string_c("  Reserved Sectors: 0x", COLOR_NORMAL);
        print_hex_word_c(bpb_local.reserved_sectors, COLOR_NORMAL);
        print_newline_c(COLOR_NORMAL);
        print_string_c("  Num FATs: 0x", COLOR_NORMAL);
        print_hex_word_c((unsigned short)bpb_local.num_fats, COLOR_NORMAL);
        print_newline_c(COLOR_NORMAL);
        print_string_c("  Root Entries: 0x", COLOR_NORMAL);
        print_hex_word_c(bpb_local.root_entries, COLOR_NORMAL);
        print_newline_c(COLOR_NORMAL);
        print_string_c("  Sectors/FAT: 0x", COLOR_NORMAL);
        print_hex_word_c(bpb_local.sectors_per_fat16, COLOR_NORMAL);
        print_newline_c(COLOR_NORMAL);
    } else {
        print_string_c("FAT BPB parsing failed (assembly helper error?).\r\n", COLOR_ERROR);
        print_string_c("FSInfo logic not fully implemented in C yet.\r\n", COLOR_NORMAL); // Placeholder message
    }
}
