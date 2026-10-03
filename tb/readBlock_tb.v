`timescale 1ns/1ps
module readBlock_tb;
    reg clk = 0, reset_n = 0;
    always #5 clk = ~clk;

    reg [31:0] srcAddr_i;
    reg [15:0] dataSize_i;
    reg intrClr_i, blockStart_i, rDone_i;
    wire [31:0] rAddr_o;
    wire arStart_o, readBlockDone_o;

    readBlock dut (
        .clk(clk), .reset_n(reset_n),
        .srcAddr_i(srcAddr_i), .dataSize_i(dataSize_i),
        .intrClr_i(intrClr_i), .blockStart_i(blockStart_i), .rDone_i(rDone_i),
        .rAddr_o(rAddr_o), .arStart_o(arStart_o), .readBlockDone_o(readBlockDone_o)
    );

    // arStart_o가 뜬 cyc의 rAddr_o 출력
    always @(posedge clk)
        if (arStart_o) $display("[%0t] arStart_o=1  rAddr_o=%h", $time, rAddr_o);

    // arStart_o 후 3cyc 뒤에 rDone_i 1cyc
    always @(posedge clk) begin
        rDone_i <= 1'b0;
        if (arStart_o) begin
            repeat (3) @(posedge clk);
            rDone_i <= 1'b1;
        end
    end

    initial begin
        srcAddr_i = 32'h1000_0000; dataSize_i = 16'd16;
        intrClr_i = 0; blockStart_i = 0; rDone_i = 0;
        #22 reset_n = 1;
        #20 blockStart_i = 1; #10 blockStart_i = 0;
        wait (readBlockDone_o);
        $display("readBlockDone_o=1 (기대: AR 4회, 주소 10000000/04/08/0C)");
        #20 intrClr_i = 1; #10 intrClr_i = 0;
        #30 $finish;
    end
endmodule