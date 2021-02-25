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

module SmartOmpSsManager #(
    parameter MAX_ACCS = 16,
    parameter ACC_BITS = $clog2(MAX_ACCS),
    parameter MAX_ACC_CREATORS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter ACC_SUBQUEUE_LEN = 64,
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
    input  [ACC_BITS-1:0] taskwait_in_tid,
    input  [63:0] taskwait_in_tdata,
    input  taskwait_in_tlast,
    //Taskwait ack
    output taskwait_out_tvalid,
    input  taskwait_out_tready,
    output [ACC_BITS-1:0] taskwait_out_tdest,
    output [63:0] taskwait_out_tdata,
    output taskwait_out_tlast,
    //Task creation inStream
    input  spawn_in_tvalid,
    output spawn_in_tready,
    input  [ACC_BITS-1:0] spawn_in_tid,
    input  [4:0] spawn_in_tdest, //NOTE: For the moment I leave it at 5 bits, but this could be less
    input  [63:0] spawn_in_tdata,
    input  spawn_in_tlast,
    //Task creation ack
    output spawn_out_tvalid,
    input  spawn_out_tready,
    output [ACC_BITS-1:0] spawn_out_tdest,
    output [63:0] spawn_out_tdata,
    output spawn_out_tlast,
    //Lock request
    input  lock_in_tvalid,
    output lock_in_tready,
    input  [ACC_BITS-1:0] lock_in_tid,
    input  [63:0] lock_in_tdata,
    //Lock ack
    output lock_out_tvalid,
    input  lock_out_tready,
    output [ACC_BITS-1:0] lock_out_tdest,
    output [63:0] lock_out_tdata,
    output lock_out_tlast,
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

    localparam TW_MEM_BITS = $clog2(MAX_ACC_CREATORS);
    localparam TW_MEM_WIDTH = OmpSsManager::TW_INFO_CW+ACC_BITS;
    localparam ACC_SUBQUEUE_BITS = $clog2(ACC_SUBQUEUE_LEN);
    localparam ACC_QUEUE_BITS = ACC_SUBQUEUE_BITS+ACC_BITS;

    wire managed_aresetn_sig;

    wire Command_Out_acc_avail_wr;
    wire [ACC_BITS-1:0] Command_Out_acc_avail_wr_address;
    wire [63:0] Command_Out_outStream_tdata;
    wire Command_Out_outStream_tlast;
    wire Command_Out_outStream_tready;
    wire Command_Out_outStream_tvalid;

    wire [ACC_QUEUE_BITS-1:0] Command_In_intCmdInQueue_addr;
    wire Command_In_intCmdInQueue_clk;
    wire [63:0] Command_In_intCmdInQueue_din;
    wire [63:0] Command_In_intCmdInQueue_dout;
    wire Command_In_intCmdInQueue_en;
    wire Command_In_intCmdInQueue_we;

    wire [ACC_BITS-1:0] Scheduler_sched_queue_nempty_address;
    wire Scheduler_sched_queue_nempty_write;
    wire [ACC_QUEUE_BITS-1:0] Scheduler_intCmdInQueue_addr;
    wire Scheduler_intCmdInQueue_clk;
    wire [63:0] Scheduler_intCmdInQueue_din;
    wire [63:0] Scheduler_intCmdInQueue_dout;
    wire Scheduler_intCmdInQueue_en;
    wire Scheduler_intCmdInQueue_we;

    wire [63:0] Spawn_In_outStream_tdata;
    wire Spawn_In_outStream_tlast;
    wire Spawn_In_outStream_tready;
    wire Spawn_In_outStream_tvalid;

    wire [63:0] Taskwait_inStream_tdata;
    wire Taskwait_inStream_tvalid;
    wire Taskwait_inStream_tready;
    wire [ACC_BITS-1:0] Taskwait_inStream_tid;
    wire [TW_MEM_BITS-1:0] Taskwait_twInfo_addr;
    wire Taskwait_twInfo_clk;
    wire [TW_MEM_WIDTH-1:0] Taskwait_twInfo_din;
    wire [TW_MEM_WIDTH-1:0] Taskwait_twInfo_dout;
    wire Taskwait_twInfo_en;
    wire Taskwait_twInfo_we;

    assign managed_aresetn = managed_aresetn_sig;
    assign managed_aresetn_sig = peripheral_aresetn & !ps_rst; 

    Command_In #(
        .MAX_ACCS(MAX_ACCS),
        .SUBQUEUE_BITS(ACC_SUBQUEUE_BITS)
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
        .SUBQUEUE_BITS(ACC_SUBQUEUE_BITS)
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

    if (LOCK_SUPPORT) begin
        Lock #(
            .ACC_BITS(ACC_BITS)
        ) Lock_I (
            .clk(aclk),
            .inStream_TDATA(lock_in_tdata),
            .inStream_TID(lock_in_tid),
            .inStream_TREADY(lock_in_tready),
            .inStream_TVALID(lock_in_tvalid),
            .outStream_TDATA(lock_out_tdata),
            .outStream_TDEST(lock_out_tdest),
            .outStream_TLAST(lock_out_tlast),
            .outStream_TREADY(lock_out_tready),
            .outStream_TVALID(lock_out_tvalid),
            .rstn(managed_aresetn_sig)
        );
    end else begin
        assign lock_in_tready = 1'b0;
        assign lock_out_tvalid = 1'b0;
    end

    if (EXTENDED_MODE) begin
        Scheduler #(
            .MAX_ACCS(MAX_ACCS),
            .SUBQUEUE_LEN(ACC_SUBQUEUE_LEN),
            .MAX_ACC_TYPES(MAX_ACC_TYPES),
            .SPAWNOUT_QUEUE_LEN(SPAWNOUT_QUEUE_LEN)
        ) Scheduler_I (
            .bitinfo_addr(bitinfo_addr),
            .bitinfo_clk(bitinfo_clk),
            .bitinfo_dout(bitinfo_dout),
            .bitinfo_en(bitinfo_en),
            .bitinfo_rst(bitinfo_rst),
            .clk(aclk),
            .inStream_TDATA(spawn_in_tdata),
            .inStream_TID(spawn_in_tid),
            .inStream_TLAST(spawn_in_tlast),
            .inStream_TREADY(spawn_in_tready),
            .inStream_TVALID(spawn_in_tvalid),
            .intCmdInQueue_addr(Scheduler_intCmdInQueue_addr),
            .intCmdInQueue_clk(Scheduler_intCmdInQueue_clk),
            .intCmdInQueue_din(Scheduler_intCmdInQueue_din),
            .intCmdInQueue_dout(Scheduler_intCmdInQueue_dout),
            .intCmdInQueue_en(Scheduler_intCmdInQueue_en),
            .intCmdInQueue_we(Scheduler_intCmdInQueue_we),
            .outStream_TDATA(spawn_out_tdata),
            .outStream_TDEST(spawn_out_tdest),
            .outStream_TLAST(spawn_out_tlast),
            .outStream_TREADY(spawn_out_tready),
            .outStream_TVALID(spawn_out_tvalid),
            .picosRejectTask_id(),
            .picosRejectTask_valid(),
            .rstn(managed_aresetn_sig),
            .sched_queue_nempty_address(Scheduler_sched_queue_nempty_address),
            .sched_queue_nempty_write(Scheduler_sched_queue_nempty_write),
            .spawnout_queue_addr(spawnout_queue_addr),
            .spawnout_queue_clk(spawnout_queue_clk),
            .spawnout_queue_din(spawnout_queue_din),
            .spawnout_queue_dout(spawnout_queue_dout),
            .spawnout_queue_en(spawnout_queue_en),
            .spawnout_queue_rst(spawnout_queue_rst),
            .spawnout_queue_we(spawnout_queue_we)
        );

        Spawn_In #(
            .SPAWNIN_QUEUE_LEN(SPAWNIN_QUEUE_LEN)
        ) Spawn_In_I (
            .clk(aclk),
            .outStream_TDATA(Spawn_In_outStream_tdata),
            .outStream_TLAST(Spawn_In_outStream_tlast),
            .outStream_TREADY(Spawn_In_outStream_tready),
            .outStream_TVALID(Spawn_In_outStream_tvalid),
            .picosFinishTask_TDATA(),
            .picosFinishTask_TREADY(1'b0),
            .picosFinishTask_TVALID(),
            .rstn(managed_aresetn_sig),
            .spawnin_queue_addr(spawnin_queue_addr),
            .spawnin_queue_clk(spawnin_queue_clk),
            .spawnin_queue_din(spawnin_queue_din),
            .spawnin_queue_dout(spawnin_queue_dout),
            .spawnin_queue_en(spawnin_queue_en),
            .spawnin_queue_rst(spawnin_queue_rst),
            .spawnin_queue_we(spawnin_queue_we)
        );

        Taskwait #(
            .ACC_BITS(ACC_BITS),
            .MAX_ACC_CREATORS(MAX_ACC_CREATORS),
            .TW_MEM_WIDTH(TW_MEM_WIDTH)
        ) Taskwait_I (
            .clk(aclk),
            .inStream_TDATA(Taskwait_inStream_tdata),
            .inStream_TID(Taskwait_inStream_tid),
            .inStream_TREADY(Taskwait_inStream_tready),
            .inStream_TVALID(Taskwait_inStream_tvalid),
            .outStream_TDATA(taskwait_out_tdata),
            .outStream_TDEST(taskwait_out_tdest),
            .outStream_TLAST(taskwait_out_tlast),
            .outStream_TREADY(taskwait_out_tready),
            .outStream_TVALID(taskwait_out_tvalid),
            .rstn(managed_aresetn_sig),
            .twInfo_addr(Taskwait_twInfo_addr),
            .twInfo_clk(Taskwait_twInfo_clk),
            .twInfo_din(Taskwait_twInfo_din),
            .twInfo_dout(Taskwait_twInfo_dout),
            .twInfo_en(Taskwait_twInfo_en),
            .twInfo_we(Taskwait_twInfo_we)
        );

        dual_port_mem_wrapper #(
            .SIZE(ACC_SUBQUEUE_LEN*MAX_ACCS),
            .WIDTH(64),
            .MODE_A("READ_FIRST"),
            .MODE_B("READ_FIRST"),
            .EN_RST_A(0),
            .EN_RST_B(0),
            .SINGLE_PORT(0)
        ) intCmdInQueue (
            .addrA(Command_In_intCmdInQueue_addr),
            .addrB(Scheduler_intCmdInQueue_addr),
            .clkA(Command_In_intCmdInQueue_clk),
            .clkB(Scheduler_intCmdInQueue_clk),
            .dinA(Command_In_intCmdInQueue_din),
            .dinB(Scheduler_intCmdInQueue_din),
            .doutA(Command_In_intCmdInQueue_dout),
            .doutB(Scheduler_intCmdInQueue_dout),
            .enA(Command_In_intCmdInQueue_en),
            .enB(Scheduler_intCmdInQueue_en),
            .weA(Command_In_intCmdInQueue_we),
            .weB(Scheduler_intCmdInQueue_we)
        );

        dual_port_mem_wrapper #(
            .SIZE(MAX_ACC_CREATORS),
            .WIDTH(TW_MEM_WIDTH),
            .MODE_A("READ_FIRST"),
            .EN_RST_A(0),
            .SINGLE_PORT(1)
        ) tw_info (
            .addrA(Taskwait_twInfo_addr),
            .clkA(Taskwait_twInfo_clk),
            .dinA(Taskwait_twInfo_din),
            .doutA(Taskwait_twInfo_dout),
            .enA(Taskwait_twInfo_en),
            .weA(Taskwait_twInfo_we)
        );

        axis_switch_independent_interfaces #(
            .NSLAVES(3),
            .NMASTERS(1),
            .REG_PIPELINE_DEPTH(0),
            .SINGLE_ST(0),
            .DATA_WIDTH(64),
            .HAS_ID(1),
            .ID_WIDTH(ACC_BITS),
            .HAS_LAST(1),
            .HAS_DEST(0)
        ) Taskwait_inStream_Inter (
            .aclk(aclk),
            .aresetn(interconnect_aresetn),
            .S00_AXIS_tvalid(taskwait_in_tvalid),
            .S00_AXIS_tready(taskwait_in_tready),
            .S00_AXIS_tdata(taskwait_in_tdata),
            .S00_AXIS_tid(taskwait_in_tid),
            .S00_AXIS_tlast(taskwait_in_tlast),
            .S01_AXIS_tvalid(Command_Out_outStream_tvalid),
            .S01_AXIS_tready(Command_Out_outStream_tready),
            .S01_AXIS_tdata(Command_Out_outStream_tdata),
            .S01_AXIS_tid(taskwait_in_tid), //Again, this is done on purpose
            .S01_AXIS_tlast(Command_Out_outStream_tlast),
            .S02_AXIS_tvalid(Spawn_In_outStream_tvalid),
            .S02_AXIS_tready(Spawn_In_outStream_tready),
            .S02_AXIS_tdata(Spawn_In_outStream_tdata),
            .S02_AXIS_tid(taskwait_in_tid), //Same reason as S01_AXIS_tid
            .S02_AXIS_tlast(Spawn_In_outStream_tlast),
            .M00_AXIS_tvalid(Taskwait_inStream_tvalid),
            .M00_AXIS_tready(Taskwait_inStream_tready),
            .M00_AXIS_tdata(Taskwait_inStream_tdata),
            .M00_AXIS_tid(Taskwait_inStream_tid),
            .M00_AXIS_tlast()
        );
    end else begin
        assign taskwait_in_tready = 1'b0;
        assign taskwait_out_tvalid = 1'b0;
        assign spawn_in_tready = 1'b0;
        assign taskwait_out_tvalid = 1'b0;

        assign spawnin_queue_clk = aclk;
        assign spawnin_queue_rst = 1;
        assign spawnin_queue_en = 0;
        assign spawnin_queue_we = 0;

        assign spawnout_queue_clk = aclk;
        assign spawnout_queue_rst = 1;
        assign spawnout_queue_en = 0;
        assign spawnout_queue_we = 0;

        assign bitinfo_clk = aclk;
        assign bitinfo_rst = 1;
        assign bitinfo_en = 0;
    end

endmodule
