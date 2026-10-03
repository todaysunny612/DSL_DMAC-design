// DMAC top: APB slave + AXI master
module dmaTop (
    input wire clk,
    input wire reset_n,

    // APB slave
    input wire [31:0] paddr,
    input wire penable,
    input wire psel,
    input wire pwrite,
    input wire [31:0] pwdata,
    output wire pready,
    output wire [31:0] prdata,
    output wire intr_o,

    // AXI AW
    output wire AWID,
    output wire [31:0] AWADDR,
    output wire [7:0] AWLEN,
    output wire [2:0] AWSIZE,
    output wire [1:0] AWBURST,
    output wire AWVALID,
    input  wire AWREADY,
    // AXI W
    output wire [31:0] WDATA,
    output wire [3:0] WSTRB,
    output wire WLAST,
    output wire WVALID,
    input  wire WREADY,
    // AXI B
    input wire BID,
    input wire BVALID,
    output wire BREADY,
    // AXI AR
    output wire ARID,
    output wire [31:0] ARADDR,
    output wire [7:0] ARLEN,
    output wire [2:0] ARSIZE,
    output wire [1:0] ARBURST,
    output wire ARVALID,
    input wire ARREADY,
    // AXI R
    input wire  RID,
    input wire [31:0] RDATA,
    input wire RLAST,
    input wire RVALID,
    output wire RREADY
);
    wire [15:0] dataSize;
    wire [31:0] srcAddr, dstAddr;
    wire        intrEn, intrClr, start;
    wire        blockStart, readBlockDone, writeBlockDone;
    wire [1:0]  coreState;
    wire        intr;

    // readBlock / writeBlock <-> axi_master
    wire [31:0] rAddr, wAddr;
    wire        arStart, awStart;
    wire        rDone, bDone, wDone;
    // data buffer <-> axi_master
    wire [31:0] rData, wData;
    wire        full, empty;

    apb_slave u_apb (
        .pclk(clk), .reset_n(reset_n),
        .paddr(paddr), .penable(penable), .psel(psel), .pwrite(pwrite),
        .pwdata(pwdata), .pready(pready), .prdata(prdata),
        .coreState_i(coreState), .intr_i(intr),
        .dataSize_o(dataSize), .srcAddr_o(srcAddr), .dstAddr_o(dstAddr),
        .intrEn_o(intrEn), .intrClr_o(intrClr), .start_o(start)
    );

    dmaCore u_core (
        .clk(clk), .reset_n(reset_n),
        .start_i(start), .intrClr_i(intrClr), .intrEn_i(intrEn),
        .readBlockDone_i(readBlockDone), .writeBlockDone_i(writeBlockDone),
        .blockStart_o(blockStart), .coreState_o(coreState), .intr_o(intr)
    );

    readBlock u_rd (
        .clk(clk), .reset_n(reset_n),
        .srcAddr_i(srcAddr), .dataSize_i(dataSize),
        .intrClr_i(intrClr), .blockStart_i(blockStart), .rDone_i(rDone),
        .rAddr_o(rAddr), .arStart_o(arStart), .readBlockDone_o(readBlockDone)
    );

    writeBlock u_wr (
        .clk(clk), .reset_n(reset_n),
        .dstAddr_i(dstAddr), .dataSize_i(dataSize),
        .intrClr_i(intrClr), .blockStart_i(blockStart), .bDone_i(bDone),
        .wAddr_o(wAddr), .awStart_o(awStart), .writeBlockDone_o(writeBlockDone)
    );

    dataBuffer u_buf (
        .clk(clk), .reset_n(reset_n),
        .rData_i(rData), .rDone_i(rDone), .wDone_i(wDone),
        .wData_o(wData), .full_o(full), .empty_o(empty)
    );

    axi_master u_axi (
        .clk(clk), .reset_n(reset_n),
        .rAddr_i(rAddr), .arStart_i(arStart), .rDone_o(rDone),
        .wAddr_i(wAddr), .awStart_i(awStart), .bDone_o(bDone),
        .full_i(full), .empty_i(empty), .rData_o(rData),
        .wData_i(wData), .wDone_o(wDone),
        .AWID(AWID), .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE), .AWBURST(AWBURST),
        .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST), .WVALID(WVALID), .WREADY(WREADY),
        .BID(BID), .BVALID(BVALID), .BREADY(BREADY),
        .ARID(ARID), .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE), .ARBURST(ARBURST),
        .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RID(RID), .RDATA(RDATA), .RLAST(RLAST), .RVALID(RVALID), .RREADY(RREADY)
    );

    assign intr_o = intr;
endmodule