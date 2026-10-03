module dataBuffer (
    input wire clk,
    input wire reset_n,

    input wire [31:0] rData_i,
    input wire rDone_i,
    input wire wDone_i,

    output reg [31:0] wData_o,
    output reg full_o,
    output reg empty_o
);

    localparam EMPTY = 1'b0;
    localparam FULL = 1'b1;

    reg state, state_next;
    reg [31:0] buffer, buffer_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= EMPTY;
            buffer <= 32'd0;
        end else begin
            state  <= state_next;
            buffer <= buffer_next;
        end
    end

    always @(*) begin
        state_next = state;
        buffer_next = buffer;

        empty_o = 1'b0;
        full_o = 1'b0;
        wData_o = buffer;

        case (state)
            EMPTY: begin
                empty_o = 1'b1;
                full_o = 1'b0;
                wData_o = buffer;

                if (rDone_i)
                    buffer_next = rData_i;

                if (rDone_i)
                    state_next = FULL;
                else
                    state_next = EMPTY;
            end

            FULL: begin
                empty_o = 1'b0;
                full_o = 1'b1;
                wData_o = buffer;

                if (wDone_i)
                    state_next = EMPTY;
                else
                    state_next = FULL;
            end

            default: state_next = EMPTY;
        endcase
    end

endmodule