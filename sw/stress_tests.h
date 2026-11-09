#ifndef STRESS_TESTS_H
#define STRESS_TESTS_H

#include <stdint.h>
#include <stdbool.h>

bool test_ddr4_memory(void);
bool run_tx_burst_test(uint32_t total_packets);
void run_soak_test(uint32_t duration_sec);
bool run_integrity_stress_test(uint32_t count);
bool run_dma_recovery_test(uint32_t cycles);
void run_rx_starvation_test(void);

#endif /* STRESS_TESTS_H */

