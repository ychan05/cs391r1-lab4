`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/19/2025 03:10:02 PM
// Design Name: 
// Module Name: alu
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


module alu #(parameter OP_WIDTH=8) (op1,op2, control,res, error);
    input wire [3:0] control;
    input wire signed [OP_WIDTH-1:0] op1 , op2;
    output wire signed [OP_WIDTH-1:0] res;
    output wire error;
    
    localparam NOT = 4'b0001; // NOT opcode
    localparam XOR = 4'b0000; // XOR opcode
    localparam AND = 4'b0010; // AND opcode
    localparam LSL = 4'b0011; // left shift logical opcode
    localparam RSL = 4'b0100; // right shift logical opcode
    localparam LSS = 4'b0101; // left shift signed opcode
    localparam RSS = 4'b0110; // right shift signed opcode
    localparam ADD = 4'b0111; // ADD opcode
    localparam SUB = 4'b1000; // SUB opcode
    localparam LT = 4'b1001; // less than opcode
    localparam EQ = 4'b1010; // equals opcode
    localparam GT = 4'b1100; // greater than opcode
    localparam OR = 4'b1011; // or opcode
    localparam XNOR = 4'b1101; // XNOR opcode

    wire signed [OP_WIDTH-1:0] rss_res;
    assign rss_res = op1 >>> op2;
    
    wire signed [OP_WIDTH-1:0] arith_res;
    assign arith_res = (control == ADD) ? (op1 + op2) :
                       (control == SUB) ? (op1 - op2) :
                       {OP_WIDTH{1'b0}};
    
    wire signed [OP_WIDTH-0:0] comp_res;
    assign comp_res = (control == LT) ? (op1 < op2):
                      (control == EQ) ? (op1 == op2):
                      (control == GT) ? (op1 > op2):
                      1'b0;

    assign res = (control == NOT) ? ~op1 :
                 (control == XOR) ? (op1 ^ op2) :
                 (control == AND) ? (op1 & op2) :
                 (control == OR) ? (op1 | op2) :
                 (control == XNOR) ? (op1 ~^ op2) : 
                 (control == LSL) ? (op1 << op2) :
                 (control == RSL) ? (op1 >> op2) :
                 (control == LSS) ? (op1 <<< op2) :  
                 (control == RSS) ? rss_res :
                 (control == ADD || control == SUB) ? arith_res :
                 (control == LT || control == GT || control == EQ) ? {{OP_WIDTH-1{1'b0}}, comp_res} :
                 {OP_WIDTH{1'b0}};
                                
   wire of;
   
   assign of = (control == ADD) ?
 (op1[OP_WIDTH-1] == op2[OP_WIDTH-1]) && (res[OP_WIDTH-1] != op1[OP_WIDTH-1]) :
               (control == SUB) ?
 (op1[OP_WIDTH-1] != op2[OP_WIDTH-1]) && (res[OP_WIDTH-1] != op1[OP_WIDTH-1]) :
                1'b0;
   // for invalid computations and invalid control signals
   assign error = (control != NOT && 
                   control != XOR && 
                   control != AND &&
                   control != LSL &&
                   control != RSL &&
                   control != LSS &&
                   control != RSS &&
                   control != ADD &&
                   control != SUB &&
                   control != LT &&
                   control != EQ &&
                   control != GT && 
                   control != OR &&
                   control != XNOR) || of;

endmodule
