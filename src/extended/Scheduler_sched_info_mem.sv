/*--------------------------------------------------------------------
  (C) Copyright 2017-2020 Barcelona Supercomputing Center
                          Centro Nacional de Supercomputacion

  This file is part of OmpSs@FPGA toolchain.

  This code is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation; either version 3 of
  the License, or (at your option) any later version.

  OmpSs@FPGA toolchain is distributed in the hope that it will be
  useful, but WITHOUT ANY WARRANTY; without even the implied
  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this code. If not, see <www.gnu.org/licenses/>.
--------------------------------------------------------------------*/

`timescale 1ns / 1ps

module Scheduler_sched_info_mem
(
    input  clk,
    //Port A
    input [OmpSsManager::ACC_BITS-1:0] scheduleData_portA_addr,
    input scheduleData_portA_en,
    input [49:0] scheduleData_portA_din,
    //Port B
    input [OmpSsManager::ACC_BITS-1:0] scheduleData_portB_addr,
    input scheduleData_portB_en,
    output logic [49:0] scheduleData_portB_dout
);

    reg [49:0] mem[OmpSsManager::MAX_ACCS];
    
    always_ff @(posedge clk) begin
        if (scheduleData_portA_en) begin
            mem[scheduleData_portA_addr] <= scheduleData_portA_din;
        end
    end
    
    always_ff @(posedge clk) begin
        if (scheduleData_portB_en) begin
            scheduleData_portB_dout <= mem[scheduleData_portB_addr];
        end
    end

endmodule
