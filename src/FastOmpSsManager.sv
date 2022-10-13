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

`timescale 1 ps / 1 ps

module FastOmpSsManager #(
    parameter MAX_ACCS = 16,
    parameter ACC_BITS = $clog2(MAX_ACCS),
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
    input  [ACC_BITS-1:0] cmdout_in_tid,
    input  [63:0] cmdout_in_tdata,
    //outStream_CmdIn
    output cmdin_out_tvalid,
    input  cmdin_out_tready,
    output [ACC_BITS-1:0] cmdin_out_tdest,
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

    localparam CMDIN_SUBQUEUE_BITS = $clog2(CMDIN_SUBQUEUE_LEN);
    localparam CMDOUT_SUBQUEUE_BITS = $clog2(CMDOUT_SUBQUEUE_LEN);
    localparam CMDIN_QUEUE_BITS = CMDIN_SUBQUEUE_BITS+ACC_BITS;

    wire managed_aresetn_sig;

    wire Command_Out_acc_avail_wr;
    wire [ACC_BITS-1:0] Command_Out_acc_avail_wr_address;
    wire [63:0] Command_Out_outStream_tdata;
    wire Command_Out_outStream_tlast;
    wire Command_Out_outStream_tready;
    wire Command_Out_outStream_tvalid;

    wire [CMDIN_QUEUE_BITS-1:0] Command_In_intCmdInQueue_addr;
    wire Command_In_intCmdInQueue_clk;
    wire [63:0] Command_In_intCmdInQueue_din;
    wire [63:0] Command_In_intCmdInQueue_dout;
    wire Command_In_intCmdInQueue_en;
    wire Command_In_intCmdInQueue_we;

    wire [ACC_BITS-1:0] Scheduler_sched_queue_nempty_address;
    wire Scheduler_sched_queue_nempty_write;

    assign managed_aresetn = managed_aresetn_sig;
    assign managed_aresetn_sig = peripheral_aresetn & !ps_rst;

    Command_In #(
        .MAX_ACCS(MAX_ACCS),
        .SUBQUEUE_BITS(CMDIN_SUBQUEUE_BITS)
    ) Command_In_I (
        .acc_avail_wr(Command_Out_acc_avail_wr),
        .acc_avail_wr_address(Command_Out_acc_avail_wr_address),
        .clk(aclk),
        .cmdin_queue_addr(cmdin_queue_addr),
        .cmdin_queue_clk(cmdin_queue_clk),
        .cmdin_queue_din(cmdin_queue_din),
        .cmdin_queue_dout(cmdin_queue_dout),
        .cmdin_queue_en(cmdin_queue_en),
        .cmdin_queue_rst(cmdin_queue_rst),
        .cmdin_queue_we(cmdin_queue_we),
        .intCmdInQueue_addr(Command_In_intCmdInQueue_addr),
        .intCmdInQueue_clk(Command_In_intCmdInQueue_clk),
        .intCmdInQueue_din(Command_In_intCmdInQueue_din),
        .intCmdInQueue_dout(Command_In_intCmdInQueue_dout),
        .intCmdInQueue_en(Command_In_intCmdInQueue_en),
        .intCmdInQueue_we(Command_In_intCmdInQueue_we),
        .outStream_TDATA(cmdin_out_tdata),
        .outStream_TDEST(cmdin_out_tdest),
        .outStream_TLAST(cmdin_out_tlast),
        .outStream_TREADY(cmdin_out_tready),
        .outStream_TVALID(cmdin_out_tvalid),
        .rstn(managed_aresetn_sig),
        .sched_queue_nempty_address(Scheduler_sched_queue_nempty_address),
        .sched_queue_nempty_write(Scheduler_sched_queue_nempty_write)
    );

    Command_Out #(
        .MAX_ACCS(MAX_ACCS),
        .SUBQUEUE_BITS(CMDOUT_SUBQUEUE_BITS)
    ) Command_Out_I (
        .acc_avail_wr(Command_Out_acc_avail_wr),
        .acc_avail_wr_address(Command_Out_acc_avail_wr_address),
        .clk(aclk),
        .cmdout_queue_addr(cmdout_queue_addr),
        .cmdout_queue_clk(cmdout_queue_clk),
        .cmdout_queue_din(cmdout_queue_din),
        .cmdout_queue_dout(cmdout_queue_dout),
        .cmdout_queue_en(cmdout_queue_en),
        .cmdout_queue_rst(cmdout_queue_rst),
        .cmdout_queue_we(cmdout_queue_we),
        .inStream_TDATA(cmdout_in_tdata),
        .inStream_TID(cmdout_in_tid),
        .inStream_TREADY(cmdout_in_tready),
        .inStream_TVALID(cmdout_in_tvalid),
        .outStream_TDATA(Command_Out_outStream_tdata),
        .outStream_TLAST(Command_Out_outStream_tlast),
        .outStream_TREADY(Command_Out_outStream_tready),
        .outStream_TVALID(Command_Out_outStream_tvalid),
        .picosFinishTask_TDATA(),
        .picosFinishTask_TREADY(),
        .picosFinishTask_TVALID(),
        .rstn(managed_aresetn_sig)
    );

    assign bitinfo_clk = aclk;
    assign bitinfo_rst = 1;
    assign bitinfo_en = 0;

endmodule
