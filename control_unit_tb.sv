module control_unit_tb();
    parameter WIDTH = 32;
    parameter NUM_REGS = 20;
    bit clk;
    bit rst;
    wire awready;
    bit awvalid;
    bit[19:0] awaddr;
    wire wready;
    bit wvalid;
    bit[31:0] wdata;
    bit bready;
    wire bvalid;
    wire[1:0] bresp;
    wire arready;
    bit arvalid;
    bit[19:0] araddr;
    bit rready;
    wire rvalid;
    wire[31:0] rdata;
    
    reg _rst;
    reg _awvalid;
    reg[19:0] _awaddr;
    reg _wvalid;
    reg[31:0] _wdata;
    reg _bready;
    reg _arvalid;
    reg[19:0] _araddr;
    reg _rready;
    
    always #5ns begin
        clk = ~clk;
    end
    always @ (posedge clk) begin
        _rst <= rst;
        _awvalid <= awvalid;
        _awaddr <= awaddr;
        _wvalid <= wvalid;
        _wdata <= wdata;
        _bready <= bready;
        _arvalid <= arvalid;
        _araddr <= araddr;
        _rready <= rready;
    end
    bram_controller my_bram(
        .s_axi_aclk(clk),
        .s_axi_aresetn(~rst),
        .s_axi_araddr(_araddr),
        .s_axi_arprot(0),
        .s_axi_arready(arready),
        .s_axi_arvalid(_arvalid),
        .s_axi_awaddr(_awaddr),
        .s_axi_awprot(0),
        .s_axi_awready(awready),
        .s_axi_awvalid(_awvalid),
        .s_axi_bready(_bready),
        .s_axi_bresp(bresp),
        .s_axi_bvalid(bvalid),
        .s_axi_rdata(rdata),
        .s_axi_rready(_rready),
        .s_axi_rvalid(rvalid),
        .s_axi_wdata(_wdata),
        .s_axi_wready(wready),
        .s_axi_wstrb('b1111),
        .s_axi_wvalid(_wvalid)
    );
    
    
    reg control_unit_error;
    reg [2:0] M_AXI_AWPROT;
    control_unit #(.WIDTH(WIDTH), .NUM_REGS(NUM_REGS)) dut (
            .clk(clk),
            .rst(rst),
            .error(control_unit_error),
            
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
            wire [WIDTH-1:0] regfile [0:NUM_REGS-1];
            genvar i;
        generate
            for (i = 0; i < NUM_REGS; i = i + 1) begin : expose_regs
                assign regfile[i] = dut.regfile.the_regs[i];
            end
        endgenerate
    reg [7:0] my_memory[511:0];
    initial begin
        rst = 1;
        #20ns;
        rst = 0;
        #20ns;
        $readmemh("/home/ugrad/yc3146/lab3/lab3.srcs/sources_1/new/lab3_binary.hex", my_memory);
        #40ns;
        for (int i = 0; i < 512; i+=4) begin
        awvalid = 1;
        wvalid = 1;
        awaddr = i;
        wdata = {my_memory[i+3], my_memory[i+2], my_memory[i+1], my_memory[i]};
        #20ns;
        awvalid = 0;
        wvalid = 0;
        bready = 1;
        #20ns;
        bready = 0;
        #20ns;
    end
        
    #20ns;
    // actual test-bench starts here...
    rst = 1;
    #10;
    rst = 0;
    #2000;
    $finish;
end
endmodule