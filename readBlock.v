module readBlock (
    input wire clk,
    input wire reset_n, 
 
    input wire [31:0] srcAddr_i,
    input wire [15:0] dataSize_i,
    input wire intrClr_i,
    input wire blockStart_i,
    input wire rDone_i,
 
    output reg [31:0] rAddr_o,
    output reg arStart_o,
    output reg readBlockDone_o
);
    //state encoding
    localparam READ_IDLE = 2'b00;
    localparam START_AR = 2'b01;
    localparam CHECK_RDONE = 2'b10;
    localparam READ_DONE = 2'b11;
 
    reg [1:0] state, state_next;
 
    reg [31:0] srcAddrTmp, srcAddrTmp_next;
    reg [15:0] dataSizeTmp,dataSizeTmp_next;
    reg [15:0] dataCnt, dataCnt_next;
    reg [31:0] rAddr_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= READ_IDLE;
            srcAddrTmp <= 32'd0;
            dataSizeTmp <= 16'd0;
            dataCnt <= 16'd0;
            rAddr_o <= 32'd0;
        end else begin
            state <= state_next;
            srcAddrTmp <= srcAddrTmp_next;
            dataSizeTmp <= dataSizeTmp_next;
            dataCnt <= dataCnt_next;
            rAddr_o <= rAddr_next;
        end
    end

    always @(*) begin
        state_next = state;
        srcAddrTmp_next = srcAddrTmp;
        dataSizeTmp_next = dataSizeTmp;
        dataCnt_next = dataCnt;
        rAddr_next = rAddr_o;
 
        arStart_o        = 1'b0;
        readBlockDone_o  = 1'b0;
 
        case (state)
            READ_IDLE: begin
                arStart_o = 1'b0;
                readBlockDone_o = 1'b0;
                srcAddrTmp_next = srcAddr_i;
                dataSizeTmp_next = dataSize_i;
                dataCnt_next = 16'd0;
                rAddr_next = srcAddr_i;
 
                if (blockStart_i)
                    state_next = START_AR;
                else
                    state_next = READ_IDLE;
            end
 
            START_AR: begin
                arStart_o = 1'b1;
                dataCnt_next = dataCnt + 16'd4;
                state_next = CHECK_RDONE;
            end
 
            CHECK_RDONE: begin
                arStart_o = 1'b0;
                rAddr_next = rAddr_o;
                dataCnt_next = dataCnt;
 
                if (!rDone_i) begin
                    state_next = CHECK_RDONE;
                end else if (dataCnt < dataSizeTmp) begin
                    rAddr_next = srcAddrTmp + dataCnt;
                    state_next = START_AR;
                end else begin
                    state_next = READ_DONE;
                end
            end
 
            READ_DONE: begin
                readBlockDone_o = 1'b1;
 
                if (intrClr_i)
                    state_next = READ_IDLE;
                else
                    state_next = READ_DONE;
            end
 
            default: begin
                state_next = READ_IDLE;
            end
        endcase
    end
 
endmodule