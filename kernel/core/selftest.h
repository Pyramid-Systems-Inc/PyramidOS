#ifndef SELFTEST_H
#define SELFTEST_H

#include <stdint.h>

/*
 * Self-test return codes:
 *   0 = PASS
 *   non-zero = FAIL
 */
int selftest_pmm(void);
int selftest_heap(void);
int selftest_ata(void);

/*
 * Runs all self-tests and prints a summary report to the console.
 * Intended to be callable both at boot and from KShell ("diagnose").
 */
void selftest_run_all(void);

#endif