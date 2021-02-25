`timescale 1ns / 1ps

module dual_port_mem_wrapper #(
    parameter SIZE = 16,
    parameter WIDTH = 128,
    parameter MODE_A = "READ_FIRST",
    parameter MODE_B = "READ_FIRST",
    parameter EN_RST_A = 1,
    parameter EN_RST_B = 1,
    parameter SINGLE_PORT = 1,
    parameter INIT_CONTENT_FILE = ""
)
(
    input clkA,
    input enA,
    input rstA,
    input [$clog2(SIZE)-1:0] addrA,
    input weA,
    input [WIDTH-1:0] dinA,
    output reg [WIDTH-1:0] doutA,
    
    input clkB,
    input enB,
    input rstB,
    input [$clog2(SIZE)-1:0] addrB,
    input weB,
    input [WIDTH-1:0] dinB,
    output reg [WIDTH-1:0] doutB
);
    
    reg[WIDTH-1:0] mem[0:SIZE-1];
    
    integer j;
    
    initial begin
        doutA = 0;
        doutB = 0;
        if (INIT_CONTENT_FILE != "") begin
            $readmemh(INIT_CONTENT_FILE, mem);
        end else begin
            for (j = 0; j < SIZE; j = j+1) begin
                mem[j] = 0;
            end
        end
    end
    
    if (MODE_A == "READ_FIRST") begin
    
        always @(posedge clkA) begin
            if (enA) begin
                if (weA) begin
                    mem[addrA] <= dinA;
                end
                if (EN_RST_A && rstA) begin
                    doutA <= 0;
                end else begin
                    doutA <= mem[addrA];
                end
            end
        end
        
    end
    
    if (!SINGLE_PORT && MODE_B == "READ_FIRST") begin
    
        always @(posedge clkB) begin
            if (enB) begin
                if (weB) begin
                    mem[addrB] <= dinB;
                end
                if (EN_RST_B && rstB) begin
                    doutB <= 0;
                end else begin
                    doutB <= mem[addrB];
                end
            end
        end
        
    end
    
    if (MODE_A == "WRITE_FIRST") begin
    
        always @(posedge clkA) begin
            if (enA) begin
                if (weA) begin
                    mem[addrA] <= dinA;
                end
                if (EN_RST_A && rstA) begin
                    doutA <= 0;
                end else if (weA) begin
                    doutA <= dinA;
                end else begin
                    doutA <= mem[addrA];
                end
            end
        end
        
    end
    
    if (!SINGLE_PORT && MODE_B == "WRITE_FIRST") begin
        
        always @(posedge clkA) begin
            if (enB) begin
                if (weB) begin
                    mem[addrB] <= dinB;
                end
                if (EN_RST_B && rstB) begin
                    doutB <= 0;
                end else if (weB) begin
                    doutB <= dinB;
                end else begin
                    doutB <= mem[addrB];
                end
            end
        end
        
    end

endmodule

