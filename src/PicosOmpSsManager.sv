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

module PicosOmpSsManager #(
    parameter MAX_ACCS = 16,
    parameter MAX_ACC_CREATORS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter CMDIN_SUBQUEUE_LEN = 64,
    parameter CMDOUT_SUBQUEUE_LEN = 64,
    parameter SPAWNIN_QUEUE_LEN = 1024,
    parameter SPAWNOUT_QUEUE_LEN = 1024,
    parameter LOCK_SUPPORT = 0,
    parameter ENABLE_SPAWN_QUEUES = 0,
    parameter AXILITE_INTF = 0,
    parameter ENABLE_TASK_CREATION = 0,
    parameter ENABLE_DEPS = 0,
    parameter DBG_AVAIL_COUNT_EN = 0,
    parameter DBG_AVAIL_COUNT_W = 1,
    //Picos parameters
    parameter MAX_ARGS_PER_TASK = 15,
    parameter MAX_DEPS_PER_TASK = 8,
    parameter MAX_COPS_PER_TASK = 15,
    parameter NUM_DCTS = 1,
    parameter TM_SIZE = 128,
    parameter DM_SIZE = 512,
    parameter VM_SIZE = 512,
    parameter DM_DS = "BINTREE",
    parameter DM_HASH = "P_PEARSON",
    parameter HASH_T_SIZE = 64,
    //localparams
    localparam ACC_BITS = $clog2(MAX_ACCS)
) (
    //Clock and resets
    input  clk,
    input  rstn,
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
    input  [31:0] bitinfo_dout,
    //AXI Lite interface
    input axilite_arvalid,
    output axilite_arready,
    input [13:0] axilite_araddr,
    input [2:0] axilite_arprot,
    output axilite_rvalid,
    input axilite_rready,
    output [31:0] axilite_rdata,
    output [1:0] axilite_rresp
);

    localparam TW_MEM_BITS = $clog2(MAX_ACC_CREATORS);
    localparam CMDIN_SUBQUEUE_BITS = $clog2(CMDIN_SUBQUEUE_LEN);
    localparam CMDOUT_SUBQUEUE_BITS = $clog2(CMDOUT_SUBQUEUE_LEN);
    localparam CMDIN_QUEUE_BITS = CMDIN_SUBQUEUE_BITS+ACC_BITS;

    wire Command_Out_acc_avail_wr;
    wire [ACC_BITS-1:0] Command_Out_acc_avail_wr_address;
    wire [63:0] Command_Out_outStream_tdata;
    wire Command_Out_outStream_tlast;
    wire Command_Out_outStream_tready;
    wire Command_Out_outStream_tvalid;
    wire [31:0] Command_out_Picos_finish_task_tdata;
    wire Command_out_Picos_finish_task_tready;
    wire Command_out_Picos_finish_task_tvalid;

    wire [CMDIN_QUEUE_BITS-1:0] Command_In_intCmdInQueue_addr;
    wire [63:0] Command_In_intCmdInQueue_din;
    wire [63:0] Command_In_intCmdInQueue_dout;
    wire Command_In_intCmdInQueue_en;
    wire Command_In_intCmdInQueue_we;

    wire [ACC_BITS-1:0] Scheduler_sched_queue_nempty_address;
    wire Scheduler_sched_queue_nempty_write;

    wire [31:0] cmd_in_n_cmds[MAX_ACCS];
    wire [31:0] cmd_out_n_cmds[MAX_ACCS];
    wire [MAX_ACCS-1:0] dbg_acc_avail;
    wire [MAX_ACCS-1:0] dbg_queue_nempty;
    OmpSsManager::DbgRegs_t dbg_regs;

    if (AXILITE_INTF) begin : GEN_AXILITE

        reg [DBG_AVAIL_COUNT_W-1:0] dbg_avail_count[MAX_ACCS];

        if (DBG_AVAIL_COUNT_EN) begin : AVAIL_COUNT_GEN

            always_ff @(posedge clk) begin
                for (int i = 0; i < MAX_ACCS; ++i) begin
                    if (!dbg_acc_avail[i]) begin
                        dbg_avail_count[i] <= dbg_avail_count[i] + {{DBG_AVAIL_COUNT_W-1{1'b0}}, 1'b1};
                    end
                end
                if (!rstn) begin
                    for (int i = 0; i < MAX_ACCS; ++i) begin
                        dbg_avail_count[i] <= {DBG_AVAIL_COUNT_W{1'b0}};
                    end
                end
            end

        end else begin

            always_comb begin
                for (int i = 0; i < MAX_ACCS; ++i) begin
                    dbg_avail_count[i] = {DBG_AVAIL_COUNT_W{1'b0}};
                end
            end

        end

        axilite_controller #(
            .AXI_ADDR_WIDTH(14),
            .MAX_ACCS(MAX_ACCS),
            .DBG_AVAIL_COUNT_W(DBG_AVAIL_COUNT_W)
        ) axilite_controller_I (
            .clk(clk),
            .rstn(rstn),
            .axilite_arvalid(axilite_arvalid),
            .axilite_arready(axilite_arready),
            .axilite_araddr(axilite_araddr),
            .axilite_arprot(axilite_arprot),
            .axilite_rvalid(axilite_rvalid),
            .axilite_rready(axilite_rready),
            .axilite_rdata(axilite_rdata),
            .axilite_rresp(axilite_rresp),
            .dbg_avail_count(dbg_avail_count),
            .dbg_regs(dbg_regs),
            .dbg_acc_avail(dbg_acc_avail),
            .dbg_queue_nempty(dbg_queue_nempty),
            .cmd_in_n_cmds(cmd_in_n_cmds),
            .cmd_out_n_cmds(cmd_out_n_cmds)
        );
    end else begin
        assign axilite_arready = 1'b0;
        assign axilite_rvalid = 1'b0;
        assign axilite_rdata = 32'd0;
        assign axilite_rresp = 2'd0;
    end

    Command_In #(
        .MAX_ACCS(MAX_ACCS),
        .SUBQUEUE_BITS(CMDIN_SUBQUEUE_BITS),
        .DBG_REGS(AXILITE_INTF)
    ) Command_In_I (
        .acc_avail_wr(Command_Out_acc_avail_wr),
        .acc_avail_wr_address(Command_Out_acc_avail_wr_address),
        .clk(clk),
        .cmdin_queue_addr(cmdin_queue_addr),
        .cmdin_queue_clk(cmdin_queue_clk),
        .cmdin_queue_din(cmdin_queue_din),
        .cmdin_queue_dout(cmdin_queue_dout),
        .cmdin_queue_en(cmdin_queue_en),
        .cmdin_queue_rst(cmdin_queue_rst),
        .cmdin_queue_we(cmdin_queue_we),
        .intCmdInQueue_addr(Command_In_intCmdInQueue_addr),
        .intCmdInQueue_din(Command_In_intCmdInQueue_din),
        .intCmdInQueue_dout(Command_In_intCmdInQueue_dout),
        .intCmdInQueue_en(Command_In_intCmdInQueue_en),
        .intCmdInQueue_we(Command_In_intCmdInQueue_we),
        .outStream_TDATA(cmdin_out_tdata),
        .outStream_TDEST(cmdin_out_tdest),
        .outStream_TLAST(cmdin_out_tlast),
        .outStream_TREADY(cmdin_out_tready),
        .outStream_TVALID(cmdin_out_tvalid),
        .rstn(rstn),
        .sched_queue_nempty_address(Scheduler_sched_queue_nempty_address),
        .sched_queue_nempty_write(Scheduler_sched_queue_nempty_write),
        .copy_in_opt(dbg_regs.copy_in_opt),
        .copy_out_opt(dbg_regs.copy_out_opt),
        .dbg_acc_avail(dbg_acc_avail),
        .dbg_queue_nempty(dbg_queue_nempty),
        .num_cmds(cmd_in_n_cmds)
    );

    Command_Out #(
        .MAX_ACCS(MAX_ACCS),
        .SUBQUEUE_BITS(CMDOUT_SUBQUEUE_BITS),
        .DBG_REGS(AXILITE_INTF),
        .PTID_WIDTH(TW_MEM_BITS)
    ) Command_Out_I (
        .acc_avail_wr(Command_Out_acc_avail_wr),
        .acc_avail_wr_address(Command_Out_acc_avail_wr_address),
        .clk(clk),
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
        .picosFinishTask_TDATA(Command_out_Picos_finish_task_tdata),
        .picosFinishTask_TREADY(Command_out_Picos_finish_task_tready),
        .picosFinishTask_TVALID(Command_out_Picos_finish_task_tvalid),
        .rstn(rstn),
        .num_cmds(cmd_out_n_cmds)
    );

    if (LOCK_SUPPORT) begin : GEN_LOCK
        Lock #(
            .ACC_BITS(ACC_BITS)
        ) Lock_I (
            .clk(clk),
            .inStream_TDATA(lock_in_tdata),
            .inStream_TID(lock_in_tid),
            .inStream_TREADY(lock_in_tready),
            .inStream_TVALID(lock_in_tvalid),
            .outStream_TDATA(lock_out_tdata),
            .outStream_TDEST(lock_out_tdest),
            .outStream_TLAST(lock_out_tlast),
            .outStream_TREADY(lock_out_tready),
            .outStream_TVALID(lock_out_tvalid),
            .rstn(rstn)
        );
    end else begin
        assign lock_in_tready = 1'b0;
        assign lock_out_tvalid = 1'b0;
        assign lock_out_tdata = '0;
        assign lock_out_tdest = '0;
        assign lock_out_tlast = 1'b0;
    end

    if (ENABLE_TASK_CREATION) begin : GEN_TCREATION

       localparam TW_MEM_WIDTH = 32;

        wire [31:0] Scheduler_picosRejectTask_id;
        wire Scheduler_picosRejectTask_valid;
        wire [63:0] Scheduler_inStream_tdata;
        wire [ACC_BITS-1:0] Scheduler_inStream_tid;
        wire Scheduler_inStream_tlast;
        wire Scheduler_inStream_tready;
        wire Scheduler_inStream_tvalid;
        wire [CMDIN_QUEUE_BITS-1:0] Scheduler_intCmdInQueue_addr;
        wire [63:0] Scheduler_intCmdInQueue_din;
        wire [63:0] Scheduler_intCmdInQueue_dout;
        wire Scheduler_intCmdInQueue_en;
        wire Scheduler_intCmdInQueue_we;
        wire Scheduler_outStream_tvalid;
        wire Scheduler_outStream_tready;
        wire [ACC_BITS-1:0] Scheduler_outStream_tdest;
        wire [63:0] Scheduler_outStream_tdata;
        wire Scheduler_outStream_tlast;

        wire [63:0] Cutoff_ack_tdata;
        wire [ACC_BITS-1:0] Cutoff_ack_tdest;
        wire Cutoff_ack_tready;
        wire Cutoff_ack_tvalid;
        wire [63:0] Cutoff_Sched_inStream_tdata;
        wire [ACC_BITS-1:0] Cutoff_Sched_inStream_tid;
        wire Cutoff_Sched_inStream_tlast;
        wire Cutoff_Sched_inStream_tready;
        wire Cutoff_Sched_inStream_tvalid;
        wire [TW_MEM_BITS-1:0] Cutoff_tw_info_addr;
        wire [TW_MEM_WIDTH-1:0] Cutoff_tw_info_din;
        wire [TW_MEM_WIDTH-1:0] Cutoff_tw_info_dout;
        wire Cutoff_tw_info_en;
        wire Cutoff_tw_info_we;

        wire [63:0] new_task_tdata;
        wire new_task_tready;
        wire new_task_tvalid;
        wire Picos_picos_full;
        wire [31:0] Picos_finish_task_tdata;
        wire Picos_finish_task_tready;
        wire Picos_finish_task_tvalid;
        wire [63:0] Picos_ready_task_tdata;
        wire Picos_ready_task_tlast;
        wire Picos_ready_task_tready;
        wire Picos_ready_task_tvalid;

        wire [63:0] Spawn_In_outStream_tdata;
        wire Spawn_In_outStream_tlast;
        wire Spawn_In_outStream_tready;
        wire Spawn_In_outStream_tvalid;
        wire [31:0] Spawn_in_Picos_finish_task_tdata;
        wire Spawn_in_Picos_finish_task_tvalid;
        wire Spawn_in_Picos_finish_task_tready;

        wire [63:0] Taskwait_inStream_tdata;
        wire Taskwait_inStream_tvalid;
        wire Taskwait_inStream_tready;
        wire [ACC_BITS-1:0] Taskwait_inStream_tid;
        wire [TW_MEM_BITS-1:0] Taskwait_twInfo_addr;
        wire [TW_MEM_WIDTH-1:0] Taskwait_twInfo_din;
        wire [TW_MEM_WIDTH-1:0] Taskwait_twInfo_dout;
        wire Taskwait_twInfo_en;
        wire Taskwait_twInfo_we;

        Cutoff_Manager #(
            .ACC_BITS(ACC_BITS),
            .MAX_ACC_CREATORS(MAX_ACC_CREATORS),
            .MAX_DEPS_PER_TASK(MAX_DEPS_PER_TASK)
        ) Cutoff_Manager_I (
            .ack_tdata(Cutoff_ack_tdata),
            .ack_tdest(Cutoff_ack_tdest),
            .ack_tready(Cutoff_ack_tready),
            .ack_tvalid(Cutoff_ack_tvalid),
            .clk(clk),
            .deps_new_task_tdata(new_task_tdata),
            .deps_new_task_tready(new_task_tready),
            .deps_new_task_tvalid(new_task_tvalid),
            .inStream_tdata(spawn_in_tdata),
            .inStream_tid(spawn_in_tid),
            .inStream_tlast(spawn_in_tlast),
            .inStream_tready(spawn_in_tready),
            .inStream_tvalid(spawn_in_tvalid),
            .picos_full(Picos_picos_full),
            .rstn(rstn),
            .sched_inStream_tdata(Cutoff_Sched_inStream_tdata),
            .sched_inStream_tid(Cutoff_Sched_inStream_tid),
            .sched_inStream_tlast(Cutoff_Sched_inStream_tlast),
            .sched_inStream_tready(Cutoff_Sched_inStream_tready),
            .sched_inStream_tvalid(Cutoff_Sched_inStream_tvalid),
            .tw_info_addr(Cutoff_tw_info_addr),
            .tw_info_din(Cutoff_tw_info_din),
            .tw_info_dout(Cutoff_tw_info_dout),
            .tw_info_en(Cutoff_tw_info_en),
            .tw_info_we(Cutoff_tw_info_we)
        );

        if (ENABLE_DEPS) begin : GEN_DEPS
            picos_top #(
                .MAX_ARGS_PER_TASK(MAX_ARGS_PER_TASK),
                .MAX_DEPS_PER_TASK(MAX_DEPS_PER_TASK),
                .MAX_COPS_PER_TASK(MAX_COPS_PER_TASK),
                .NUM_DCTS(NUM_DCTS),
                .TM_SIZE(TM_SIZE),
                .DM_SIZE(DM_SIZE),
                .VM_SIZE(VM_SIZE),
                .DM_DS(DM_DS),
                .DM_HASH(DM_HASH),
                .HASH_T_SIZE(HASH_T_SIZE),
                .PTID_WIDTH(TW_MEM_BITS)
            ) Picos_I (
                .clk(clk),
                .finish_task_tdata(Picos_finish_task_tdata),
                .finish_task_tready(Picos_finish_task_tready),
                .finish_task_tvalid(Picos_finish_task_tvalid),
                .new_task_tdata(new_task_tdata),
                .new_task_tready(new_task_tready),
                .new_task_tvalid(new_task_tvalid),
                .picos_full(Picos_picos_full),
                .ready_task_tdata(Picos_ready_task_tdata),
                .ready_task_tlast(Picos_ready_task_tlast),
                .ready_task_tready(Picos_ready_task_tready),
                .ready_task_tvalid(Picos_ready_task_tvalid),
                .retry_id(Scheduler_picosRejectTask_id),
                .retry_valid(Scheduler_picosRejectTask_valid),
                .rstn(rstn)
            );
        end else begin
            assign Picos_finish_task_tready = 1'b0;
            assign new_task_tready = 1'b0;
            assign Picos_ready_task_tvalid = 1'b0;
            assign Picos_ready_task_tdata = '0;
            assign Picos_ready_task_tlast = 1'b0;
        end

        Scheduler #(
            .MAX_ACCS(MAX_ACCS),
            .SUBQUEUE_LEN(CMDIN_SUBQUEUE_LEN),
            .MAX_ACC_TYPES(MAX_ACC_TYPES),
            .SPAWNOUT_QUEUE_LEN(SPAWNOUT_QUEUE_LEN),
            .ENABLE_SPAWN_QUEUES(ENABLE_SPAWN_QUEUES)
        ) Scheduler_I (
            .bitinfo_addr(bitinfo_addr),
            .bitinfo_clk(bitinfo_clk),
            .bitinfo_dout(bitinfo_dout),
            .bitinfo_en(bitinfo_en),
            .bitinfo_rst(bitinfo_rst),
            .clk(clk),
            .inStream_TDATA(Scheduler_inStream_tdata),
            .inStream_TID(Scheduler_inStream_tid),
            .inStream_TLAST(Scheduler_inStream_tlast),
            .inStream_TREADY(Scheduler_inStream_tready),
            .inStream_TVALID(Scheduler_inStream_tvalid),
            .intCmdInQueue_addr(Scheduler_intCmdInQueue_addr),
            .intCmdInQueue_din(Scheduler_intCmdInQueue_din),
            .intCmdInQueue_dout(Scheduler_intCmdInQueue_dout),
            .intCmdInQueue_en(Scheduler_intCmdInQueue_en),
            .intCmdInQueue_we(Scheduler_intCmdInQueue_we),
            .outStream_TDATA(Scheduler_outStream_tdata),
            .outStream_TDEST(Scheduler_outStream_tdest),
            .outStream_TLAST(Scheduler_outStream_tlast),
            .outStream_TREADY(Scheduler_outStream_tready),
            .outStream_TVALID(Scheduler_outStream_tvalid),
            .picosRejectTask_id(Scheduler_picosRejectTask_id),
            .picosRejectTask_valid(Scheduler_picosRejectTask_valid),
            .rstn(rstn),
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

        if (ENABLE_SPAWN_QUEUES) begin
            Spawn_In #(
                .SPAWNIN_QUEUE_LEN(SPAWNIN_QUEUE_LEN)
            ) Spawn_In_I (
                .clk(clk),
                .outStream_TDATA(Spawn_In_outStream_tdata),
                .outStream_TLAST(Spawn_In_outStream_tlast),
                .outStream_TREADY(Spawn_In_outStream_tready),
                .outStream_TVALID(Spawn_In_outStream_tvalid),
                .picosFinishTask_TDATA(Spawn_in_Picos_finish_task_tdata),
                .picosFinishTask_TREADY(Spawn_in_Picos_finish_task_tready),
                .picosFinishTask_TVALID(Spawn_in_Picos_finish_task_tvalid),
                .rstn(rstn),
                .spawnin_queue_addr(spawnin_queue_addr),
                .spawnin_queue_clk(spawnin_queue_clk),
                .spawnin_queue_din(spawnin_queue_din),
                .spawnin_queue_dout(spawnin_queue_dout),
                .spawnin_queue_en(spawnin_queue_en),
                .spawnin_queue_rst(spawnin_queue_rst),
                .spawnin_queue_we(spawnin_queue_we)
            );
        end else begin
            assign Spawn_In_outStream_tvalid = 1'b0;
            assign Spawn_In_outStream_tdata = 64'd0;
            assign Spawn_In_outStream_tlast = 1'b0;
            assign Spawn_in_Picos_finish_task_tvalid = 1'b0;
            assign Spawn_in_Picos_finish_task_tdata = 32'd0;
            assign spawnin_queue_addr = 32'd0;
            assign spawnin_queue_clk = 1'b0;
            assign spawnin_queue_din = 64'd0;
            assign spawnin_queue_en = 1'b0;
            assign spawnin_queue_rst = 1'b0;
            assign spawnin_queue_we = 8'd0;
        end

        Taskwait #(
            .ACC_BITS(ACC_BITS),
            .MAX_ACC_CREATORS(MAX_ACC_CREATORS)
        ) Taskwait_I (
            .clk(clk),
            .inStream_TDATA(Taskwait_inStream_tdata),
            .inStream_TID(Taskwait_inStream_tid),
            .inStream_TREADY(Taskwait_inStream_tready),
            .inStream_TVALID(Taskwait_inStream_tvalid),
            .outStream_TDATA(taskwait_out_tdata),
            .outStream_TDEST(taskwait_out_tdest),
            .outStream_TREADY(taskwait_out_tready),
            .outStream_TVALID(taskwait_out_tvalid),
            .rstn(rstn),
            .twInfo_addr(Taskwait_twInfo_addr),
            .twInfo_din(Taskwait_twInfo_din),
            .twInfo_dout(Taskwait_twInfo_dout),
            .twInfo_en(Taskwait_twInfo_en),
            .twInfo_we(Taskwait_twInfo_we)
        );
        assign taskwait_out_tlast = 1'b1;

        dual_port_mem_wrapper #(
            .SIZE(CMDIN_SUBQUEUE_LEN*MAX_ACCS),
            .WIDTH(64),
            .MODE_A("READ_FIRST"),
            .MODE_B("READ_FIRST"),
            .EN_RST_A(0),
            .EN_RST_B(0),
            .SINGLE_PORT(0)
        ) intCmdInQueue (
            .clk(clk),
            .rstA(1'b0),
            .rstB(1'b0),
            .addrA(Command_In_intCmdInQueue_addr),
            .addrB(Scheduler_intCmdInQueue_addr),
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
            .MODE_B("READ_FIRST"),
            .EN_RST_A(0),
            .EN_RST_B(0),
            .SINGLE_PORT(0)
        ) tw_info (
            .clk(clk),
            .rstA(1'b0),
            .rstB(1'b0),
            .addrA(Taskwait_twInfo_addr),
            .addrB(Cutoff_tw_info_addr),
            .dinA(Taskwait_twInfo_din),
            .dinB(Cutoff_tw_info_din),
            .doutA(Taskwait_twInfo_dout),
            .doutB(Cutoff_tw_info_dout),
            .enA(Taskwait_twInfo_en),
            .enB(Cutoff_tw_info_en),
            .weA(Taskwait_twInfo_we),
            .weB(Cutoff_tw_info_we)
        );

        axis_switch_picos_finish_task #(
            .ENABLE_SPAWN_QUEUES(ENABLE_SPAWN_QUEUES)
        ) Picos_finish_task_Inter (
            .clk(clk),
            .rstn(rstn),
            .S00_AXIS_tvalid(Command_out_Picos_finish_task_tvalid),
            .S00_AXIS_tready(Command_out_Picos_finish_task_tready),
            .S00_AXIS_tdata(Command_out_Picos_finish_task_tdata),
            .S01_AXIS_tvalid(Spawn_in_Picos_finish_task_tvalid),
            .S01_AXIS_tready(Spawn_in_Picos_finish_task_tready),
            .S01_AXIS_tdata(Spawn_in_Picos_finish_task_tdata),
            .M00_AXIS_tvalid(Picos_finish_task_tvalid),
            .M00_AXIS_tready(Picos_finish_task_tready),
            .M00_AXIS_tdata(Picos_finish_task_tdata)
        );

        axis_switch_sched_in #(
            .ENABLE_DEPS(ENABLE_DEPS),
            .ID_WIDTH(ACC_BITS)
        ) Sched_inStream_Inter (
            .clk(clk),
            .rstn(rstn),
            .S00_AXIS_tvalid(Cutoff_Sched_inStream_tvalid),
            .S00_AXIS_tready(Cutoff_Sched_inStream_tready),
            .S00_AXIS_tdata(Cutoff_Sched_inStream_tdata),
            .S00_AXIS_tid(Cutoff_Sched_inStream_tid),
            .S00_AXIS_tlast(Cutoff_Sched_inStream_tlast),
            .S01_AXIS_tvalid(Picos_ready_task_tvalid),
            .S01_AXIS_tready(Picos_ready_task_tready),
            .S01_AXIS_tdata(Picos_ready_task_tdata),
            .S01_AXIS_tid(Cutoff_Sched_inStream_tid), //This is done on purpose to optimize the design
            .S01_AXIS_tlast(Picos_ready_task_tlast),
            .M00_AXIS_tvalid(Scheduler_inStream_tvalid),
            .M00_AXIS_tready(Scheduler_inStream_tready),
            .M00_AXIS_tdata(Scheduler_inStream_tdata),
            .M00_AXIS_tid(Scheduler_inStream_tid),
            .M00_AXIS_tlast(Scheduler_inStream_tlast)
        );

        axis_switch_taskwait_in #(
            .ENABLE_SPAWN_QUEUES(ENABLE_SPAWN_QUEUES),
            .ID_WIDTH(ACC_BITS)
        ) Taskwait_inStream_Inter (
            .clk(clk),
            .rstn(rstn),
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
            .M00_AXIS_tid(Taskwait_inStream_tid)
        );

        axis_switch_task_create_ack #(
            .DEST_WIDTH(ACC_BITS)
        ) Task_create_ack_Inter (
            .clk(clk),
            .rstn(rstn),
            .S00_AXIS_tvalid(Scheduler_outStream_tvalid),
            .S00_AXIS_tready(Scheduler_outStream_tready),
            .S00_AXIS_tdata(Scheduler_outStream_tdata),
            .S00_AXIS_tdest(Scheduler_outStream_tdest),
            .S01_AXIS_tvalid(Cutoff_ack_tvalid),
            .S01_AXIS_tready(Cutoff_ack_tready),
            .S01_AXIS_tdata(Cutoff_ack_tdata),
            .S01_AXIS_tdest(Cutoff_ack_tdest),
            .M00_AXIS_tvalid(spawn_out_tvalid),
            .M00_AXIS_tready(spawn_out_tready),
            .M00_AXIS_tdata(spawn_out_tdata),
            .M00_AXIS_tdest(spawn_out_tdest)
        );

        assign spawn_out_tlast = 1'b1;

    end else begin
        assign Command_In_intCmdInQueue_dout = '0;
        assign Scheduler_sched_queue_nempty_address = '0;
        assign Scheduler_sched_queue_nempty_write = 1'b0;
        assign Command_Out_outStream_tready = 1'b0;
        assign Command_out_Picos_finish_task_tready = 1'b0;
        assign spawn_in_tready = 1'b0;
        assign taskwait_in_tready = 1'b0;
        assign taskwait_out_tvalid = 1'b0;
        assign taskwait_out_tdata = '0;
        assign taskwait_out_tdest = '0;
        assign taskwait_out_tlast = 1'b0;
        assign spawn_in_tready = 1'b0;
        assign spawn_out_tvalid = 1'b0;
        assign spawn_out_tdata = '0;
        assign spawn_out_tdest = '0;
        assign spawn_out_tlast = 1'b0;
        assign bitinfo_clk = 1'b0;
        assign bitinfo_rst = 1'b0;
        assign bitinfo_en = 1'b0;
        assign bitinfo_addr = '0;
    end

endmodule
