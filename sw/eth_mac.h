#ifndef ETH_MAC_H
#define ETH_MAC_H

#include <stdint.h>
#include <stdbool.h>
#include "xil_io.h"

#ifndef ETH_MAC_BASEADDR
#define ETH_MAC_BASEADDR        0x00020000U
#endif

/* MAC CSR Register Offsets */
#define REG_ETH_IDENT           0x000U
#define REG_ETH_VERSION         0x004U
#define REG_ETH_STATUS          0x008U
#define REG_ETH_APPLY           0x00CU
#define REG_ETH_CTRL            0x010U
#define REG_ETH_MIN_LEN         0x014U
#define REG_ETH_TX_MAX_LEN      0x018U
#define REG_ETH_RX_MAX_LEN      0x01CU
#define REG_ETH_IFG             0x020U
#define REG_ETH_IRQ_PENDING     0x024U
#define REG_ETH_IRQ_MASK        0x028U
#define REG_ETH_COUNTER_CLR     0x02CU

/* MAC Statistics Counters */
#define REG_ETH_CNT_TX_UNDR     0x040U
#define REG_ETH_CNT_TX_OVFL     0x044U
#define REG_ETH_CNT_TX_BAD      0x048U
#define REG_ETH_CNT_TX_GOOD     0x04CU
#define REG_ETH_CNT_RX_BAD_F    0x050U
#define REG_ETH_CNT_RX_BAD_C    0x054U
#define REG_ETH_CNT_RX_OVFL     0x058U
#define REG_ETH_CNT_RX_BAD      0x05CU
#define REG_ETH_CNT_RX_GOOD     0x060U
#define REG_ETH_CNT_TX_CPL      0x064U

static inline uint32_t eth_mac_read(uint32_t offset)
{
    return Xil_In32(ETH_MAC_BASEADDR + offset);
}

static inline void eth_mac_write(uint32_t offset, uint32_t val)
{
    Xil_Out32(ETH_MAC_BASEADDR + offset, val);
}

bool eth_mac_init(uint32_t base_addr);
void eth_mac_dump_counters(void);
void eth_mac_clear_counters(void);
uint32_t eth_mac_get_speed(void);
uint32_t eth_mac_get_status(void);

#endif /* ETH_MAC_H */

