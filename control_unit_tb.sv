module control_unit_tb();
    parameter WIDTH = 32;
parameter NUM_REGS = 20;
    bit clk;
    bit rst;

    // AXI signals
    wire awready;
    bit awvalid;
    bit [19:0] awaddr;
    wire wready;
    bit wvalid;
    bit [31:0] wdata;
    bit bready;
    wire bvalid;
    wire [1:0] bresp;
    wire arready;
    wire arvalid;
    wire [19:0] araddr;
    wire rready;
    wire rvalid;
    wire [31:0] rdata;
    wire error;
    reg [7:0] my_memory[0:511];

    wire [2:0] awprot, arprot;
    wire [3:0] wstrb;
    wire [1:0] rresp;

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Instantiate a simple BRAM model
    bram_controller bram (
        .s_axi_aclk(clk),
        .s_axi_aresetn(~rst),
        .s_axi_araddr(araddr),
        .s_axi_arprot(3'b000),
        .s_axi_arvalid(arvalid),
        .s_axi_arready(arready),
        .s_axi_awaddr(awaddr),
        .s_axi_awprot(3'b000),
        .s_axi_awvalid(awvalid),
        .s_axi_awready(awready),
        .s_axi_wdata(wdata),
        .s_axi_wstrb(4'b1111),
        .s_axi_wvalid(wvalid),
        .s_axi_wready(wready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_bready(bready),
        .s_axi_rdata(rdata),
        .s_axi_rresp(),
        .s_axi_rvalid(rvalid),
        .s_axi_rready(rready)
    );


    wire [WIDTH-1:0] regfile [0:NUM_REGS-1];
    genvar i;
    generate
        for (i = 0; i < NUM_REGS; i = i + 1) begin : expose_regs
            assign regfile[i] = dut.regfile.the_regs[i];
        end
    endgenerate
    
    initial begin
            awvalid = 1;
            wvalid = 1;
            awaddr = 380;  // 0x17C
            wdata = 32'hDEADBEEF;
            #20;
            awvalid = 0;
            wvalid = 0;
            bready= 1;
            #20;
            bready = 0;
            #30;
    end
   
    
        // Instantiate the control unit
   control_unit #(.WIDTH(WIDTH), .NUM_REGS(NUM_REGS)) dut (
        .clk(clk),
        .rst(rst),
        .error(error),
        
        .M_AXI_AWADDR(awaddr),
        .M_AXI_AWPROT(awprot),
        .M_AXI_AWVALID(awvalid),
        .M_AXI_AWREADY(awready),
        
        .M_AXI_WDATA(wdata),
        .M_AXI_WSTRB(wstrb),
        .M_AXI_WVALID(wvalid),
        .M_AXI_WREADY(wready),
        
        .M_AXI_BRESP(bresp),
        .M_AXI_BVALID(bvalid),
        .M_AXI_BREADY(bready),
        
        .M_AXI_ARADDR(araddr),
        .M_AXI_ARPROT(arprot),
        .M_AXI_ARVALID(arvalid),
        .M_AXI_ARREADY(arready),
        
        .M_AXI_RDATA(rdata),
        .M_AXI_RRESP(rresp),
        .M_AXI_RVALID(rvalid),
        .M_AXI_RREADY(rready)
    );

initial begin

        // Reset
        rst = 1;
        #20;
        rst = 0;
    
        // Load program into memory
        $readmemh("/home/ugrad/yc3146/lab3/lab3.srcs/sources_1/new/lab3_binary.hex", my_memory);
        
        // Load program into BRAM
        for (int i = 0; i < 368; i = i + 4) begin
            awvalid = 1;
            wvalid  = 1;
            awaddr  = i;
            wdata   = {my_memory[i+3], my_memory[i+2], my_memory[i+1], my_memory[i]};
            #20;
            awvalid = 0;
            wvalid  = 0;
            bready  = 1;
            #20;
            bready  = 0;
            #30;
        end
        $finish;
    end
endmodule