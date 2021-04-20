`timescale 1ns / 1ps

module bitinfo_mem #(
    parameter COE_PATH = ""
) (
    input clk,
    input rst,
    input en,
    input [31:0] addr,
    output logic [31:0] dout    
);

    reg [31:0] mem[512];

    initial begin
        int fd, i, aux;
        string auxs;
        
        fd = $fopen(COE_PATH, "r");
        if (!fd) begin
            $error("Could not open file %s", COE_PATH); $fatal;
        end
        
        aux = $fscanf(fd, "%s", auxs); //memory_initialization_radix=16;
        aux = $fscanf(fd, "%s", auxs); //memory_initialization_vector=
        
        i = 0;
        while ($fscanf(fd, "%x", mem[i]) > 0) begin
            i = i+1;
        end
        $fclose(fd);
        
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            dout <= 0;
        end else if (en) begin
            assert(^addr !== 1'bX) else begin
                $error("Accessing memory with undefined address"); $fatal;
             end
            dout <= mem[addr[31:2]];
        end
    end

endmodule
