`timescale 1ns/1ps
module axi_master_tb;

    reg clk, reset_n;

    reg [31:0] rAddr_i, wAddr_i;
    reg arStart_i, awStart_i;
    wire rDone_o, bDone_o, wDone_o;
    reg full_i, empty_i;
    wire [31:0] rData_o;
    reg [31:0] wData_i;

    wire AWID;    
    wire [31:0] AWADDR;
    wire [7:0] AWLEN;
    wire [2:0] AWSIZE;
    wire [1:0] AWBURST;
    wire AWVALID; 
    reg AWREADY;
    wire [31:0] WDATA;
    wire [3:0] WSTRB;
    wire WLAST;
    wire WVALID;
    reg WREADY;
    reg BID;
    reg BVALID;
    wire BREADY;
    wire ARID;
    wire [31:0] ARADDR;
    wire [7:0] ARLEN;
    wire [2:0] ARSIZE;
    wire [1:0] ARBURST;
    wire ARVALID; 
    reg ARREADY;
    reg RID;
    reg [31:0] RDATA;
    reg RLAST;
    reg RVALID;
    wire RREADY;

    integer errors;

    axi_master dut (
        .clk(clk), .reset_n(reset_n),
        .rAddr_i(rAddr_i), .arStart_i(arStart_i), .rDone_o(rDone_o),
        .wAddr_i(wAddr_i), .awStart_i(awStart_i), .bDone_o(bDone_o),
        .full_i(full_i), .empty_i(empty_i), .rData_o(rData_o),
        .wData_i(wData_i), .wDone_o(wDone_o),
        .AWID(AWID), .AWADDR(AWADDR), .AWLEN(AWLEN), .AWSIZE(AWSIZE), .AWBURST(AWBURST),
        .AWVALID(AWVALID), .AWREADY(AWREADY),
        .WDATA(WDATA), .WSTRB(WSTRB), .WLAST(WLAST), .WVALID(WVALID), .WREADY(WREADY),
        .BID(BID), .BVALID(BVALID), .BREADY(BREADY),
        .ARID(ARID), .ARADDR(ARADDR), .ARLEN(ARLEN), .ARSIZE(ARSIZE), .ARBURST(ARBURST),
        .ARVALID(ARVALID), .ARREADY(ARREADY),
        .RID(RID), .RDATA(RDATA), .RLAST(RLAST), .RVALID(RVALID), .RREADY(RREADY)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check(input [511:0] name, input cond);
        begin
            if (cond) $display("ok   : %0s", name);
            else begin
                $display("FAIL : %0s", name);
                errors = errors + 1;
            end
        end
    endtask

    task pulse_ar;  begin @(negedge clk); arStart_i = 1; @(negedge clk); arStart_i = 0; end endtask
    task pulse_aw;  begin @(negedge clk); awStart_i = 1; @(negedge clk); awStart_i = 0; end endtask

    // AR: 3ck 뒤 ARREADY, 이후 2클럭 뒤 RVALID 및 RREADY 올 때까지 유지
    reg [31:0] rd_addr_seen;
    initial begin
        ARREADY = 0; RVALID = 0; RDATA = 0; RLAST = 0; RID = 0;
        forever begin
            @(posedge clk);
            if (ARVALID && !ARREADY) begin
                repeat (2) @(posedge clk);
                #1 ARREADY = 1;
                rd_addr_seen = ARADDR;
                @(posedge clk); #1 ARREADY = 0;
                repeat (2) @(posedge clk);
                #1 RVALID = 1; RLAST = 1; RDATA = ~rd_addr_seen;
                @(posedge clk);
                while (!RREADY) @(posedge clk);
                #1 RVALID = 0; RLAST = 0;
            end
        end
    end

    // AW/W 각각 독립적으로 ready, 둘 다 받으면 B 응답
    reg aw_got, w_got;
    reg [31:0] aw_addr_seen, w_data_seen;
    initial begin
        AWREADY = 0; WREADY = 0; BVALID = 0; BID = 0; aw_got = 0; w_got = 0;
        forever begin
            @(posedge clk);
            if (AWVALID && !AWREADY && !aw_got) begin
                repeat (3) @(posedge clk);
                #1 AWREADY = 1; aw_addr_seen = AWADDR;
                @(posedge clk); #1 AWREADY = 0; aw_got = 1;
            end
        end
    end
    initial begin
        forever begin
            @(posedge clk);
            if (WVALID && !WREADY && !w_got) begin
                repeat (5) @(posedge clk);
                #1 WREADY = 1; w_data_seen = WDATA;
                @(posedge clk); #1 WREADY = 0; w_got = 1;
            end
        end
    end
    initial begin
        forever begin
            @(posedge clk);
            if (aw_got && w_got) begin
                repeat (2) @(posedge clk);
                #1 BVALID = 1;
                @(posedge clk);
                while (!BREADY) @(posedge clk);
                #1 BVALID = 0; aw_got = 0; w_got = 0;
            end
        end
    end

    integer cnt_rDone, cnt_wDone, cnt_bDone;
    always @(posedge clk) begin
        if (rDone_o) cnt_rDone = cnt_rDone + 1;
        if (wDone_o) cnt_wDone = cnt_wDone + 1;
        if (bDone_o) cnt_bDone = cnt_bDone + 1;
    end

    initial begin
        errors = 0; cnt_rDone = 0; cnt_wDone = 0; cnt_bDone = 0;
        reset_n = 0; rAddr_i = 0; wAddr_i = 0; arStart_i = 0; awStart_i = 0;
        full_i = 0; empty_i = 1; wData_i = 0;
        #22 reset_n = 1;
        repeat (2) @(negedge clk);

        // 고정 신호
        check("AxLEN=0, AxSIZE=2, AxBURST=0", AWLEN==0 && ARLEN==0 && AWSIZE==2 && ARSIZE==2 && AWBURST==0 && ARBURST==0);
        check("WSTRB=F", WSTRB == 4'hF);

        // Read 1, buffer not full
        rAddr_i = 32'h1000_0000;
        pulse_ar;
        wait (rDone_o);
        check("read: ARADDR was 10000000", rd_addr_seen == 32'h1000_0000);
        check("read: rData_o == ~addr", rData_o == ~32'h1000_0000);
        @(posedge clk); #2;
        check("read: rDone_o is 1-cycle pulse", rDone_o == 0);
        check("read: cnt_rDone == 1", cnt_rDone == 1);

        // Read 2, buffer FULL ->  R_WAIT에서 대기, full 해제 후 rDone 
        full_i = 1; rAddr_i = 32'h1000_0004;
        pulse_ar;
        repeat (15) @(posedge clk);
        check("read(full): rDone_o stays 0 while full_i", cnt_rDone == 1);
        check("read(full): RREADY stays 0 while full_i", RREADY == 0);
        @(negedge clk); full_i = 0;
        wait (rDone_o);
        @(posedge clk); #2;
        check("read(full): rDone after full released (cnt==2)", cnt_rDone == 2);
        check("read(full): rData_o == ~addr", rData_o == ~32'h1000_0004);
        repeat (3) @(negedge clk);

        // Write 1, buffer not empty
        empty_i = 0; wData_i = 32'hCAFE_0001; wAddr_i = 32'h2000_0000;
        pulse_aw;
        wait (bDone_o);
        check("write: AWADDR was 20000000", aw_addr_seen == 32'h2000_0000);
        check("write: WDATA was CAFE0001",  w_data_seen  == 32'hCAFE_0001);
        @(posedge clk); #2;
        check("write: wDone_o count == 1", cnt_wDone == 1);
        check("write: bDone_o is 1-cycle pulse", bDone_o == 0);
        repeat (3) @(negedge clk);

        // Write 2, buffer EMPTY이면 W_WAIT에서 대기
        empty_i = 1; wData_i = 32'hCAFE_0002; wAddr_i = 32'h2000_0004;
        pulse_aw;
        repeat (15) @(posedge clk);
        check("write(empty): WVALID stays 0 while empty_i", WVALID == 0);
        check("write(empty): wDone not yet", cnt_wDone == 1);
        @(negedge clk); empty_i = 0;
        wait (bDone_o);
        @(posedge clk); #2;
        check("write(empty): AWADDR was 20000004", aw_addr_seen == 32'h2000_0004);
        check("write(empty): WDATA was CAFE0002",  w_data_seen  == 32'hCAFE_0002);
        check("write(empty): cnt_wDone == 2, cnt_bDone == 2", cnt_wDone == 2 && cnt_bDone == 2);

        repeat (5) @(negedge clk);
        if (errors == 0) $display("=== PASS : axi_master ===");
        else             $display("=== FAIL : axi_master (errors=%0d) ===", errors);
        $finish;
    end

    initial begin
        #20000 $display("TIMEOUT"); $finish;
    end

endmodule