`timescale 1ns/1ps

module dataBuffer_tb;

    reg clk;
    reg reset_n;
    reg [31:0] rData_i;
    reg rDone_i;
    reg wDone_i;
    wire [31:0] wData_o;
    wire full_o;
    wire empty_o;
    integer errors;

    dataBuffer dut (
        .clk (clk),
        .reset_n (reset_n),
        .rData_i (rData_i),
        .rDone_i (rDone_i),
        .wDone_i (wDone_i),
        .wData_o (wData_o),
        .full_o  (full_o),
        .empty_o (empty_o)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    task check(input [511:0] name, input cond);
        begin
            if (cond) $display("ok   : %0s", name);
            else begin
                $display("FAIL : %0s  (wData=%h full=%b empty=%b)", name, wData_o, full_o, empty_o);
                errors = errors + 1;
            end
        end
    endtask

    // 1클럭 pulse 입력
    // negedge에 인가 ->  race
    task push(input [31:0] d);
        begin
            @(negedge clk); rData_i = d; rDone_i = 1'b1;
            @(negedge clk); rDone_i = 1'b0; rData_i = 32'd0;
        end
    endtask

    task pop;
        begin
            @(negedge clk); wDone_i = 1'b1;
            @(negedge clk); wDone_i = 1'b0;
        end
    endtask

    initial begin
        errors = 0;
        reset_n = 1'b0;
        rData_i = 32'd0;
        rDone_i = 1'b0;
        wDone_i = 1'b0;

        #22 reset_n = 1'b1;
        @(negedge clk);

        // reset 직후: EMPTY
        check("reset -> EMPTY", empty_o && !full_o);

        // rDone_i -> 저장, FULL
        push(32'hAAAA_0001);
        check("push AAAA0001 -> FULL", full_o && !empty_o);
        check("wData_o == AAAA0001",   wData_o == 32'hAAAA_0001);

        // FULL 상태에서 rDone_i
        push(32'hBBBB_0002);
        check("FULL: 2nd push ignored (old data kept)", wData_o == 32'hAAAA_0001);
        check("still FULL", full_o && !empty_o);

        // wDone_i -> EMPTY
        pop;
        check("pop -> EMPTY", empty_o && !full_o);

        // EMPTY 상태에서 wDone_i
        pop;
        check("EMPTY: wDone_i ignored", empty_o && !full_o);

        // push/pop
        push(32'hCCCC_0003);
        check("push CCCC0003", full_o && wData_o == 32'hCCCC_0003);
        pop;
        check("pop -> EMPTY again", empty_o);

        // rDone_i, wDone_i 동시
        @(negedge clk); rData_i = 32'hDDDD_0004; rDone_i = 1'b1; wDone_i = 1'b1;
        @(negedge clk); rDone_i = 1'b0; wDone_i = 1'b0;
        check("EMPTY + rDone&wDone -> FULL w/ DDDD0004", full_o && wData_o == 32'hDDDD_0004);

        // 연속 rDone_i 2클럭
        pop;
        @(negedge clk); rData_i = 32'h1111_1111; rDone_i = 1'b1;
        @(negedge clk); rData_i = 32'h2222_2222;
        @(negedge clk); rDone_i = 1'b0;
        check("back-to-back: first data kept, second dropped", wData_o == 32'h1111_1111);

        #20;
        if (errors == 0) $display("=== PASS : dataBuffer ===");
        else             $display("=== FAIL : dataBuffer (errors=%0d) ===", errors);
        $finish;
    end

endmodule