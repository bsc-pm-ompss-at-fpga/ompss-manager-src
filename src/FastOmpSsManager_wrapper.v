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

module FastOmpSsManager_wrapper #(
    parameter MAX_ACCS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter CMDIN_SUBQUEUE_LEN = 64,
    parameter CMDOUT_SUBQUEUE_LEN = 64
) (
    //Clock and resets
    input  aclk,
    input  ps_rst,
    input  interconnect_aresetn,
    input  peripheral_aresetn,
    output managed_aresetn,
    //inStream_CmdOut
    input  cmdout_in_tvalid,
    output cmdout_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] cmdout_in_tid,
    input  [63:0] cmdout_in_tdata,
    //outStream_CmdIn
    output cmdin_out_tvalid,
    input  cmdin_out_tready,
    output [$clog2(MAX_ACCS)-1:0] cmdin_out_tdest,
    output [63:0] cmdin_out_tdata,
    output cmdin_out_tlast,
    //CmdInQueue
    output cmdin_queue_clk,
    output cmdin_queue_rst,
    output cmdin_queue_en,
    output [7:0] cmdin_queue_we,
    output [31:0] cmdin_queue_addr,
    output [63:0] cmdin_queue_din,
    input  [63:0] cmdin_queue_dout,
    //CmdOutQueue
    output cmdout_queue_clk,
    output cmdout_queue_rst,
    output cmdout_queue_en,
    output [7:0] cmdout_queue_we,
    output [31:0] cmdout_queue_addr,
    output [63:0] cmdout_queue_din,
    input  [63:0] cmdout_queue_dout,
    //BitInfo
    output bitinfo_clk,
    output bitinfo_rst,
    output bitinfo_en,
    output [31:0] bitinfo_addr,
    input  [31:0] bitinfo_dout
);

    FastOmpSsManager #(
        .CMDIN_SUBQUEUE_LEN(CMDIN_SUBQUEUE_LEN),
        .CMDOUT_SUBQUEUE_LEN(CMDOUT_SUBQUEUE_LEN),
        .MAX_ACC_TYPES(MAX_ACC_TYPES),
        .MAX_ACCS(MAX_ACCS)
    ) FastOmpSsManager_I (
        .aclk(aclk),
        .bitinfo_addr(bitinfo_addr),
        .bitinfo_clk(bitinfo_clk),
        .bitinfo_dout(bitinfo_dout),
        .bitinfo_en(bitinfo_en),
        .bitinfo_rst(bitinfo_rst),
        .cmdin_queue_addr(cmdin_queue_addr),
        .cmdin_queue_clk(cmdin_queue_clk),
        .cmdin_queue_din(cmdin_queue_din),
        .cmdin_queue_dout(cmdin_queue_dout),
        .cmdin_queue_en(cmdin_queue_en),
        .cmdin_queue_rst(cmdin_queue_rst),
        .cmdin_queue_we(cmdin_queue_we),
        .cmdout_queue_addr(cmdout_queue_addr),
        .cmdout_queue_clk(cmdout_queue_clk),
        .cmdout_queue_din(cmdout_queue_din),
        .cmdout_queue_dout(cmdout_queue_dout),
        .cmdout_queue_en(cmdout_queue_en),
        .cmdout_queue_rst(cmdout_queue_rst),
        .cmdout_queue_we(cmdout_queue_we),
        .cmdout_in_tdata(cmdout_in_tdata),
        .cmdout_in_tid(cmdout_in_tid),
        .cmdout_in_tready(cmdout_in_tready),
        .cmdout_in_tvalid(cmdout_in_tvalid),
        .interconnect_aresetn(interconnect_aresetn),
        .managed_aresetn(managed_aresetn),
        .cmdin_out_tdata(cmdin_out_tdata),
        .cmdin_out_tdest(cmdin_out_tdest),
        .cmdin_out_tlast(cmdin_out_tlast),
        .cmdin_out_tready(cmdin_out_tready),
        .cmdin_out_tvalid(cmdin_out_tvalid),
        .peripheral_aresetn(peripheral_aresetn),
        .ps_rst(ps_rst)
    );

endmodule
