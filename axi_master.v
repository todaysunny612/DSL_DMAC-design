module axi_master (
    input wire clk,
    input wire reset_n,

    // Read block
    input wire [31:0] rAddr_i,
    input wire arStart_i,
    output reg rDone_o,
    // Write block
    input wire [31:0] wAddr_i,
    input wire awStart_i,
    output reg bDone_o,
    // Data buffer
    input wire full_i,
    input wire empty_i,
    output wire [31:0] rData_o,
    input wire [31:0] wData_i,
    output reg wDone_o,

    // AW channel
    output wire AWID,
    output reg [31:0] AWADDR,
    output wire [7:0] AWLEN,
    output wire [2:0] AWSIZE,
    output wire [1:0] AWBURST,
    output reg AWVALID,
    input wire  AWREADY,

    // W channel
    output reg [31:0] WDATA,
    output wire [3:0] WSTRB, 
    output reg WLAST,
    output reg WVALID,
    input wire WREADY,

    // B channel 
    input wire BID,
    input wire BVALID,
    output reg BREADY,

    // AR channel
    output wire ARID,
    output reg  [31:0] ARADDR,
    output wire [7:0] ARLEN,
    output wire [2:0] ARSIZE,
    output wire [1:0] ARBURST,
    output reg ARVALID,
    input wire ARREADY,

    // R channel
    input  wire RID,
    input  wire [31:0] RDATA,
    input  wire RLAST,
    input  wire RVALID,
    output reg RREADY
);

    // 고정값
    assign AWID    = 1'b0;
    assign AWLEN   = 8'd0;
    assign AWSIZE  = 3'd2;
    assign AWBURST = 2'b00;
    assign WSTRB   = 4'hF;
    assign ARID    = 1'b0;
    assign ARLEN   = 8'd0;
    assign ARSIZE  = 3'd2;
    assign ARBURST = 2'b00;

    // R data -> data buffer로 전달
    assign rData_o = RDATA;

    // AR channel FSM
    localparam AR_IDLE = 1'b0;
    localparam AR_EXEC = 1'b1;

    reg ar_state, ar_state_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) ar_state <= AR_IDLE;
        else  ar_state <= ar_state_next;
    end

    always @(*) begin
        ar_state_next = ar_state;
        ARVALID = 1'b0;
        ARADDR = rAddr_i;

        case (ar_state)
            AR_IDLE: begin
                if (arStart_i) ar_state_next = AR_EXEC;
                else ar_state_next = AR_IDLE;
            end
            AR_EXEC: begin
                ARVALID = 1'b1;
                if (ARREADY) ar_state_next = AR_IDLE;
                else ar_state_next = AR_EXEC;
            end
            default: ar_state_next = AR_IDLE;
        endcase
    end

    // R channel FSM
    localparam R_IDLE = 2'd0;
    localparam R_WAIT = 2'd1;
    localparam R_EXEC = 2'd2;

    reg [1:0] r_state, r_state_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) r_state <= R_IDLE;
        else r_state <= r_state_next;
    end

    always @(*) begin
        r_state_next = r_state;
        RREADY = 1'b0;
        rDone_o = 1'b0;

        case (r_state)
            R_IDLE: begin
                if (RVALID && full_i) r_state_next = R_WAIT;
                else if (RVALID && !full_i) r_state_next = R_EXEC;
                else  r_state_next = R_IDLE;
            end
            R_WAIT: begin
                if (!full_i) r_state_next = R_EXEC;
                else         r_state_next = R_WAIT;
            end
            R_EXEC: begin
                if ((RID == 1'b0) && RLAST) begin
                    rDone_o = 1'b1;
                    RREADY = 1'b1;
                    r_state_next = R_IDLE;
                end else begin
                    r_state_next = R_EXEC;
                end
            end
            default: r_state_next = R_IDLE;
        endcase
    end

    // AW channel FSM
    localparam AW_IDLE = 1'b0;
    localparam AW_EXEC = 1'b1;

    reg aw_state, aw_state_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) aw_state <= AW_IDLE;
        else aw_state <= aw_state_next;
    end

    always @(*) begin
        aw_state_next = aw_state;
        AWVALID  = 1'b0;
        AWADDR = wAddr_i;

        case (aw_state)
            AW_IDLE: begin
                if (awStart_i) aw_state_next = AW_EXEC;
                else aw_state_next = AW_IDLE;
            end
            AW_EXEC: begin
                AWVALID = 1'b1;
                if (AWREADY) aw_state_next = AW_IDLE;
                else aw_state_next = AW_EXEC;
            end
            default: aw_state_next = AW_IDLE;
        endcase
    end

    // W channel FSM
    localparam W_IDLE = 2'd0;
    localparam W_WAIT = 2'd1;
    localparam W_EXEC = 2'd2;

    reg [1:0] w_state, w_state_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) w_state <= W_IDLE;
        else w_state <= w_state_next;
    end

    always @(*) begin
        w_state_next = w_state;
        WVALID = 1'b0;
        WDATA = wData_i;
        WLAST = 1'b0;
        wDone_o = 1'b0;

        case (w_state)
            W_IDLE: begin
                if (awStart_i && empty_i) w_state_next = W_WAIT;
                else if (awStart_i && !empty_i) w_state_next = W_EXEC;
                else w_state_next = W_IDLE;
            end
            W_WAIT: begin
                if (!empty_i) w_state_next = W_EXEC;
                else          w_state_next = W_WAIT;
            end
            W_EXEC: begin
                WVALID = 1'b1;
                WLAST  = 1'b1;
                if (WREADY) begin
                    wDone_o      = 1'b1;
                    w_state_next = W_IDLE;
                end else begin
                    w_state_next = W_EXEC;
                end
            end
            default: w_state_next = W_IDLE;
        endcase
    end

    // B channel FSM
    localparam B_IDLE = 1'b0;
    localparam B_EXEC = 1'b1;

    reg b_state, b_state_next;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) b_state <= B_IDLE;
        else b_state <= b_state_next;
    end

    always @(*) begin
        b_state_next = b_state;
        BREADY       = 1'b0;
        bDone_o      = 1'b0;

        case (b_state)
            B_IDLE: begin
                if (BVALID) b_state_next = B_EXEC;
                else        b_state_next = B_IDLE;
            end
            B_EXEC: begin
                if (BID == 1'b0) begin
                    bDone_o = 1'b1;
                    BREADY = 1'b1;
                    b_state_next = B_IDLE;
                end else begin
                    b_state_next = B_EXEC;
                end
            end
            default: b_state_next = B_IDLE;
        endcase
    end

endmodule