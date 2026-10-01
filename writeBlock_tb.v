`timescale 1ns/1ps
module writeBlock_tb;
    reg clk = 0, reset_n = 0;
    always #5 clk = ~clk;

    reg [31:0] dstAddr_i;
    reg [15:0] dataSize_i;
    reg intrClr_i, blockStart_i, bDone_i;
    wire [31:0] wAddr_o;
    wire wStart_o, writeBlockDone_o;

    writeBlock dut (
        .clk(clk), .reset_n(reset_n),
        .dstAddr_i(dstAddr_i), .dataSize_i(dataSize_i),
        .intrClr_i(intrClr_i), .blockStart_i(blockStart_i), .bDone_i(bDone_i),
        .wAddr_o(wAddr_o), .awStart_o(awStart_o), .writeBlockDone_o(writeBlockDone_o)
    );

    // awStart_o가 뜬 cyc의 wAddr_o 출력
    always @(posedge clk)
        if (awStart_o) $display("[%0t] awStart_o=1  wAddr_o=%h", $time, wAddr_o);

    // awStart_o 후 3cyc -> bDone_i 1cyc
    always @(posedge clk) begin
        bDone_i <= 1'b0;
        if (awStart_o) begin
            repeat (3) @(posedge clk);
            bDone_i <= 1'b1;
        end
    end

    initial begin
        dstAddr_i = 32'h2000_0000; dataSize_i = 16'd16;
        intrClr_i = 0; blockStart_i = 0; bDone_i = 0;
        #22 reset_n = 1;
        #20 blockStart_i = 1; #10 blockStart_i = 0;
        wait (writeBlockDone_o);
        $display("writeBlockDone_o=1 (기대: AW 4회, 주소 20000000/04/08/0C)");
        #20 intrClr_i = 1; #10 intrClr_i = 0;
        #30 $finish;
    end
endmodule