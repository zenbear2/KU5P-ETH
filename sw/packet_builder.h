#ifndef PACKET_BUILDER_H
#define PACKET_BUILDER_H

#include <stdint.h>
#include <stdbool.h>

extern const uint8_t FPGA_MAC[6];

void print_hex_dump(const char *label, const uint8_t *data, uint32_t len);
void build_test_packet(uint8_t *buf, uint32_t seq, uint32_t *len);
void build_arp_request(uint8_t *buf, uint32_t *len);
void build_prbs_packet(uint8_t *buf, uint32_t seq, uint32_t seed, uint32_t *len);
void handle_rx_packet(const uint8_t *rx_buf, uint32_t rx_len);

uint32_t get_auto_arp_count(void);
uint32_t get_auto_ping_count(void);
uint32_t get_next_tx_seq(void);

#endif /* PACKET_BUILDER_H */

