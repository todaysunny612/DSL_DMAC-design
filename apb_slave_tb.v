`timescale 1ns/1ps
module tb_apb_slave;
    reg pclk = 0, reset_n = 0;
    reg [31:0] paddr = 0, pwdata = 0;
    reg psel = 0, penable = 0, pwrite = 0;
    reg [1:0] coreState_i = 2'b00;
    reg intr_i = 0;

    wire pready;
    wire [31:0] prdata;
    wire [15:0] dataSize_o;
    wire [31:0] srcAddr_o, dstAddr_o;
    wire intrEn_o, intrClr_o, start_o;

    apb_slave dut (
        .pclk(pclk), .reset_n(reset_n),
        .paddr(paddr), .penable(penable), .psel(psel), .pwrite(pwrite),
        .pwdata(pwdata), .pready(pready), .prdata(prdata),
        .coreState_i(coreState_i), .intr_i(intr_i),
        .dataSize_o(dataSize_o), .srcAddr_o(srcAddr_o), .dstAddr_o(dstAddr_o),
        .intrEn_o(intrEn_o), .intrClr_o(intrClr_o), .start_o(start_o)
    );

    always #5 pclk = ~pclk;

    integer err = 0;
    integer start_cnt = 0, clr_cnt = 0;
    reg [31:0] rd;

    // 펄스 개수 카운트
    always @(posedge pclk) begin
        if (start_o)   start_cnt = start_cnt + 1;
        if (intrClr_o) clr_cnt   = clr_cnt + 1;
    end

    task check32(input [255:0] name, input [31:0] got, input [31:0] exp);
        begin
            if (got !== exp) begin
                err = err + 1;
                $display("FAIL %0s : got=%h exp=%h", name, got, exp);
            end else
                $display("ok   %0s : %h", name, got);
        end
    endtask

    // APB write: setup(psel=1,penable=0) -> access(penable=1)
    task apb_write(input [31:0] a, input [31:0] d);
        begin
            @(posedge pclk); #1; psel = 1; penable = 0; pwrite = 1; paddr = a; pwdata = d;
            #5; if (pready !== 1'b0) begin err = err + 1; $display("FAIL pready must be 0 in setup phase"); end
            @(posedge pclk); #1; penable = 1;
            #5; if (pready !== 1'b1) begin err = err + 1; $display("FAIL pready must be 1 in access phase"); end
            @(posedge pclk); #1; psel = 0; penable = 0; pwrite = 0;
        end
    endtask

    task apb_read(input [31:0] a, output [31:0] d);
        begin
            @(posedge pclk); #1; psel = 1; penable = 0; pwrite = 0; paddr = a;
            @(posedge pclk); #1; penable = 1;
            #5; d = prdata;
            @(posedge pclk); #1; psel = 0; penable = 0;
        end
    endtask

    initial begin
        #22 reset_n = 1;
        repeat (2) @(posedge pclk);

        // 1. reset 값
        apb_read(32'h00, rd); check32("reset srcAddr", rd, 32'h0);
        apb_read(32'h04, rd); check32("reset dstAddr",rd, 32'h0);
        apb_read(32'h08, rd); check32("reset dataSize", rd, 32'h0);
        apb_read(32'h0C, rd); check32("reset CTRL", rd, 32'h0);

        // 쓰기 -> 읽기 -> 출력 포트
        apb_write(32'h00, 32'h1000_0000);
        apb_write(32'h04, 32'h2000_0000);
        apb_write(32'h08, 32'hFFFF_0040);   // 상위 16비트는 잘려야 함
        apb_read(32'h00, rd); check32("srcAddr rb", rd, 32'h1000_0000);
        apb_read(32'h04, rd); check32("dstAddr rb", rd, 32'h2000_0000);
        apb_read(32'h08, rd); check32("dataSize rb", rd, 32'h0000_0040);
        check32("srcAddr_o",  srcAddr_o,32 'h1000_0000);
        check32("dstAddr_o",  dstAddr_o, 32'h2000_0000);
        check32("dataSize_o", {16'd0, dataSize_o}, 32'h40);

        // CTRL: intrEn만 설정 (start/clr 펄스 없어야 함)
        apb_write(32'h0C, 32'h4);
        repeat (3) @(posedge pclk);
        check32("intrEn_o", intrEn_o,  1);
        check32("start_cnt (=0)", start_cnt, 0);
        check32("clr_cnt (=0)", clr_cnt,   0);
        apb_read(32'h0C, rd); check32("CTRL rb", rd, 32'h4);

        // start 펄스 (1 cycle, 1회)
        apb_write(32'h0C, 32'h5);
        repeat (4) @(posedge pclk);
        check32("start_cnt (=1)", start_cnt, 1);
        check32("start_o idle", start_o,   0);

        // intrClr 펄스 (1회), intrEn은 bit2 값으로 갱신됨
        apb_write(32'h0C, 32'h6);
        repeat (4) @(posedge pclk);
        check32("clr_cnt (=1)", clr_cnt,   1);
        check32("start_cnt (=1)", start_cnt, 1);
        check32("intrEn_o stays", intrEn_o,  1);

        // intrEn 끄기
        apb_write(32'h0C, 32'h0);
        repeat (2) @(posedge pclk);
        check32("intrEn_o off", intrEn_o, 0);

        // STATUS 읽기: coreState=2'b10, intr=1 -> 3'b110
        coreState_i = 2'b10; intr_i = 1'b1;
        apb_read(32'h10, rd); check32("STATUS", rd, 32'h6);

        // 연속 쓰기 (back-to-back)
        apb_write(32'h00, 32'hAAAA_0001);
        apb_write(32'h00, 32'hBBBB_0002);
        apb_read(32'h00, rd); check32("back-to-back", rd, 32'hBBBB_0002);

        // 읽기는 레지스터를 바꾸지 않아야 함
        apb_read(32'h04, rd); check32("dstAddr unchanged", rd, 32'h2000_0000);

        // 비동기 reset
        #3 reset_n = 0; #3 reset_n = 1;
        apb_read(32'h00, rd); check32("srcAddr after reset", rd, 32'h0);

        if (err == 0) $display("=== PASS : apb_slave ===");
        else $display("=== FAIL : %0d error(s) ===", err);
        $finish;
    end
endmodule