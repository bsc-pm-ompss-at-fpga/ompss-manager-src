/*-------------------------------------------------------------------------*/
/*  Copyright (C) 2020-2023 Barcelona Supercomputing Center                */
/*                  Centro Nacional de Supercomputacion (BSC-CNS)          */
/*                                                                         */
/*  This file is part of OmpSs@FPGA toolchain.                             */
/*                                                                         */
/*  This program is free software: you can redistribute it and/or modify   */
/*  it under the terms of the GNU General Public License as published      */
/*  by the Free Software Foundation, either version 3 of the License,      */
/*  or (at your option) any later version.                                 */
/*                                                                         */
/*  This program is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                   */
/*  See the GNU General Public License for more details.                   */
/*                                                                         */
/*  You should have received a copy of the GNU General Public License      */
/*  along with this program. If not, see <https://www.gnu.org/licenses/>.  */
/*-------------------------------------------------------------------------*/

module dual_port_32_bit_mem_wrapper #(
    parameter SIZE = 256,
    parameter WIDTH = 32,
    parameter EN_RST_A = 1,
    parameter EN_RST_B = 1
)
(
    input rst,
    input clkA,
    input enA,
    input rstA,
    input [31:0] addrA,
    input [WIDTH/8-1:0] weA,
    input [WIDTH-1:0] dinA,
    output reg [WIDTH-1:0] doutA,
    input clkB,
    input enB,
    input rstB,
    input [31:0] addrB,
    input [WIDTH/8-1:0] weB,
    input [WIDTH-1:0] dinB,
    output reg [WIDTH-1:0] doutB
);

    reg[WIDTH-1:0] mem[0:SIZE-1];

    integer j;

    initial begin
        doutA = 0;
        doutB = 0;
        for (j = 0; j < SIZE; j = j+1) begin
            mem[j] = 0;
        end
    end

    genvar i;

    always @(posedge clkA) begin
        if (enA) begin
            if (EN_RST_A && rstA) begin
                doutA <= 0;
            end else begin
                assert(rst || ^addrA !== 1'bX) else begin
                    $error("Accessing memory with undefined address"); $fatal;
                end
                doutA <= mem[addrA[$clog2(WIDTH/8) + $clog2(SIZE)-1:$clog2(WIDTH/8)]];
            end
        end
    end

    for (i = 0; i < WIDTH/8; i = i+1) begin
        always @(posedge clkA) begin
            if (enA && weA[i]) begin
                mem[addrA[$clog2(WIDTH/8) + $clog2(SIZE)-1:$clog2(WIDTH/8)]][i*8 + 7:i*8] <= dinA[i*8 + 7:i*8];
            end
        end
    end



    always @(posedge clkB) begin
        if (enB) begin
            if (EN_RST_B && rstB) begin
                doutB <= 0;
            end else begin
                assert(rst || ^addrB !== 1'bX) else begin
                    $error("Accessing memory with undefined address"); $fatal;
                end
                doutB <= mem[addrB[$clog2(WIDTH/8) + $clog2(SIZE)-1:$clog2(WIDTH/8)]];
            end
        end
    end

    for (i = 0; i < WIDTH/8; i = i+1) begin
        always @(posedge clkB) begin
            if (enB && weB[i]) begin
                mem[addrB[$clog2(WIDTH/8) + $clog2(SIZE)-1:$clog2(WIDTH/8)]][i*8 + 7:i*8] <= dinB[i*8 + 7:i*8];
            end
        end
    end


endmodule
