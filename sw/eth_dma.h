#ifndef ETH_DMA_H
#define ETH_DMA_H

#include <stdint.h>
#include <stdbool.h>
#include "xil_types.h"
#include "xaxidma.h"

#ifndef DMA_DEV_ID
#define DMA_DEV_ID             XPAR_AXIDMA_0_DEVICE_ID
#endif

/* DDR4 Memory Allocation for DMA Buffers (4KB Aligned) */
#define DDR4_BASE_ADDR          0x80000000U
#define TX_BD_SPACE_BASE        (DDR4_BASE_ADDR + 0x00100000U)
#define TX_BD_SPACE_HIGH        (DDR4_BASE_ADDR + 0x00100FFFU)
#define RX_BUFFERS_NUM          32U
#define RX_BUF_SIZE             0x1000U /* 4KB per buffer */
#define RX_BD_SPACE_BASE        (DDR4_BASE_ADDR + 0x00102000U)
#define RX_BD_SPACE_HIGH        (RX_BD_SPACE_BASE + (RX_BUFFERS_NUM * XAXIDMA_BD_MINIMUM_ALIGNMENT) - 1U)
#define TX_BUFFER_BASE          (DDR4_BASE_ADDR + 0x00200000U)
#define RX_BUFFER_BASE          (DDR4_BASE_ADDR + 0x00300000U)

#define ETH_PKT_MIN_LEN         64U
#define TX_PIPE_DEPTH           16U
#define TX_BUF_SIZE             0x1000U /* 4KB per buffer */

int eth_dma_init(u16 dev_id);
int eth_dma_reset(void);
int eth_dma_transmit(const uint8_t *pkt, uint32_t len, const char *desc);
int eth_dma_poll_rx(void);
void eth_dma_dump_status(void);

XAxiDma* eth_dma_get_instance(void);
XAxiDma_BdRing* eth_dma_get_tx_ring(void);
XAxiDma_BdRing* eth_dma_get_rx_ring(void);
uint32_t eth_dma_get_tx_count(void);
uint32_t eth_dma_get_rx_count(void);
void eth_dma_inc_tx_count(uint32_t count);

#endif /* ETH_DMA_H */

