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

module SmartOmpSsManager_wrapper #(
    parameter MAX_ACCS = 16,
    parameter MAX_ACC_CREATORS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter CMDIN_SUBQUEUE_LEN = 64,
    parameter CMDOUT_SUBQUEUE_LEN = 64,
    parameter SPAWNIN_QUEUE_LEN = 1024,
    parameter SPAWNOUT_QUEUE_LEN = 1024,
    parameter EXTENDED_MODE = 0,
    parameter LOCK_SUPPORT = 0
) (
    //Clock and resets
    input  aclk,
    input  ps_rst,
    input  interconnect_aresetn,
    input  peripheral_aresetn,
    output managed_aresetn,
    //Taskwait request
    input  taskwait_in_tvalid,
    output taskwait_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] taskwait_in_tid,
    input  [63:0] taskwait_in_tdata,
    input  taskwait_in_tlast,
    //Taskwait ack
    output taskwait_out_tvalid,
    input  taskwait_out_tready,
    output [$clog2(MAX_ACCS)-1:0] taskwait_out_tdest,
    output [63:0] taskwait_out_tdata,
    output taskwait_out_tlast,
    //Task creation inStream
    input  spawn_in_tvalid,
    output spawn_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] spawn_in_tid,
    input  [4:0] spawn_in_tdest, //NOTE: For the moment I leave it at 5 bits, but this could be less
    input  [63:0] spawn_in_tdata,
    input  spawn_in_tlast,
    //Task creation ack
    output spawn_out_tvalid,
    input  spawn_out_tready,
    output [$clog2(MAX_ACCS)-1:0] spawn_out_tdest,
    output [63:0] spawn_out_tdata,
    output spawn_out_tlast,
    //Lock request
    input  lock_in_tvalid,
    output lock_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] lock_in_tid,
    input  [63:0] lock_in_tdata,
    //Lock ack
    output lock_out_tvalid,
    input  lock_out_tready,
    output [$clog2(MAX_ACCS)-1:0] lock_out_tdest,
    output [63:0] lock_out_tdata,
    output lock_out_tlast,
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
    //SpawnInQueue
    output spawnin_queue_clk,
    output spawnin_queue_rst,
    output spawnin_queue_en,
    output [7:0] spawnin_queue_we,
    output [31:0] spawnin_queue_addr,
    output [63:0] spawnin_queue_din,
    input  [63:0] spawnin_queue_dout,
    //SpawnOutQueue
    output spawnout_queue_clk,
    output spawnout_queue_rst,
    output spawnout_queue_en,
    output [7:0] spawnout_queue_we,
    output [31:0] spawnout_queue_addr,
    output [63:0] spawnout_queue_din,
    input  [63:0] spawnout_queue_dout,
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

    SmartOmpSsManager #(
        .LOCK_SUPPORT(LOCK_SUPPORT),
        .SPAWNOUT_QUEUE_LEN(SPAWNOUT_QUEUE_LEN),
        .EXTENDED_MODE(EXTENDED_MODE),
        .SPAWNIN_QUEUE_LEN(SPAWNIN_QUEUE_LEN),
        .CMDIN_SUBQUEUE_LEN(CMDIN_SUBQUEUE_LEN),
        .CMDOUT_SUBQUEUE_LEN(CMDOUT_SUBQUEUE_LEN),
        .MAX_ACC_TYPES(MAX_ACC_TYPES),
        .MAX_ACC_CREATORS(MAX_ACC_CREATORS),
        .MAX_ACCS(MAX_ACCS)
    ) SmartOmpSsManager_I (
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
        .spawn_in_tdata(spawn_in_tdata),
        .spawn_in_tdest(spawn_in_tdest),
        .spawn_in_tid(spawn_in_tid),
        .spawn_in_tlast(spawn_in_tlast),
        .spawn_in_tready(spawn_in_tready),
        .spawn_in_tvalid(spawn_in_tvalid),
        .interconnect_aresetn(interconnect_aresetn),
        .lock_out_tdata(lock_out_tdata),
        .lock_out_tdest(lock_out_tdest),
        .lock_out_tlast(lock_out_tlast),
        .lock_out_tready(lock_out_tready),
        .lock_out_tvalid(lock_out_tvalid),
        .lock_in_tdata(lock_in_tdata),
        .lock_in_tid(lock_in_tid),
        .lock_in_tready(lock_in_tready),
        .lock_in_tvalid(lock_in_tvalid),
        .managed_aresetn(managed_aresetn),
        .cmdin_out_tdata(cmdin_out_tdata),
        .cmdin_out_tdest(cmdin_out_tdest),
        .cmdin_out_tlast(cmdin_out_tlast),
        .cmdin_out_tready(cmdin_out_tready),
        .cmdin_out_tvalid(cmdin_out_tvalid),
        .peripheral_aresetn(peripheral_aresetn),
        .ps_rst(ps_rst),
        .spawnin_queue_addr(spawnin_queue_addr),
        .spawnin_queue_clk(spawnin_queue_clk),
        .spawnin_queue_din(spawnin_queue_din),
        .spawnin_queue_dout(spawnin_queue_dout),
        .spawnin_queue_en(spawnin_queue_en),
        .spawnin_queue_rst(spawnin_queue_rst),
        .spawnin_queue_we(spawnin_queue_we),
        .spawnout_queue_addr(spawnout_queue_addr),
        .spawnout_queue_clk(spawnout_queue_clk),
        .spawnout_queue_din(spawnout_queue_din),
        .spawnout_queue_dout(spawnout_queue_dout),
        .spawnout_queue_en(spawnout_queue_en),
        .spawnout_queue_rst(spawnout_queue_rst),
        .spawnout_queue_we(spawnout_queue_we),
        .taskwait_out_tdata(taskwait_out_tdata),
        .taskwait_out_tdest(taskwait_out_tdest),
        .taskwait_out_tlast(taskwait_out_tlast),
        .taskwait_out_tready(taskwait_out_tready),
        .taskwait_out_tvalid(taskwait_out_tvalid),
        .taskwait_in_tdata(taskwait_in_tdata),
        .taskwait_in_tid(taskwait_in_tid),
        .taskwait_in_tlast(taskwait_in_tlast),
        .taskwait_in_tready(taskwait_in_tready),
        .taskwait_in_tvalid(taskwait_in_tvalid),
        .spawn_out_tdata(spawn_out_tdata),
        .spawn_out_tdest(spawn_out_tdest),
        .spawn_out_tlast(spawn_out_tlast),
        .spawn_out_tready(spawn_out_tready),
        .spawn_out_tvalid(spawn_out_tvalid)
    );

endmodule
