#include "packet_builder.h"
#include "eth_dma.h"
#include <stdio.h>
#include <string.h>
#include "xil_printf.h"

const uint8_t FPGA_MAC[6] = {0x00, 0x0A, 0x35, 0x01, 0x02, 0x03};

static volatile uint32_t g_auto_arp_count  = 0;
static volatile uint32_t g_auto_ping_count = 0;
static uint32_t g_tx_seq_num = 1;

uint32_t get_auto_arp_count(void)
{
    return g_auto_arp_count;
}

uint32_t get_auto_ping_count(void)
{
    return g_auto_ping_count;
}

uint32_t get_next_tx_seq(void)
{
    return g_tx_seq_num++;
}

void print_hex_dump(const char *label, const uint8_t *data, uint32_t len)
{
    xil_printf("  [%s] Length = %d bytes:\r\n    ", label, (int)len);
    for (uint32_t i = 0; i < len; i++) {
        xil_printf("%02X ", data[i]);
        if ((i + 1) % 16 == 0 && (i + 1) < len) {
            xil_printf("\r\n    ");
        }
    }
    xil_printf("\r\n");
}

void build_test_packet(uint8_t *buf, uint32_t seq, uint32_t *len)
{
    /* Destination MAC: Broadcast FF:FF:FF:FF:FF:FF */
    buf[0] = 0xFF; buf[1] = 0xFF; buf[2] = 0xFF;
    buf[3] = 0xFF; buf[4] = 0xFF; buf[5] = 0xFF;

    /* Source MAC: Kintex-US+ FPGA (00:0A:35:01:02:03) */
    memcpy(&buf[6], FPGA_MAC, 6);

    /* EtherType: 0x88B5 (IEEE 802 Local Experimental Test) */
    buf[12] = 0x88; buf[13] = 0xB5;

    /* Payload: Sequence Number + Magic "KU5P" */
    buf[14] = (uint8_t)((seq >> 24) & 0xFF);
    buf[15] = (uint8_t)((seq >> 16) & 0xFF);
    buf[16] = (uint8_t)((seq >> 8)  & 0xFF);
    buf[17] = (uint8_t)(seq & 0xFF);
    buf[18] = 'K'; buf[19] = 'U'; buf[20] = '5'; buf[21] = 'P';

    /* Test Payload Pattern */
    for (uint32_t i = 22; i < ETH_PKT_MIN_LEN; i++) {
        buf[i] = (uint8_t)(i + (seq & 0xFF));
    }
    *len = ETH_PKT_MIN_LEN;
}

void build_arp_request(uint8_t *buf, uint32_t *len)
{
    /* Broadcast MAC */
    buf[0] = 0xFF; buf[1] = 0xFF; buf[2] = 0xFF;
    buf[3] = 0xFF; buf[4] = 0xFF; buf[5] = 0xFF;

    /* Source MAC: FPGA */
    memcpy(&buf[6], FPGA_MAC, 6);

    /* EtherType: ARP (0x0806) */
    buf[12] = 0x08; buf[13] = 0x06;

    /* Hardware Type: Ethernet (0x0001) */
    buf[14] = 0x00; buf[15] = 0x01;
    /* Protocol Type: IPv4 (0x0800) */
    buf[16] = 0x08; buf[17] = 0x00;
    /* Hardware Size (6), Protocol Size (4) */
    buf[18] = 0x06;
    buf[19] = 0x04;
    /* Opcode: ARP Request (0x0001) */
    buf[20] = 0x00; buf[21] = 0x01;

    /* Sender MAC: FPGA */
    memcpy(&buf[22], FPGA_MAC, 6);
    /* Sender IP: 192.168.1.175 */
    buf[28] = 192; buf[29] = 168; buf[30] = 1; buf[31] = 175;

    /* Target MAC: 00:00:00:00:00:00 */
    buf[32] = 0x00; buf[33] = 0x00; buf[34] = 0x00;
    buf[35] = 0x00; buf[36] = 0x00; buf[37] = 0x00;
    /* Target IP: 192.168.1.1 (Query Default Gateway / Host PC) */
    buf[38] = 192; buf[39] = 168; buf[40] = 1; buf[41] = 1;

    /* Pad to minimum 64 bytes */
    for (uint32_t i = 42; i < ETH_PKT_MIN_LEN; i++) {
        buf[i] = 0x00;
    }
    *len = ETH_PKT_MIN_LEN;
}

