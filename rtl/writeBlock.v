module writeBlock (
    input wire clk,
    input wire reset_n,

    input wire [31:0] dstAddr_i,
    input wire [15:0] dataSize_i,
    input wire intrClr_i,
    input wire blockStart_i,
    input wire bDone_i,

    output reg [31:0] wAddr_o,
    output reg awStart_o,
    output reg writeBlockDone_o
);
    localparam WRITE_IDLE = 2'b00;
    localparam START_AW = 2'b01;
    localparam CHECK_BDONE = 2'b10;
    localparam WRITE_DONE = 2'b11;

    reg [1:0] state, state_next;
    reg [31:0] dstAddrTmp, dstAddrTmp_next;
    reg [15:0] dataSizeTmp, dataSizeTmp_next;
    reg [15:0] dataCnt, dataCnt_next;
    reg [31:0] wAddr_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= WRITE_IDLE;
            dstAddrTmp <= 32'd0;
            dataSizeTmp <= 16'd0;
            dataCnt <= 16'd0;
            wAddr_o <= 32'd0;
        end else begin
            state <= state_next;
            dstAddrTmp <= dstAddrTmp_next;
            dataSizeTmp <= dataSizeTmp_next;
            dataCnt <= dataCnt_next;
            wAddr_o <= wAddr_next;
        end
    end

    always @(*) begin
        state_next = state;
        dstAddrTmp_next = dstAddrTmp;
        dataSizeTmp_next = dataSizeTmp;
        dataCnt_next = dataCnt;
        wAddr_next = wAddr_o;
        awStart_o = 1'b0;
        writeBlockDone_o = 1'b0;

        case (state)
            WRITE_IDLE: begin
                awStart_o = 1'b0;
                writeBlockDone_o = 1'b0;
                dstAddrTmp_next = dstAddr_i;
                dataSizeTmp_next = dataSize_i;
                dataCnt_next = 16'd0;
                wAddr_next = dstAddr_i;

                if (blockStart_i)
                    state_next = START_AW;
                else
                    state_next = WRITE_IDLE;
            end

            START_AW: begin
                awStart_o = 1'b1;
                dataCnt_next = dataCnt + 16'd4;
                state_next = CHECK_BDONE;
            end

            CHECK_BDONE: begin
                awStart_o = 1'b0;
                wAddr_next = wAddr_o;
                dataCnt_next = dataCnt;

                if (!bDone_i)
                    state_next = CHECK_BDONE;
                else if (dataCnt < dataSizeTmp) begin
                    wAddr_next = dstAddrTmp + dataCnt;   // 다음 AW 주소를 미리 준비
                    state_next = START_AW;
                end
                else
                    state_next = WRITE_DONE;
            end

            WRITE_DONE: begin
                writeBlockDone_o = 1'b1;

                if (intrClr_i)
                    state_next = WRITE_IDLE;
                else
                    state_next = WRITE_DONE;
            end

            default: state_next = WRITE_IDLE;
        endcase
    end

endmodule