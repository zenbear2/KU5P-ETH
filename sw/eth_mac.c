#include "eth_mac.h"
#include <stdio.h>
#include "xil_printf.h"
#include "sleep.h"

bool eth_mac_init(uint32_t base_addr)
{
    uint32_t ident = eth_mac_read(REG_ETH_IDENT);
    uint32_t version = eth_mac_read(REG_ETH_VERSION);
    uint32_t status = eth_mac_read(REG_ETH_STATUS);
    uint32_t speed = status & 0x03;

    char id_str[5];
    id_str[0] = (char)(ident & 0xFF);
    id_str[1] = (char)((ident >> 8) & 0xFF);
    id_str[2] = (char)((ident >> 16) & 0xFF);
    id_str[3] = (char)((ident >> 24) & 0xFF);
    id_str[4] = '\0';

    xil_printf("[MAC] Initializing Core (Base: 0x%08X)...\r\n", (unsigned int)base_addr);
    xil_printf("  IP Identifier : 0x%08X (\"%s\")\r\n", (unsigned int)ident, id_str);
    xil_printf("  IP Version    : 0x%08X (v%d.%d.%d)\r\n",
               (unsigned int)version,
               (int)((version >> 16) & 0xFFFF),
               (int)((version >> 8) & 0xFF),
               (int)(version & 0xFF));
    xil_printf("  Link Speed    : %s (Status Reg: 0x%08X)\r\n",
               (speed == 2) ? "1000 Mbps (1G GMII)" :
               (speed == 1) ? "100 Mbps (MII)" : "10 Mbps (MII)",
               (unsigned int)status);

    if (ident != 0x494D4754 && ident != 0x54474D49) {
        xil_printf("  [WARN] Unexpected IP Identifier! Expected 'TGMI'\r\n");
    }

    /* Wait for CFG_BUSY (Bit 8) to clear */
    int timeout = 10000;
    while ((eth_mac_read(REG_ETH_STATUS) & 0x100) && --timeout > 0) {
        usleep(10);
    }
    if (timeout <= 0) {
        xil_printf("  [FAIL] MAC CSR Mailbox Busy timeout!\r\n");
        return false;
    }

    /* Configure MAC Parameters */
    eth_mac_write(REG_ETH_CTRL, 0x07);           /* TX_EN=1, RX_EN=1, PAD_EN=1 */
    eth_mac_write(REG_ETH_MIN_LEN, 64 - 1);      /* Min Length = 64 bytes */
    eth_mac_write(REG_ETH_TX_MAX_LEN, 1518 - 1); /* Standard MTU */
    eth_mac_write(REG_ETH_RX_MAX_LEN, 1518 - 1);
    eth_mac_write(REG_ETH_IFG, 12);              /* Standard Inter-Frame Gap */
    eth_mac_write(REG_ETH_IRQ_MASK, 0x00);       /* Polling mode: mask interrupts */

    /* Commit shadow registers via APPLY command */
    eth_mac_write(REG_ETH_APPLY, 0x01);

    timeout = 10000;
    while ((eth_mac_read(REG_ETH_STATUS) & 0x100) && --timeout > 0) {
        usleep(10);
    }
    if (timeout <= 0) {
        xil_printf("  [FAIL] MAC Configuration Apply timeout!\r\n");
        return false;
    }

    /* Clear hardware statistics counters */
    eth_mac_write(REG_ETH_COUNTER_CLR, 0x01);

    xil_printf("  [PASS] MAC Core Configured: TX/RX Enabled, Pad=64B, IFG=12\r\n\r\n");
    return true;
}

void eth_mac_dump_counters(void)
{
    xil_printf("\r\n--- [MAC Hardware Statistics Dump] ---\r\n");
    xil_printf("  TX Underflow   : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_UNDR));
    xil_printf("  TX Overflow    : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_OVFL));
    xil_printf("  TX Bad Frame   : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_BAD));
    xil_printf("  TX Good Frame  : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_GOOD));
    xil_printf("  TX Completion  : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_CPL));
    xil_printf("  RX Bad Frame   : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_RX_BAD_F));
    xil_printf("  RX Bad FCS     : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_RX_BAD_C));
    xil_printf("  RX Overflow    : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_RX_OVFL));
    xil_printf("  RX Drop Bad    : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_RX_BAD));
    xil_printf("  RX Good Frame  : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_RX_GOOD));
    xil_printf("--------------------------------------\r\n\r\n");
}

void eth_mac_clear_counters(void)
{
    eth_mac_write(REG_ETH_COUNTER_CLR, 1);
    xil_printf("  [COUNTERS] All hardware counters cleared to zero.\r\n");
}

uint32_t eth_mac_get_speed(void)
{
    return eth_mac_read(REG_ETH_STATUS) & 0x03;
}

uint32_t eth_mac_get_status(void)
{
    return eth_mac_read(REG_ETH_STATUS);
}

