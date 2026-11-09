/******************************************************************************
* Copyright (C) 2026 Taxi Project / Antigravity
* 
* Application: KU5P 1G GMII Ethernet Stress Testing & Verification Suite
* Target     : AMD Kintex UltraScale+ (xcku5p-ffvb676-2-i)
* Peripheral : taxi_eth_gmii_axi_wrapper (Base Address: 0x00020000)
* DMA        : Xilinx AXI DMA (Base Address: 0x41E00000, DevID: 0)
* PHY        : Realtek RTL8211EG (GMII Mode, 125 MHz GTX_CLK)
* Memory     : DDR4 SDRAM (0x80000000 - 0xBFFFFFFF, 1GB)
******************************************************************************/

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

#include "platform.h"
#include "xil_printf.h"
#include "xuartlite_l.h"
#include "sleep.h"

#include "eth_mac.h"
#include "eth_dma.h"
#include "packet_builder.h"
#include "stress_tests.h"

#ifndef UARTLITE_BASEADDR
#define UARTLITE_BASEADDR       0x40600000U
#endif

/******************************************************************************
* Interactive Command Menu
******************************************************************************/
static void print_menu(void)
{
    xil_printf("\r\n================================================================\r\n");
    xil_printf("       KU5P 1G GMII Ethernet Stress Testing Command Menu        \r\n");
    xil_printf("================================================================\r\n");
    xil_printf("  [1] Send Single Test Packet (0x88B5 Broadcast Frame)\r\n");
    xil_printf("  [2] Send Single ARP Request (Who has 192.168.1.1?)\r\n");
    xil_printf("  [3] Send Burst of 10 Packets\r\n");
    xil_printf("  [4] Run Pipelined TX Burst Stress Test (1,000 Frames)\r\n");
    xil_printf("  [5] Run Pipelined TX Burst Stress Test (10,000 Frames)\r\n");
    xil_printf("  [6] Run Full-Duplex Soak Stress Test (60 Seconds)\r\n");
    xil_printf("  [7] Run PRBS Data & DDR4 Memory Integrity Test (1,000 Frames)\r\n");
    xil_printf("  [8] Run DMA Soft-Reset & Auto-Recovery Test (10 Cycles)\r\n");
    xil_printf("  [9] Run RX Starvation & Buffer Exhaustion Resilience Test\r\n");
    xil_printf("  [c] Clear All MAC Hardware Counters\r\n");
    xil_printf("  [s] Dump All MAC Hardware Statistics\r\n");
    xil_printf("  [d] Dump DMA MM2S/S2MM & MAC Hardware Status\r\n");
    xil_printf("  [h] Print This Menu\r\n");
    xil_printf("================================================================\r\n\r\n");
}

