#include "rtc.h"
#include "io.h"

#define CMOS_ADDR 0x70
#define CMOS_DATA 0x71

// Helper to read a CMOS register
static uint8_t get_rtc_register(int reg) {
    outb(CMOS_ADDR, reg);
    return inb(CMOS_DATA);
}

// Check if RTC is currently updating (results effectively invalid during update)
static int get_update_in_progress_flag(void) {
    outb(CMOS_ADDR, 0x0A);
    return (inb(CMOS_DATA) & 0x80);
}

// Convert BCD (Binary Coded Decimal) to Binary
// e.g., 0x14 (20) -> 14
static uint8_t bcd2bin(uint8_t bcd) {
    return ((bcd / 16) * 10) + (bcd & 0x0F);
}

void rtc_get_time(DateTime* dt) {
    uint8_t statusB;

    // Wait until update is finished
    while (get_update_in_progress_flag());

    dt->second = get_rtc_register(0x00);
    dt->minute = get_rtc_register(0x02);
    dt->hour   = get_rtc_register(0x04);
    dt->day    = get_rtc_register(0x07);
    dt->month  = get_rtc_register(0x08);
    dt->year   = get_rtc_register(0x09);

    // Check if data is BCD (Bit 2 of Register B is 0)
    statusB = get_rtc_register(0x0B);

    if (!(statusB & 0x04)) {
        dt->second = bcd2bin(dt->second);
        dt->minute = bcd2bin(dt->minute);
        dt->hour   = bcd2bin(dt->hour);
        dt->day    = bcd2bin(dt->day);
        dt->month  = bcd2bin(dt->month);
        dt->year   = bcd2bin(dt->year);
    }

    // Adjust year (CMOS usually stores last 2 digits)
    // We assume 20xx for now.
    dt->year += 2000;
}