/*--------------------------------------------------------------------
  Copyright (C) Barcelona Supercomputing Center
                Centro Nacional de Supercomputacion (BSC-CNS)

  All Rights Reserved. 
  This file is part of OmpSs@FPGA toolchain.

  Unauthorized copying and/or distribution of this file,
  via any medium is strictly prohibited.
  The intellectual and technical concepts contained herein are
  propietary to BSC-CNS and may be covered by Patents.
--------------------------------------------------------------------*/

`timescale 1ns / 1ps

module Scheduler_sched_info_mem #(
    parameter MAX_ACC_TYPES = 16,
    parameter ACC_TYPE_BITS = $clog2(MAX_ACC_TYPES)
) (
    input clk,
    //Port A
    input [ACC_TYPE_BITS-1:0] scheduleData_portA_addr,
    input scheduleData_portA_en,
    input [49:0] scheduleData_portA_din,
    //Port B
    input [ACC_TYPE_BITS-1:0] scheduleData_portB_addr,
    input scheduleData_portB_en,
    output logic [49:0] scheduleData_portB_dout
);

    reg [49:0] mem[MAX_ACC_TYPES];

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
