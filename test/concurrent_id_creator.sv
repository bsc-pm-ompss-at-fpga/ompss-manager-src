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

module concurrent_id_creator #(
    parameter NUM_ACCS = 16
) (
    input clk,
    input [NUM_ACCS-1:0] create_id,
    output int id[0:NUM_ACCS-1]
);

    int idx;

    initial begin
        idx = 0;
    end

    always @(posedge clk) begin
        int i;
        for (i = 0; i < NUM_ACCS; i = i+1) begin
            if (create_id[i]) begin
                id[i] <= idx;
                idx = idx+1;
            end
        end
    end

endmodule