/******************************************************************************
* Main Entry Point
******************************************************************************/
int main(void)
{
    init_platform();

    xil_printf("\r\n");
    xil_printf("================================================================\r\n");
    xil_printf("   Kintex UltraScale+ 1G GMII Ethernet Stress Testing Suite     \r\n");
    xil_printf("================================================================\r\n");
    xil_printf("  FPGA Device  : AMD Kintex UltraScale+ (xcku5p-ffvb676-2-i)\r\n");
    xil_printf("  Ethernet MAC : taxi_eth_gmii_axi_wrapper @ 0x%08X\r\n", (unsigned int)ETH_MAC_BASEADDR);
    xil_printf("  AXI DMA IP   : axi_dma @ 0x41E00000 (Device ID %d)\r\n", DMA_DEV_ID);
    xil_printf("  PHY Device   : Realtek RTL8211EG (GMII Mode, 125 MHz GTX_CLK)\r\n");
    xil_printf("  FPGA IP/MAC  : 192.168.1.175 / 00:0A:35:01:02:03\r\n");
    xil_printf("================================================================\r\n\r\n");

    /* Step 0: Test DDR4 */
    if (!test_ddr4_memory()) {
        xil_printf("[FATAL] DDR4 Memory check failed! Halting.\r\n");
        return -1;
    }

    /* Step 1: MAC CSR */
    if (!eth_mac_init(ETH_MAC_BASEADDR)) {
        xil_printf("[FATAL] MAC Core Initialization failed! Halting.\r\n");
        return -1;
    }

    /* Step 2: AXI DMA */
    if (eth_dma_init(DMA_DEV_ID) != XST_SUCCESS) {
        xil_printf("[FATAL] AXI DMA Setup failed! Halting.\r\n");
        return -1;
    }

    /* Poll any early RX packets before TX */
    eth_dma_poll_rx();

    /* Step 3: Run Initial Transmission Tests */
    xil_printf("[STEP 3] Running Automated Initial Verification Tests...\r\n");
    uint8_t pkt_buf[128];
    uint32_t pkt_len = 0;

    /* Test 1: Send Single 0x88B5 Experimental Test Frame */
    xil_printf("\r\n--- [Test 1: Single Broadcast Test Frame] ---\r\n");
    build_test_packet(pkt_buf, get_next_tx_seq(), &pkt_len);
    print_hex_dump("Outbound Frame", pkt_buf, pkt_len);
    eth_dma_transmit(pkt_buf, pkt_len, "Broadcast Test Frame (0x88B5)");

    eth_dma_poll_rx();

    /* Test 2: Send ARP Request Frame */
    xil_printf("\r\n--- [Test 2: ARP Request Frame] ---\r\n");
    build_arp_request(pkt_buf, &pkt_len);
    print_hex_dump("Outbound ARP", pkt_buf, pkt_len);
    eth_dma_transmit(pkt_buf, pkt_len, "ARP Request (Who has 192.168.1.1?)");

    eth_dma_poll_rx();

    eth_mac_dump_counters();
    print_menu();

    /* Step 4: Continuous Polling & Interactive Execution Loop */
    uint32_t loop_count = 0;
    while (1) {
        /* Check for UART character input (Non-blocking) */
        if (!XUartLite_IsReceiveEmpty(UARTLITE_BASEADDR)) {
            uint8_t cmd = XUartLite_RecvByte(UARTLITE_BASEADDR);
            switch (cmd) {
                case '1': {
                    build_test_packet(pkt_buf, get_next_tx_seq(), &pkt_len);
                    eth_dma_transmit(pkt_buf, pkt_len, "Single Test Frame");
                    break;
                }
                case '2': {
                    build_arp_request(pkt_buf, &pkt_len);
                    eth_dma_transmit(pkt_buf, pkt_len, "ARP Request");
                    break;
                }
                case '3': {
                    xil_printf("  [BURST] Transmitting 10 packets...\r\n");
                    for (int k = 0; k < 10; k++) {
                        build_test_packet(pkt_buf, get_next_tx_seq(), &pkt_len);
                        eth_dma_transmit(pkt_buf, pkt_len, NULL);
                        usleep(1000);
                    }
                    xil_printf("  [BURST] Done! Sent 10 packets.\r\n");
                    break;
                }
                case '4': {
                    run_tx_burst_test(1000);
                    break;
                }
                case '5': {
                    run_tx_burst_test(10000);
                    break;
                }
                case '6': {
                    run_soak_test(60);
                    break;
                }
                case '7': {
                    run_integrity_stress_test(1000);
                    break;
                }
                case '8': {
                    run_dma_recovery_test(10);
                    break;
                }
                case '9': {
                    run_rx_starvation_test();
                    break;
                }
                case 'c':
                case 'C': {
                    eth_mac_clear_counters();
                    break;
                }
                case 's':
                case 'S': {
                    eth_mac_dump_counters();
                    break;
                }
                case 'd':
                case 'D': {
                    eth_dma_dump_status();
                    break;
                }
                case 'h':
                case 'H': {
                    print_menu();
                    break;
                }
                default:
                    break;
            }
        }

        /* Check and handle inbound packets (Auto ARP Reply & Auto Ping Reply) */
        eth_dma_poll_rx();

        /* Periodic Heartbeat every ~3 seconds (3000 x 1ms) */
        loop_count++;
        if (loop_count % 3000 == 0) {
            uint32_t tx_good = eth_mac_read(REG_ETH_CNT_TX_GOOD);
            uint32_t rx_good = eth_mac_read(REG_ETH_CNT_RX_GOOD);
            uint32_t rx_ovfl = eth_mac_read(REG_ETH_CNT_RX_OVFL);
            uint32_t status  = eth_mac_read(REG_ETH_STATUS);
            XAxiDma *dma = eth_dma_get_instance();
            uint32_t rx_sr   = Xil_In32(dma->RegBase + XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
            xil_printf("[HEARTBEAT] Speed: %s | TX_G: %u | RX_G: %u | RX_OVFL: %u | S2MM_SR: 0x%08X (Halted=%d, Err=%d)\r\n",
                       ((status & 0x03) == 2) ? "1000M" : ((status & 0x03) == 1) ? "100M" : "10M",
                       (unsigned int)tx_good, (unsigned int)rx_good, (unsigned int)rx_ovfl,
                       (unsigned int)rx_sr, (int)(rx_sr & 1), (int)((rx_sr >> 14) & 1));
        }

        usleep(1000); /* 1 ms poll tick (1000 Hz) */
    }

    cleanup_platform();
    return 0;
}

