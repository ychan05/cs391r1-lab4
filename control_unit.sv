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
    parameter NUM_REGS = 16     
)(
    input wire clk,
input wire rst,
output wire error,

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

// Assign BRAM outputs
assign M_AXI_ARADDR  = araddr_reg;
assign M_AXI_ARPROT  = 3'b000;
assign M_AXI_ARVALID = arvalid_reg; // take vals from reg since they need to be changed in FSM
assign M_AXI_RREADY  = rready_reg; // takes vals from reg since they need to be changed in FSM

// Zero out unused write channels
assign M_AXI_AWADDR  = 20'b0;
assign M_AXI_AWPROT  = 3'b0;
assign M_AXI_AWVALID = 1'b0;
assign M_AXI_WDATA   = 32'b0;
assign M_AXI_WSTRB   = 4'b0;
assign M_AXI_WVALID  = 1'b0;
assign M_AXI_BREADY  = 1'b0;

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

// FSM: 0 = READY, 1 = FETCHING, 2 = DECODE, 3 = EXECUTE, 4 = WRITEBACK, 5 = MOVE TO NEXT, 6 = LOAD 
reg [2:0] state;

always @(posedge clk) begin
    if (rst) begin
        state <= 0;
        error_reg <= 0;
        we <= 0;
        arvalid_reg <= 0;
        rready_reg <= 1;
        PC <= 0;
        fetched_instruction <= 0;
    end else begin
        case (state)
            3'd0: begin // STATE 0: READY
                araddr_reg <= PC;
                we <= 0;
                error_reg <= 0;
                arvalid_reg <= 1; // Ready to give address to read from
                rready_reg <= 1;  // Set ready to read data
                state <= 1;      
            end
            
            3'd1: begin // STATE 1: FETCHING
                we <= 0;
                error_reg <= 0;

                if (M_AXI_RVALID && M_AXI_RREADY) begin           
                    arvalid_reg <= 0; // stop giving instruction to AXI
                    fetched_instruction <= M_AXI_RDATA;
                    state <= 2;         
                end
            end
            
            3'd2: begin // STATE 2: DECODE
                // Decode instruction
                opcode <= fetched_instruction[6:0];
                funct7 <= fetched_instruction[31:25];
                funct3 <= fetched_instruction[14:12];
                rs1 <= fetched_instruction[19:15];
                rs2 <= fetched_instruction[24:20];
                rd <= fetched_instruction[11:7];
                
                state <= 3;
            end 
            
            3'd3: begin // STATE 3: EXECUTE 
                case (opcode)
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
                    
                    default: begin
                        error_reg <= 1; // Unknown instruction
                    end
                endcase
                
                if (alu_error) begin 
                    error_reg <= 1; 
                end
                
                if (opcode != 7'b0000011) begin 
                    state <= 4;
                end else begin
                   
                end
            end
            
            3'd6: begin // STATE 6: LOAD
                araddr_reg  <= alu_res[19:0]; // take the calculated address
                arvalid_reg <= 1;
                rready_reg <= 1;
                state <= 7;    
                
               
            end
            
            3'd7: begin // STATE 7: Load fetch:
              if (M_AXI_RVALID && M_AXI_RREADY) begin
                  arvalid_reg <= 0;
                  loaded_data <= M_AXI_RDATA;
                  state <= 4; // now move to WRITEBACK

              end 
            end

            3'd4: begin // STATE 4: WRITEBACK
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
           
            3'd5: begin // STATE 5: MOVE TO NEXT
                we <= 0;
                PC <= PC + 4;
                state <= 0;
            end

            default: state <= 0;
        endcase
    end
end
endmodule