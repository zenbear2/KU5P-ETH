#include "eth_dma.h"
#include "eth_mac.h"
#include "packet_builder.h"

#include <stdio.h>
#include "xil_printf.h"
#include "xil_cache.h"
#include "sleep.h"

static XAxiDma AxiDma;
static volatile uint32_t g_total_rx_count = 0;
static volatile uint32_t g_total_tx_count = 0;

XAxiDma* eth_dma_get_instance(void)
{
    return &AxiDma;
}

XAxiDma_BdRing* eth_dma_get_tx_ring(void)
{
    return XAxiDma_GetTxRing(&AxiDma);
}

XAxiDma_BdRing* eth_dma_get_rx_ring(void)
{
    return XAxiDma_GetRxRing(&AxiDma);
}

uint32_t eth_dma_get_tx_count(void)
{
    return g_total_tx_count;
}

uint32_t eth_dma_get_rx_count(void)
{
    return g_total_rx_count;
}

void eth_dma_inc_tx_count(uint32_t count)
{
    g_total_tx_count += count;
}

int eth_dma_init(u16 dev_id)
{
    XAxiDma_Config *cfg;
    int status;
    XAxiDma_BdRing *tx_ring = XAxiDma_GetTxRing(&AxiDma);
    XAxiDma_BdRing *rx_ring = XAxiDma_GetRxRing(&AxiDma);
    XAxiDma_Bd bd_template;
    uint32_t bd_count;

    xil_printf("[DMA] Initializing AXI DMA Engine (DevID: %d)...\r\n", dev_id);
    cfg = XAxiDma_LookupConfig(dev_id);
    if (!cfg) {
        xil_printf("  [FAIL] XAxiDma_LookupConfig failed for ID %d\r\n", dev_id);
        return XST_FAILURE;
    }

    status = XAxiDma_CfgInitialize(&AxiDma, cfg);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] XAxiDma_CfgInitialize failed: %d\r\n", status);
        return status;
    }

    if (!XAxiDma_HasSg(&AxiDma)) {
        xil_printf("  [FAIL] AXI DMA not configured in Scatter-Gather mode!\r\n");
        return XST_FAILURE;
    }

    /*
     * Correct length bitmask for Scatter-Gather DMA:
     * Mask is (1U << Config->SgLengthWidth) - 1.
     */
    uint32_t len_mask = (1U << cfg->SgLengthWidth) - 1;
    tx_ring->MaxTransferLen = len_mask;
    rx_ring->MaxTransferLen = len_mask;

    xil_printf("  AXI DMA Base  : 0x%08X\r\n", (unsigned int)cfg->BaseAddr);
    xil_printf("  Operating Mode: %s\r\n", AxiDma.MicroDmaMode ? "Micro DMA (Low Footprint)" : "Standard SG DMA");
    xil_printf("  Length Bitmask: 0x%08X (Width: %d bits)\r\n", (unsigned int)len_mask, (int)cfg->SgLengthWidth);

    /* --- Setup TX BD Ring in DDR4 --- */
    XAxiDma_BdRingIntDisable(tx_ring, XAXIDMA_IRQ_ALL_MASK);
    XAxiDma_BdRingSetCoalesce(tx_ring, 1, 0);

    bd_count = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, TX_BD_SPACE_HIGH - TX_BD_SPACE_BASE + 1);
    status = XAxiDma_BdRingCreate(tx_ring, TX_BD_SPACE_BASE, TX_BD_SPACE_BASE, XAXIDMA_BD_MINIMUM_ALIGNMENT, bd_count);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdRingCreate failed: %d\r\n", status);
        return status;
    }

    XAxiDma_BdClear(&bd_template);
    status = XAxiDma_BdRingClone(tx_ring, &bd_template);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdRingClone failed: %d\r\n", status);
        return status;
    }

    status = XAxiDma_BdRingStart(tx_ring);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdRingStart failed: %d\r\n", status);
        return status;
    }

    /* --- Setup RX BD Ring in DDR4 --- */
    XAxiDma_BdRingIntDisable(rx_ring, XAXIDMA_IRQ_ALL_MASK);
    XAxiDma_BdRingSetCoalesce(rx_ring, 1, 0);

    bd_count = XAxiDma_BdRingCntCalc(XAXIDMA_BD_MINIMUM_ALIGNMENT, RX_BD_SPACE_HIGH - RX_BD_SPACE_BASE + 1);
    status = XAxiDma_BdRingCreate(rx_ring, RX_BD_SPACE_BASE, RX_BD_SPACE_BASE, XAXIDMA_BD_MINIMUM_ALIGNMENT, bd_count);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] RX BdRingCreate failed: %d\r\n", status);
        return status;
    }

    XAxiDma_BdClear(&bd_template);
    status = XAxiDma_BdRingClone(rx_ring, &bd_template);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] RX BdRingClone failed: %d\r\n", status);
        return status;
    }

    /* Allocate and replenish RX BDs */
    uint32_t free_rx_bds = XAxiDma_BdRingGetFreeCnt(rx_ring);
    if (free_rx_bds > RX_BUFFERS_NUM) free_rx_bds = RX_BUFFERS_NUM;

    XAxiDma_Bd *rx_bd_ptr, *cur_rx_bd;
    status = XAxiDma_BdRingAlloc(rx_ring, free_rx_bds, &rx_bd_ptr);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] RX BdRingAlloc failed: %d\r\n", status);
        return status;
    }

    cur_rx_bd = rx_bd_ptr;
    UINTPTR cur_buf = RX_BUFFER_BASE;
    for (uint32_t i = 0; i < free_rx_bds; i++) {
        if (AxiDma.MicroDmaMode) {
            status = XAxiDma_BdSetBufAddrMicroMode(cur_rx_bd, cur_buf);
        } else {
            status = XAxiDma_BdSetBufAddr(cur_rx_bd, cur_buf);
        }
        if (status != XST_SUCCESS) {
            xil_printf("  [FAIL] RX SetBufAddr failed on BD %d\r\n", (int)i);
            return status;
        }

        status = XAxiDma_BdSetLength(cur_rx_bd, RX_BUF_SIZE, rx_ring->MaxTransferLen);
        if (status != XST_SUCCESS) return status;

        XAxiDma_BdSetCtrl(cur_rx_bd, 0);
        XAxiDma_BdSetId(cur_rx_bd, cur_buf);

        cur_buf += RX_BUF_SIZE;
        cur_rx_bd = (XAxiDma_Bd *)XAxiDma_BdRingNext(rx_ring, cur_rx_bd);
    }

    status = XAxiDma_BdRingToHw(rx_ring, free_rx_bds, rx_bd_ptr);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] RX BdRingToHw failed: %d\r\n", status);
        return status;
    }

    status = XAxiDma_BdRingStart(rx_ring);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] RX BdRingStart failed: %d\r\n", status);
        return status;
    }

    xil_printf("  [PASS] AXI DMA Engine & BD Rings Configured! (RX BDs: %u)\r\n\r\n",
               (unsigned int)free_rx_bds);
    return XST_SUCCESS;
}

