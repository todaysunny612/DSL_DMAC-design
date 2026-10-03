module dmaCore (
    input wire clk,
    input wire reset_n,

    input wire start_i, // apb_slave start_o (1-cycle pulse)
    input wire intrClr_i, // apb_slave intrClr_o
    input wire intrEn_i, // apb_slave intrEn_o
    input wire readBlockDone_i,
    input wire writeBlockDone_i,

    output reg blockStart_o, // readBlock/writeBlock blockStart_i
    output reg [1:0] coreState_o, // apb_slave coreState_i
    output wire intr_o // apb_slave intr_i
);
    localparam CORE_IDLE = 2'b00;
    localparam CORE_RUN = 2'b01;
    localparam CORE_DONE = 2'b10;

    reg [1:0] state, state_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) state <= CORE_IDLE;
        else state <= state_next;
    end

    always @(*) begin
        state_next = state;
        blockStart_o = 1'b0;
        coreState_o = state;

        case (state)
            CORE_IDLE: begin
                if (start_i) begin
                    blockStart_o = 1'b1;
                    state_next = CORE_RUN;
                end
            end
            CORE_RUN: begin
                if (readBlockDone_i && writeBlockDone_i)
                    state_next = CORE_DONE;
            end
            CORE_DONE: begin
                if (intrClr_i)
                    state_next = CORE_IDLE;
            end
            default: state_next = CORE_IDLE;
        endcase
    end

    assign intr_o = (state == CORE_DONE) && intrEn_i;
endmodule