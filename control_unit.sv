`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/08/2025 11:34:27 AM
// Design Name: 
// Module Name: control_unit
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module control_unit #(
    parameter WIDTH = 32,        
    parameter NUM_REGS = 32     
)(
    input wire clk,
input wire rst,
output wire error,
    input wire enable,  // ADDED: Enable signal
// BRAM Manager
output wire [19:0] M_AXI_AWADDR,
output wire [2:0] M_AXI_AWPROT,
output wire M_AXI_AWVALID,
input  wire M_AXI_AWREADY,

output wire [31:0] M_AXI_WDATA,
output wire [3:0] M_AXI_WSTRB,
output wire M_AXI_WVALID,
input  wire M_AXI_WREADY,

input  wire [1:0] M_AXI_BRESP,
input  wire M_AXI_BVALID,
output wire M_AXI_BREADY,

output wire [19:0] M_AXI_ARADDR,
output wire [2:0] M_AXI_ARPROT,
output wire M_AXI_ARVALID,
input  wire M_AXI_ARREADY,

input  wire [31:0] M_AXI_RDATA,
input  wire [1:0] M_AXI_RRESP,
input  wire M_AXI_RVALID,
output wire M_AXI_RREADY
);

// Instruction decoding
reg [6:0] opcode;
reg [2:0] funct3;
reg [6:0] funct7;
reg [4:0] rd, rs1, rs2;
reg [WIDTH-1:0] imm;

// Register file
reg we;
wire [WIDTH-1:0] rs;
wire [WIDTH-1:0] rt;
reg [WIDTH-1:0] d_in;

// ALU
reg  [WIDTH-1:0] alu_op1;
reg  [WIDTH-1:0] alu_op2;
reg [3:0] alu_control;
wire [WIDTH-1:0] alu_res;
wire alu_error;

//  Error signal
reg error_reg;
assign error = error_reg;

// Program Counter
reg [19:0] PC;

// Instruction register
reg [31:0] fetched_instruction;

// BRAM control signals
reg arvalid_reg;
reg rready_reg;

reg [19:0] araddr_reg;

// write channel registers
reg awvalid_reg;
reg wvalid_reg;
reg bready_reg;

reg [19:0] awaddr_reg;
reg [31:0] wdata_reg;
reg [3:0]  wstrb_reg;


// Assign BRAM outputs
assign M_AXI_ARADDR  = araddr_reg;
assign M_AXI_ARPROT  = 3'b000;
assign M_AXI_ARVALID = arvalid_reg; // take vals from reg since they need to be changed in FSM
assign M_AXI_RREADY  = rready_reg; // takes vals from reg since they need to be changed in FSM

// assign write channel registers
assign M_AXI_AWADDR  = awaddr_reg;
assign M_AXI_AWPROT  = 3'b000;
assign M_AXI_AWVALID = awvalid_reg;
assign M_AXI_WDATA   = wdata_reg;
assign M_AXI_WSTRB   = wstrb_reg;
assign M_AXI_WVALID  = wvalid_reg;
assign M_AXI_BREADY  = bready_reg;

// Register file instantiation
register_file #(.WIDTH(WIDTH), .NUM_REG(NUM_REGS))
regfile (
    .clk(clk),
    .we(we),
    .d_in(d_in),
    .rd_sel(rd),
    .rs_sel(rs1),
    .rt_sel(rs2),
    .rs(rs),
    .rt(rt)
);

// ALU instantiation
alu #(.OP_WIDTH(WIDTH)) my_alu (
    .op1(alu_op1),
    .op2(alu_op2),
    .control(alu_control),
    .res(alu_res),
    .error(alu_error)
);

reg [31:0] loaded_data; // store data from load instructions

// FSM: 0 = READY, 1 = FETCHING, 2 = DECODE, 3 = EXECUTE, 4 = WRITEBACK, 5 = MOVE TO NEXT, 6 = LOAD, 7 = load fetch, 
// 8 = store, 9 = STORE wait for B VALID, 10 = deassign bready
reg [3:0] state;

always @(posedge clk) begin
    if (rst) begin
        state <= 0;
        error_reg <= 0;
        we <= 0;
        arvalid_reg <= 0;
        rready_reg <= 0;
        PC <= 0;
        fetched_instruction <= 0;
        awaddr_reg = 0;
        awvalid_reg = 0; 
        wdata_reg = 0;
        wstrb_reg = 0;
        wvalid_reg = 0;
        bready_reg = 0;
    end else begin
        case (state)
            4'd0: begin // STATE 0: READY
                araddr_reg <= PC;
                we <= 0;
                error_reg <= 0;
                arvalid_reg <= 1; // Ready to give address to read from
                rready_reg <= 1;  // Set ready to read data
                state <= 1;      
            end
            
            4'd1: begin // STATE 1: FETCHING
                we <= 0;
                error_reg <= 0;

                if (M_AXI_RVALID && M_AXI_RREADY) begin           
                    arvalid_reg <= 0; // stop giving instruction to AXI
                    fetched_instruction <= M_AXI_RDATA;
                    state <= 2;         
                end
            end
            
            4'd2: begin // STATE 2: DECODE
                // Decode instruction
                opcode <= fetched_instruction[6:0];
                funct7 <= fetched_instruction[31:25];
                funct3 <= fetched_instruction[14:12];
                rs1 <= fetched_instruction[19:15];
                rs2 <= fetched_instruction[24:20];
                rd <= fetched_instruction[11:7];
                
                state <= 3;
            end
      
            4'd3: begin // STATE 3: EXECUTE 
                case (opcode)
                    7'b1100011: begin // B-type
                        // we use sub as our comparison operator
                        alu_control <= 4'b1000;
                        alu_op1 <= rs;
                        alu_op2 <= rt;
                        
                        state <= 5; // jump straight to next instruction state
                    end
                    7'b0110011: begin // R-type
                        case ({funct7, funct3})
                            10'b0000000_111: alu_control <= 4'b0010; // AND
                            10'b0000000_110: alu_control <= 4'b1011; // OR
                            10'b0000000_100: alu_control <= 4'b0000; // XOR
                            10'b0000000_001: alu_control <= 4'b0011; // LSL
                            10'b0000000_101: alu_control <= 4'b0100; // RSL
                            10'b0100000_101: alu_control <= 4'b0110; // RSS
                            10'b0000000_000: alu_control <= 4'b0111; // ADD
                            10'b0100000_000: alu_control <= 4'b1000; // SUB
                            default: error_reg <= 1;
                        endcase
                        alu_op1 <= rs;
                        alu_op2 <= rt;
                    end

                    7'b0010011: begin // I-type
                        alu_op1 <= rs;
                        
                        case (funct3)
                            3'h7: begin
                                alu_control <= 4'b0010; // ANDI
                                alu_op2 <= {{20{fetched_instruction[31]}}, fetched_instruction[31:20]};
                            end
                            3'h6: begin
                                alu_control <= 4'b1011; // ORI
                                alu_op2 <= {{20{fetched_instruction[31]}}, fetched_instruction[31:20]};
                            end
                            3'h4: begin
                                alu_control <= 4'b0000; // XORI
                                alu_op2 <= {{20{fetched_instruction[31]}}, fetched_instruction[31:20]};
                            end
                            3'h1: begin
                                if (fetched_instruction[31:25] == 7'b0000000) begin
                                    alu_control <= 4'b0011; // SLLI
                                    alu_op2 <= {27'b0, fetched_instruction[24:20]}; 
                                end else begin
                                    error_reg <= 1;
                                end
                            end
                            3'h5: begin
                                if (fetched_instruction[31:25] == 7'b0000000) begin
                                    alu_control <= 4'b0100; // SRLI
                                    alu_op2 <= {27'b0, fetched_instruction[24:20]}; 
                                end
                                else if (fetched_instruction[31:25] == 7'b0100000) begin
                                    alu_control <= 4'b0110; // SRAI
                                    alu_op2 <= {27'b0, fetched_instruction[24:20]}; 
                                end
                                else begin 
                                    error_reg <= 1; 
                                end
                            end
                            3'h0: begin
                                alu_control <= 4'b0111; // ADDI
                                alu_op2 <= {{20{fetched_instruction[31]}}, fetched_instruction[31:20]};
                            end
                            default: begin 
                                error_reg <= 1; 
                            end
                        endcase
                    end

                    7'b0110111: begin // LUI
                        imm <= {fetched_instruction[31:12], 12'b0};
                    end
                    
                    7'b1110011: begin // ebreak
                        if (funct3 == 3'h0 && fetched_instruction[31:20] == 12'h001) begin
                            error_reg <= 1;
                        end 
                    end
                    
                    7'b0000011: begin // I type loads
                        // first calculate address to read from
                        alu_op1 <= rs;
                        alu_op2 <= {{20{fetched_instruction[31]}}, fetched_instruction[31:20]};
                        alu_control <= 4'b0111;
                        state <= 6; // move to next state to load because we need one clock cycle to calc address
                        
                    end
                    7'b0100011: begin // S type
                            alu_op1 <= rs;
                            alu_op2 <= {{20{fetched_instruction[31]}}, fetched_instruction[31:25], fetched_instruction[11:7]};
                            alu_control <= 4'b0111;
                            state <= 8; // store state after calculating address
                    end
                    
                    default: begin
                        error_reg <= 1; // Unknown instruction
                    end
                endcase
                
                if (alu_error) begin 
                    error_reg <= 1; 
                end
                
                if (opcode != 7'b0000011 && opcode != 7'b0100011) begin 
                    state <= 4;
                end else begin
                   if (opcode == 7'b0100011) begin
                    state <= 8;
                   end else begin 
                    state <= 6;
                   end
                end
            end
            
            4'd8: begin // STORE: issue address and data to AXI
                awaddr_reg  <= alu_res[19:0];
                awvalid_reg <= 1;
                wvalid_reg  <= 1;
            
                case (funct3)
                    3'h0: begin // SB
                        wdata_reg <= {24'b0, rt[7:0]};
                        wstrb_reg <= 4'b0001;
                    end
                    3'h1: begin // SH
                        wdata_reg <= {16'b0, rt[15:0]};
                        wstrb_reg <= 4'b0011;
                    end
                    3'h2: begin // SW
                        wdata_reg <= rt;
                        wstrb_reg <= 4'b1111;
                    end
                    default: error_reg <= 1;
                endcase
            
           if (M_AXI_AWREADY && M_AXI_WREADY) begin
                   awvalid_reg <= 0;
                   wvalid_reg  <= 0;
                   state <= 9; // move to wait for BVALID
                end 
            end
            
            4'd9: begin // wait for B VALID
            if (M_AXI_BVALID) begin
                        bready_reg <= 1;  
                        awvalid_reg <= 0;
                        wvalid_reg <= 0;
                        state <= 10;       
                    end 
            
            end
            4'd10: begin // STORE wait for B
                    bready_reg <= 0;
                    state <= 5; // increment PC
            end
            
            4'd6: begin // STATE 6: LOAD
                araddr_reg  <= alu_res[19:0]; // take the calculated address
                arvalid_reg <= 1;
                rready_reg <= 1;
                state <= 7;    
               
            end
            
            4'd7: begin // STATE 7: Load fetch
              if (M_AXI_RVALID && M_AXI_RREADY) begin
                  arvalid_reg <= 0;
                  loaded_data <= M_AXI_RDATA;
                  state <= 4; //  move to WRITEBACK

              end 
            end

            4'd4: begin // STATE 4: WRITEBACK
                if (error_reg) begin
                    we <= 0;
                    arvalid_reg <= 0;
                    rready_reg <= 0;
                    PC <= PC;
                end else begin
                    // Select data to write based on opcode
                    if (opcode == 7'b0110111) begin // LUI
                        d_in <= imm;
                        we <= 1;
                    end 
                    else if (opcode == 7'b0000011) begin 

                        case(funct3)
                            3'h0: d_in <= {{24{loaded_data[7]}},  loaded_data[7:0]};   // LB
                            3'h1: d_in <= {{16{loaded_data[15]}}, loaded_data[15:0]};  // LH
                            3'h2: d_in <= loaded_data; // LW
                            default: d_in <= 0;
                    endcase
                    we <= 1;
                    end
                    else begin // R-type and I-type
                        d_in <= alu_res;
                        we <= 1;
                    end
                    
                    state <= 5;
                end
            end
      
           
            4'd5: begin // STATE 5: MOVE TO NEXT
                we <= 0;
                if (opcode == 7'b1100011) begin
                    case (funct3) 
                        3'h0: begin // BEQ
                            if (alu_res == 0) begin
                                PC <= PC + {{6{fetched_instruction[31]}}, fetched_instruction[31], fetched_instruction[7], fetched_instruction[30:25], fetched_instruction[11:8], 1'b0};;
                            end else begin 
                                PC <= PC + 4;
                            end
                        end
                        3'h1: begin // BNE
                            if (alu_res != 0) begin
                                PC <= PC + {{7{fetched_instruction[31]}}, fetched_instruction[31], fetched_instruction[7], fetched_instruction[30:25], fetched_instruction[11:8]};;
                            end else begin 
                                PC <= PC + 4;
                            end                              
                        end 
                        3'h4: begin // BLT
                            if ($signed(alu_res) < 0) begin
                                PC <= PC + {{6{fetched_instruction[31]}}, fetched_instruction[31], fetched_instruction[7], fetched_instruction[30:25], fetched_instruction[11:8], 1'b0};;;
                            end else begin 
                                PC <= PC + 4;
                            end                              
                        end 
                        3'h5: begin // BGE
                            if ($signed(alu_res) >= 0) begin
                                PC <= PC + {{6{fetched_instruction[31]}}, fetched_instruction[31], fetched_instruction[7], fetched_instruction[30:25], fetched_instruction[11:8], 1'b0};
                            end else begin 
                                PC <= PC + 4;
                            end                              
                        end 
                        default: PC <= PC + 4;
                    endcase
                end else begin
                    PC <= PC + 4;
                end
                state <= 0;
            end

            default: state <= 0;
        endcase
    end
end
endmodule