int eth_dma_reset(void)
{
    XAxiDma_Reset(&AxiDma);
    int rst_cnt = 20000;
    while (!XAxiDma_ResetIsDone(&AxiDma) && --rst_cnt > 0) {
        usleep(10);
    }
    if (rst_cnt <= 0) {
        return XST_FAILURE;
    }
    return eth_dma_init(DMA_DEV_ID);
}

int eth_dma_transmit(const uint8_t *pkt, uint32_t len, const char *desc)
{
    XAxiDma_BdRing *tx_ring = XAxiDma_GetTxRing(&AxiDma);
    XAxiDma_Bd *bd_ptr;
    int status;
    uint32_t tx_good_before, tx_good_after;
    uint32_t tx_cpl_before, tx_cpl_after;

    if (len > tx_ring->MaxTransferLen) {
        xil_printf("  [FAIL] Packet length %d exceeds MaxTransferLen %d\r\n",
                   (int)len, (int)tx_ring->MaxTransferLen);
        return XST_INVALID_PARAM;
    }

    tx_good_before = eth_mac_read(REG_ETH_CNT_TX_GOOD);
    tx_cpl_before  = eth_mac_read(REG_ETH_CNT_TX_CPL);

    /* Copy packet data to DDR4 TX buffer */
    volatile uint8_t *tx_buf = (volatile uint8_t *)TX_BUFFER_BASE;
    for (uint32_t b = 0; b < len; b++) {
        tx_buf[b] = pkt[b];
    }
    Xil_DCacheFlushRange((UINTPTR)TX_BUFFER_BASE, len);

    /* Allocate one TX BD */
    status = XAxiDma_BdRingAlloc(tx_ring, 1, &bd_ptr);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdRingAlloc failed: %d\r\n", status);
        return status;
    }

    if (AxiDma.MicroDmaMode) {
        status = XAxiDma_BdSetBufAddrMicroMode(bd_ptr, TX_BUFFER_BASE);
    } else {
        status = XAxiDma_BdSetBufAddr(bd_ptr, TX_BUFFER_BASE);
    }
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdSetBufAddr failed: %d\r\n", status);
        XAxiDma_BdRingUnAlloc(tx_ring, 1, bd_ptr);
        return status;
    }

    status = XAxiDma_BdSetLength(bd_ptr, len, tx_ring->MaxTransferLen);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdSetLength failed: %d\r\n", status);
        XAxiDma_BdRingUnAlloc(tx_ring, 1, bd_ptr);
        return status;
    }

    XAxiDma_BdSetCtrl(bd_ptr, XAXIDMA_BD_CTRL_TXEOF_MASK | XAXIDMA_BD_CTRL_TXSOF_MASK);
    XAxiDma_BdSetId(bd_ptr, TX_BUFFER_BASE);

    /* Push BD to DMA Hardware */
    status = XAxiDma_BdRingToHw(tx_ring, 1, bd_ptr);
    if (status != XST_SUCCESS) {
        xil_printf("  [FAIL] TX BdRingToHw failed: %d\r\n", status);
        XAxiDma_BdRingUnAlloc(tx_ring, 1, bd_ptr);
        return status;
    }

    /* Wait for DMA transfer completion */
    int processed = 0;
    int timeout = 500000;
    while ((processed = XAxiDma_BdRingFromHw(tx_ring, 1, &bd_ptr)) == 0 && --timeout > 0) {
    }

    if (timeout <= 0) {
        xil_printf("  [FAIL] TX DMA timed out waiting for hardware completion!\r\n");
        uint32_t cr = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_CR_OFFSET);
        uint32_t sr = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET);
        uint32_t cur = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_CDESC_OFFSET);
        uint32_t tail = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_TDESC_OFFSET);
        xil_printf("    [DIAG] MM2S_DMACR   : 0x%08X\r\n", (unsigned int)cr);
        xil_printf("    [DIAG] MM2S_DMASR   : 0x%08X (Halted=%d, Idle=%d, Err=%d)\r\n",
                   (unsigned int)sr, (int)(sr & 1), (int)((sr >> 1) & 1), (int)((sr >> 14) & 1));
        xil_printf("    [DIAG] MM2S_CURDESC : 0x%08X\r\n", (unsigned int)cur);
        xil_printf("    [DIAG] MM2S_TAILDESC: 0x%08X\r\n", (unsigned int)tail);
        xil_printf("    [DIAG] MAC STATUS   : 0x%08X (Speed=%u)\r\n",
                   (unsigned int)eth_mac_read(REG_ETH_STATUS), (unsigned int)(eth_mac_read(REG_ETH_STATUS) & 3));
        xil_printf("    [DIAG] MAC TX_GOOD  : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_GOOD));
        xil_printf("    [DIAG] MAC TX_CPL   : %u\r\n", (unsigned int)eth_mac_read(REG_ETH_CNT_TX_CPL));

        XAxiDma_Reset(&AxiDma);
        int rst_cnt = 10000;
        while (!XAxiDma_ResetIsDone(&AxiDma) && --rst_cnt > 0);
        XAxiDma_BdRingStart(tx_ring);

        return XST_FAILURE;
    }

    status = XAxiDma_BdRingFree(tx_ring, processed, bd_ptr);
    if (status != XST_SUCCESS) {
        xil_printf("  [WARN] TX BdRingFree failed: %d\r\n", status);
    }

    tx_good_after = eth_mac_read(REG_ETH_CNT_TX_GOOD);
    tx_cpl_after  = eth_mac_read(REG_ETH_CNT_TX_CPL);

    g_total_tx_count++;

    if (desc != NULL) {
        xil_printf("  [TX SUCCESS] %s (%d bytes sent)\r\n", desc, (int)len);
        xil_printf("    DMA Status    : Complete (processed %d BD)\r\n", processed);
        xil_printf("    MAC TX_GOOD   : %u -> %u (%s)\r\n",
                   (unsigned int)tx_good_before, (unsigned int)tx_good_after,
                   (tx_good_after > tx_good_before) ? "+1 PASS" : "SAME");
        xil_printf("    MAC TX_CPL    : %u -> %u\r\n",
                   (unsigned int)tx_cpl_before, (unsigned int)tx_cpl_after);
    }

    return XST_SUCCESS;
}

