module apb_slave (
    input pclk,
    input reset_n,
    input [31:0] paddr,
    input penable,
    input psel,
    input pwrite,
    input [31:0] pwdata,
    output reg pready,
    output reg [31:0] prdata,

    input [1:0] coreState_i,
    input intr_i,
    output [15:0] dataSize_o,
    output [31:0] srcAddr_o,
    output [31:0] dstAddr_o,
    output intrEn_o,
    output intrClr_o,
    output start_o
);

//pin
reg [15:0] dataSize;
reg [31:0] srcAddr;
reg [31:0] dstAddr;
reg intrEn;
reg intrClr;
reg start;

localparam [1:0] IDLE = 2'b0;
localparam [1:0] ACCESS = 2'b1;

wire [2:0] offset = paddr[4:2];

//현재 상태 결정
reg [1:0] current_state, next_state;
always @(posedge pclk or negedge reset_n) begin
      if(!reset_n)
            current_state <= IDLE;
      else
            current_state <= next_state;
end

//다음 상태 결정
always @(*) begin
      next_state = current_state; //우선 기본값으로 현재 값을 next에 넣어둠
      pready = 1'b0;
      prdata = 32'b0;

      case (current_state)
            IDLE: begin
                  if(psel) begin
                        next_state = ACCESS;
                  end
            end

            ACCESS: begin
                  pready = 1;

                  if (!pwrite) begin //읽기
                        case (offset)
                              3'd0: prdata = srcAddr;
                              3'd1: prdata = dstAddr;
                              3'd2: prdata = {16'd0, dataSize};
                              3'd3: prdata = {29'd0, intrEn, 2'b00};
                              3'd4: prdata = {29'd0, intr_i, coreState_i};
                              default: prdata = 32'd0;
                        endcase
                  end

                  if(!psel || penable)
                        next_state = IDLE;

                  else if(psel && !penable)
                        next_state = ACCESS;
            end

            default: next_state = IDLE;
      endcase
end

//쓰기 
wire wr_en = (current_state == ACCESS) && psel && penable && pwrite;

always @(posedge pclk or negedge reset_n) begin
      if(!reset_n) begin
            srcAddr <= 32'd0;
            dstAddr <= 32'd0;
            dataSize <= 16'd0;
            intrEn <= 1'b0;
            intrClr <= 1'b0;
            start <= 1'b0;
      end else begin
            //start, intrClr는 1-cycle 펄스
            start   <= 1'b0;
            intrClr <= 1'b0;

            if (wr_en) begin
                  case (offset)
                        3'd0: srcAddr <= pwdata;
                        3'd1: dstAddr <= pwdata;
                        3'd2: dataSize <= pwdata[15:0];
                        3'd3: begin
                              start <= pwdata[0];
                              intrClr <= pwdata[1];
                              intrEn <= pwdata[2];
                        end
                        default: ;
                  endcase
            end
      end
end

assign dataSize_o = dataSize;
assign srcAddr_o = srcAddr;
assign dstAddr_o = dstAddr;
assign intrEn_o = intrEn;
assign intrClr_o = intrClr;
assign start_o = start;

endmodule