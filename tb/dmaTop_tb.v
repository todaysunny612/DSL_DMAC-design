`timescale 1ns/1ps
// APB -> start -> AXI slave memory model and DMA copy
module dmaTop_tb;

    reg clk, reset_n;
    reg [31:0] paddr, pwdata;
    reg penable, psel, pwrite;
    wire pready, intr_o;
    wire [31:0] prdata;

    wire AWID, WLAST, WVALID, BREADY, ARID, ARVALID, RREADY, AWVALID;
    wire [31:0] AWADDR, WDATA, ARADDR;
    wire [3:0] WSTRB;
    wire [7:0] AWLEN, ARLEN;
    wire [2:0] AWSIZE, ARSIZE;
    wire [1:0] AWBURST, ARBURST;
    reg AWREADY, WREADY, BVALID, ARREADY, RVALID, RLAST;
    reg [31:0] RDATA;

    dmaTop dut (
        .clk(clk), .reset_n(reset_n),
        .paddr(paddr), .penable(penable), .psel(psel), .pwrite(pwrite), .pwdata(pwdata),
        .pready(pready), .prdata(prdata), .intr_o(intr_o),
        .AWID(AWID), .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE), .AWBURST(AWBURST),
        .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST), .WVALID(WVALID), .WREADY(WREADY),
        .BID(1'b0), .BVALID(BVALID), .BREADY(BREADY),
        .ARID(ARID), .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE), .ARBURST(ARBURST),
        .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RID(1'b0), .RDATA(RDATA), .RLAST(RLAST), .RVALID(RVALID), .RREADY(RREADY)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // AXI slave memory
    reg [31:0] mem [0:255];
    integer i;

    // AR/R
    reg [31:0] ra; reg rpend; integer rwait;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            ARREADY <= 0; RVALID <= 0; RLAST <= 0; RDATA <= 0; rpend <= 0; rwait <= 0; ra <= 0;
        end else begin
            ARREADY <= ARVALID && !ARREADY;
            if (ARVALID && ARREADY) begin ra <= ARADDR; rpend <= 1; rwait <= 2; end
            if (rpend) begin
                if (rwait > 0) rwait <= rwait - 1;
                else begin RVALID <= 1; RLAST <= 1; RDATA <= mem[ra[9:2]]; rpend <= 0; end
            end
            if (RVALID && RREADY) begin RVALID <= 0; RLAST <= 0; end
        end
    end

    // AW/W/B
    reg awg, wg, bp; reg [31:0] wa, wd; integer bwait;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            AWREADY <= 0; WREADY <= 0; BVALID <= 0; awg <= 0; wg <= 0; bp <= 0; bwait <= 0; wa <= 0; wd <= 0;
        end else begin
            AWREADY <= AWVALID && !AWREADY && !awg;
            WREADY  <= WVALID  && !WREADY  && !wg;
            if (AWVALID && AWREADY) begin awg <= 1; wa <= AWADDR; end
            if (WVALID  && WREADY ) begin wg  <= 1; wd <= WDATA;  end
            if (awg && wg && !bp && !BVALID) begin
                mem[wa[9:2]] <= wd; bp <= 1; bwait <= 2;
            end
            if (bp) begin
                if (bwait > 0) bwait <= bwait - 1;
                else begin BVALID <= 1; bp <= 0; end
            end
            if (BVALID && BREADY) begin BVALID <= 0; awg <= 0; wg <= 0; end
        end
    end

    // APB write task 
    task apb_write(input [31:0] a, input [31:0] d);
        begin
            @(negedge clk); paddr = a; pwdata = d; pwrite = 1; psel = 1; penable = 0;
            @(negedge clk); penable = 1;
            @(negedge clk); psel = 0; penable = 0; pwrite = 0;
        end
    endtask

    integer errors;
    integer n;
    localparam SRC = 32'h0000_0000;
    localparam DST = 32'h0000_0100; // word index 64
    localparam NBYTES = 16; // 4 word

    initial begin
        errors = 0;
        reset_n = 0; paddr = 0; pwdata = 0; penable = 0; psel = 0; pwrite = 0;
        for (i = 0; i < 256; i = i + 1) mem[i] = 32'hA000_0000 + i;
        for (i = 64; i < 80; i = i + 1) mem[i] = 32'hDEAD_BEEF; // dst 영역 초기화
        #22 reset_n = 1;
        repeat (2) @(negedge clk);

        // 레지스터 설정: srcAddr, dstAddr, dataSize, intrEn, start
        apb_write(32'h00, SRC);
        apb_write(32'h04, DST);
        apb_write(32'h08, NBYTES);
        apb_write(32'h0C, 32'h4); // intrEn=1
        apb_write(32'h0C, 32'h5); // intrEn=1, start=1

        wait (intr_o);
        repeat (2) @(negedge clk);

        // 결과 비교
        for (n = 0; n < NBYTES/4; n = n + 1) begin
            if (mem[64+n] === mem[n]) $display("ok : dst[%0d] = %h", n, mem[64+n]);
            else begin
                $display("FAIL : dst[%0d] = %h (expected %h)", n, mem[64+n], mem[n]);
                errors = errors + 1;
            end
        end
        if (mem[64+NBYTES/4] === 32'hDEAD_BEEF) $display("ok : dst 범위 밖은 변하지 않음");
        else begin $display("FAIL : dst 범위 밖 overwrite"); errors = errors + 1; end

        // intr clear -> IDLE 복귀
        apb_write(32'h0C, 32'h6); // intrClr=1, intrEn=1
        repeat (3) @(negedge clk);
        if (intr_o === 1'b0) $display("ok : intr cleared");
        else begin $display("FAIL : intr not cleared"); errors = errors + 1; end

        if (errors == 0) $display("=== PASS : dmaTop (copy %0d bytes) ===", NBYTES);
        else $display("=== FAIL : dmaTop (errors=%0d) ===", errors);
        $finish;
    end

    initial begin
        #100000 $display("TIMEOUT"); $finish;
    end

endmodule