int eth_dma_poll_rx(void)
{
    XAxiDma_BdRing *rx_ring = XAxiDma_GetRxRing(&AxiDma);
    XAxiDma_Bd *bd_ptr, *cur_bd;
    int rx_count = XAxiDma_BdRingFromHw(rx_ring, XAXIDMA_ALL_BDS, &bd_ptr);

    if (rx_count <= 0) return 0;

    cur_bd = bd_ptr;
    for (int i = 0; i < rx_count; i++) {
        UINTPTR buf_addr = (UINTPTR)XAxiDma_BdGetId(cur_bd);
        uint32_t actual_len = XAxiDma_BdGetActualLength(cur_bd, rx_ring->MaxTransferLen);

        Xil_DCacheInvalidateRange(buf_addr, actual_len > 0 ? actual_len : 64);

        /* Automatic ARP & Ping Response */
        handle_rx_packet((const uint8_t *)buf_addr, actual_len);

        g_total_rx_count++;
        cur_bd = (XAxiDma_Bd *)XAxiDma_BdRingNext(rx_ring, cur_bd);
    }

    /* Free and replenish processed RX BDs back to hardware */
    XAxiDma_BdRingFree(rx_ring, rx_count, bd_ptr);

    XAxiDma_Bd *new_bd_ptr, *new_cur_bd;
    if (XAxiDma_BdRingAlloc(rx_ring, rx_count, &new_bd_ptr) == XST_SUCCESS) {
        new_cur_bd = new_bd_ptr;
        for (int i = 0; i < rx_count; i++) {
            uint32_t bd_idx = ((UINTPTR)new_cur_bd - RX_BD_SPACE_BASE) / XAXIDMA_BD_MINIMUM_ALIGNMENT;
            UINTPTR buf_addr = RX_BUFFER_BASE + (bd_idx * RX_BUF_SIZE);
            if (AxiDma.MicroDmaMode) {
                XAxiDma_BdSetBufAddrMicroMode(new_cur_bd, buf_addr);
            } else {
                XAxiDma_BdSetBufAddr(new_cur_bd, buf_addr);
            }
            XAxiDma_BdSetLength(new_cur_bd, RX_BUF_SIZE, rx_ring->MaxTransferLen);
            XAxiDma_BdSetCtrl(new_cur_bd, 0);
            XAxiDma_BdSetId(new_cur_bd, buf_addr);
            new_cur_bd = (XAxiDma_Bd *)XAxiDma_BdRingNext(rx_ring, new_cur_bd);
        }
        XAxiDma_BdRingToHw(rx_ring, rx_count, new_bd_ptr);
    }

    /* Check for S2MM errors and clear/restart if halted */
    uint32_t rx_sr = Xil_In32(AxiDma.RegBase + XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    if (rx_sr & XAXIDMA_ERR_ALL_MASK) {
        Xil_Out32(AxiDma.RegBase + XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET, rx_sr & XAXIDMA_ERR_ALL_MASK);
    }

    return rx_count;
}

void eth_dma_dump_status(void)
{
    uint32_t cr = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_CR_OFFSET);
    uint32_t sr = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_SR_OFFSET);
    uint32_t cur = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_CDESC_OFFSET);
    uint32_t tail = Xil_In32(AxiDma.RegBase + XAXIDMA_TX_OFFSET + XAXIDMA_TDESC_OFFSET);
    uint32_t rx_cr = Xil_In32(AxiDma.RegBase + XAXIDMA_RX_OFFSET + XAXIDMA_CR_OFFSET);
    uint32_t rx_sr = Xil_In32(AxiDma.RegBase + XAXIDMA_RX_OFFSET + XAXIDMA_SR_OFFSET);
    uint32_t rx_cur = Xil_In32(AxiDma.RegBase + XAXIDMA_RX_OFFSET + XAXIDMA_CDESC_OFFSET);

    xil_printf("\r\n--- [AXI DMA & MAC Hardware Status] ---\r\n");
    xil_printf("  MM2S (TX DMA) CR    : 0x%08X\r\n", (unsigned int)cr);
    xil_printf("  MM2S (TX DMA) SR    : 0x%08X (Halted=%d, Idle=%d, Err=%d)\r\n",
               (unsigned int)sr, (int)(sr & 1), (int)((sr >> 1) & 1), (int)((sr >> 14) & 1));
    xil_printf("  MM2S (TX DMA) CUR   : 0x%08X\r\n", (unsigned int)cur);
    xil_printf("  MM2S (TX DMA) TAIL  : 0x%08X\r\n", (unsigned int)tail);
    xil_printf("  S2MM (RX DMA) CR    : 0x%08X\r\n", (unsigned int)rx_cr);
    xil_printf("  S2MM (RX DMA) SR    : 0x%08X (Halted=%d, Idle=%d, Err=%d)\r\n",
               (unsigned int)rx_sr, (int)(rx_sr & 1), (int)((rx_sr >> 1) & 1), (int)((rx_sr >> 14) & 1));
    xil_printf("  S2MM (RX DMA) CUR   : 0x%08X\r\n", (unsigned int)rx_cur);
    xil_printf("  MAC Status Reg      : 0x%08X (Speed=%u)\r\n",
               (unsigned int)eth_mac_get_status(), (unsigned int)eth_mac_get_speed());
    xil_printf("  MAC Ctrl Reg        : 0x%08X\r\n", (unsigned int)eth_mac_read(REG_ETH_CTRL));
    xil_printf("  Software Counters   : TX_Sent=%u | RX_Recv=%u | Auto-ARP=%u | Auto-Ping=%u\r\n",
               (unsigned int)g_total_tx_count, (unsigned int)g_total_rx_count,
               (unsigned int)get_auto_arp_count(), (unsigned int)get_auto_ping_count());
    xil_printf("----------------------------------------\r\n\r\n");
}