void build_prbs_packet(uint8_t *buf, uint32_t seq, uint32_t seed, uint32_t *len)
{
    /* Destination MAC: Broadcast */
    buf[0] = 0xFF; buf[1] = 0xFF; buf[2] = 0xFF;
    buf[3] = 0xFF; buf[4] = 0xFF; buf[5] = 0xFF;

    /* Source MAC */
    memcpy(&buf[6], FPGA_MAC, 6);

    /* EtherType: 0x88B5 (Test) */
    buf[12] = 0x88; buf[13] = 0xB5;

    /* Sequence Number */
    buf[14] = (uint8_t)((seq >> 24) & 0xFF);
    buf[15] = (uint8_t)((seq >> 16) & 0xFF);
    buf[16] = (uint8_t)((seq >> 8)  & 0xFF);
    buf[17] = (uint8_t)(seq & 0xFF);

    /* Magic tag "KU5P" */
    buf[18] = 'K'; buf[19] = 'U'; buf[20] = '5'; buf[21] = 'P';

    /* Seed */
    buf[22] = (uint8_t)((seed >> 24) & 0xFF);
    buf[23] = (uint8_t)((seed >> 16) & 0xFF);
    buf[24] = (uint8_t)((seed >> 8)  & 0xFF);
    buf[25] = (uint8_t)(seed & 0xFF);

    /* PRBS Payload: PRBS(k) = (PRBS(k-1) * 1103515245 + 12345) */
    uint32_t prbs = seed;
    uint16_t csum = 0;
    for (uint32_t i = 26; i < 62; i++) {
        prbs = prbs * 1103515245U + 12345U;
        uint8_t val = (uint8_t)((prbs >> 16) & 0xFF);
        buf[i] = val;
        csum += val;
    }

    /* 16-bit Payload Checksum */
    buf[62] = (uint8_t)((csum >> 8) & 0xFF);
    buf[63] = (uint8_t)(csum & 0xFF);

    *len = ETH_PKT_MIN_LEN;
}

void handle_rx_packet(const uint8_t *rx_buf, uint32_t rx_len)
{
    if (rx_len < 42) return;

    uint16_t eth_type = ((uint16_t)rx_buf[12] << 8) | rx_buf[13];

    /* Case 1: ARP Request from PC */
    if (eth_type == 0x0806) {
        uint16_t opcode = ((uint16_t)rx_buf[20] << 8) | rx_buf[21];
        if (opcode == 0x0001) { /* ARP Request */
            uint8_t target_ip[4] = {rx_buf[38], rx_buf[39], rx_buf[40], rx_buf[41]};

            /* Respond if query is for 192.168.1.175 or general 192.168.1.x */
            if (target_ip[0] == 192 && target_ip[1] == 168 && target_ip[2] == 1) {
                uint8_t reply_buf[64];
                memset(reply_buf, 0, 64);

                /* Eth Header: Dst = Requester MAC, Src = FPGA MAC */
                memcpy(&reply_buf[0], &rx_buf[6], 6);
                memcpy(&reply_buf[6], FPGA_MAC, 6);
                reply_buf[12] = 0x08; reply_buf[13] = 0x06;

                /* ARP Payload */
                reply_buf[14] = 0x00; reply_buf[15] = 0x01; /* Ethernet */
                reply_buf[16] = 0x08; reply_buf[17] = 0x00; /* IPv4 */
                reply_buf[18] = 0x06; reply_buf[19] = 0x04;
                reply_buf[20] = 0x00; reply_buf[21] = 0x02; /* ARP Reply */

                /* Sender: FPGA MAC & Target IP queried by PC */
                memcpy(&reply_buf[22], FPGA_MAC, 6);
                memcpy(&reply_buf[28], target_ip, 4);

                /* Target: PC MAC & PC IP */
                memcpy(&reply_buf[32], &rx_buf[22], 6);
                memcpy(&reply_buf[38], &rx_buf[28], 4);

                g_auto_arp_count++;
                eth_dma_transmit(reply_buf, 64, NULL);
            }
        }
    }
    /* Case 2: IPv4 ICMP Ping Echo Request */
    else if (eth_type == 0x0800 && rx_len >= 34) {
        uint8_t ip_proto = rx_buf[23];
        if (ip_proto == 1 && rx_len >= 42) { /* ICMP */
            uint8_t icmp_type = rx_buf[34];
            if (icmp_type == 8) { /* Echo Request */
                uint32_t reply_len = (rx_len < 64) ? 64 : rx_len;
                if (reply_len > 64) reply_len = 64;

                uint8_t reply_buf[64];
                memset(reply_buf, 0, 64);
                memcpy(reply_buf, rx_buf, (rx_len <= 64) ? rx_len : 64);

                /* Swap MAC addresses */
                memcpy(&reply_buf[0], &rx_buf[6], 6);
                memcpy(&reply_buf[6], FPGA_MAC, 6);

                /* Swap IP addresses */
                memcpy(&reply_buf[26], &rx_buf[30], 4);
                memcpy(&reply_buf[30], &rx_buf[26], 4);

                /* Change ICMP type to 0 (Echo Reply) */
                reply_buf[34] = 0;

                /* Adjust ICMP checksum: type changed 8 -> 0 (+0x0800) */
                uint32_t csum = ((uint32_t)reply_buf[36] << 8) | reply_buf[37];
                csum += 0x0800;
                if (csum > 0xFFFF) csum = (csum & 0xFFFF) + (csum >> 16);
                reply_buf[36] = (uint8_t)((csum >> 8) & 0xFF);
                reply_buf[37] = (uint8_t)(csum & 0xFF);

                g_auto_ping_count++;
                eth_dma_transmit(reply_buf, reply_len, NULL);
            }
        }
    }
}

