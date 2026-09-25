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

//pin1
reg [31:0] coreState;
reg [15:0] dataSize;
reg [31:0] srcAddr;
reg [31:0] dstAddr;
reg intrEn;
reg intr;
reg intrClr;
reg start;


localparam [1:0] IDLE = 2'b0;
localparam [1:0] ACCESS = 2'b1;

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
                  pready =1;
                  offset = paddr[4:2];

                  // if (penable && !pwrite) //읽기
                  //       prdata = reg[offset];
                  // else if (penable && pwrite) //쓰기
                  //       reg[offset] = pwdata;

                  if(!psel || penable) 
                        next_state = IDLE;

                  else if(psel && !penable)
                        next_state = ACCESS;
            end

            default: next_state = IDLE;
      endcase
end
            
endmodule