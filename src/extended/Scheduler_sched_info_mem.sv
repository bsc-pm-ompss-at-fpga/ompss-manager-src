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
    input  ap_clk,
    //Port 0
    input [OmpSsManager::ACC_BITS-1:0] scheduleData_address0,
    input scheduleData_ce0,
    input [49:0] scheduleData_d0,
    //Port 1
    input [OmpSsManager::ACC_BITS-1:0] scheduleData_address1,
    input scheduleData_ce1,
    output logic [49:0] scheduleData_q1
);

    reg [49:0] mem[OmpSsManager::MAX_ACCS];
    
    always_ff @(posedge ap_clk) begin
        if (scheduleData_ce0) begin
            mem[scheduleData_address0] <= scheduleData_d0;
        end
    end
    
    always_ff @(posedge ap_clk) begin
        if (scheduleData_ce1) begin
            scheduleData_q1 <= mem[scheduleData_address1];
        end
    end

endmodule
