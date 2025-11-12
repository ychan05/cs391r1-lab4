`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/08/2025 10:15:15 AM
// Design Name: 
// Module Name: register_file
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


module register_file #(
    parameter WIDTH = 32,
    parameter NUM_REG = 16)
    (
    input wire clk,
    input wire we,
    input wire [WIDTH-1:0] d_in,
    input wire [4:0] rd_sel,
    input wire [4:0] rs_sel,
    input wire [4:0] rt_sel,
    output wire [WIDTH-1:0] rs,
    output wire [WIDTH-1:0] rt
    );
    
    reg [WIDTH-1:0] the_regs [0:NUM_REG-1];
    assign rs = the_regs[rs_sel[4:0]];
    assign rt = the_regs[rt_sel[4:0]];
    assign the_regs[0] = {WIDTH{1'b0}};
    
    always @ (posedge clk) begin
        if (we && rd_sel != 0)
            the_regs[rd_sel[4:0]] <= d_in;
        the_regs[0] <= {WIDTH{1'b0}};
    end
    

endmodule