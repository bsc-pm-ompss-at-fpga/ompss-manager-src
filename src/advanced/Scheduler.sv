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


module Scheduler #(
    parameter MAX_ACCS = 16,
    parameter ACC_BITS = $clog2(MAX_ACCS),
    parameter SUBQUEUE_LEN = 64,
    parameter SUBQUEUE_BITS = $clog2(SUBQUEUE_LEN),
    parameter MAX_ACC_TYPES = 16,
    parameter SPAWNOUT_QUEUE_LEN = 1024,
    parameter ENABLE_SPAWN_QUEUES = 1,
    parameter [MAX_ACC_TYPES*8-1:0]  SCHED_COUNT = 0,
    parameter [MAX_ACC_TYPES*8-1:0]  SCHED_ACCID = 0,
    parameter [MAX_ACC_TYPES*32-1:0] SCHED_TTYPE = 0
) (
    input  clk,
    input  rstn,
    //Internal command queue
    output logic [SUBQUEUE_BITS+ACC_BITS-1:0] intCmdInQueue_addr,
    output logic intCmdInQueue_en,
    output logic intCmdInQueue_we,
    output logic [63:0] intCmdInQueue_din,
    input  [63:0] intCmdInQueue_dout,
    //Spawn out queue
    output logic [31:0] spawnout_queue_addr,
    output logic spawnout_queue_en,
    output logic [7:0] spawnout_queue_we,
    output logic [63:0] spawnout_queue_din,
    input [63:0] spawnout_queue_dout,
    output spawnout_queue_clk,
    output spawnout_queue_rst,
    //inStream
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    output inStream_TREADY,
    input  [ACC_BITS-1:0] inStream_TID,
    input  inStream_TLAST,
    //outStream
    output logic [63:0] outStream_TDATA,
    output logic outStream_TVALID,
    input  outStream_TREADY,
    output outStream_TLAST,
    output [ACC_BITS-1:0] outStream_TDEST,
    //Picos reject interface
    output [31:0] picosRejectTask_id,
    output picosRejectTask_valid,
    //Queue not empty interface
    output logic [ACC_BITS-1:0] sched_queue_nempty_address,
    output logic sched_queue_nempty_write
);

    import OmpSsManager::*;
    localparam ACC_TYPE_BITS = $clog2(MAX_ACC_TYPES);

    typedef enum bit [4:0] {
        SCHED_READ_HEADER_1,
        SCHED_READ_HEADER_OTHER_1,
        SCHED_READ_HEADER_OTHER_2,
        SCHED_READ_TASK_ID,
        SCHED_GEN_TASK_ID,
        SCHED_WAIT_SPAWNOUT,
        SCHED_ASSIGN_SEARCH,
        SCHED_ASSIGN_ACCID,
        SCHED_ASSIGN,
        SCHED_CMDIN_CHECK,
        SCHED_CMDIN_READ,
        SCHED_READ_REST,
        SCHED_CMDIN_WRITE_1,
        SCHED_CMDIN_WRITE_2,
        SCHED_READ_COPS_1,
        SCHED_READ_COPS_2,
        SCHED_READ_COPS_3,
        SCHED_CMDIN_WRITE_FLAGS,
        SCHED_CMDIN_WRITE_ARG,
        SCHED_CMDIN_WRITE_4,
        SCHED_ACCEPT_TASK,
        SCHED_REJECT_TASK
    } State_t;

    State_t state;

    struct packed {
        logic [SUBQUEUE_BITS-1:0] wIdx;       //< Slot where the current task creation starts
        logic [SUBQUEUE_BITS-1:0] rIdx;       //< Slot where the last known read task starts
        logic [SUBQUEUE_BITS  :0] availSlots; //< Number of available slots in the subqueue
    } subqueue_info[MAX_ACCS];

    reg [1:0] bufferArgFlags[15];
    reg [1:0] cur_flag;

    reg spawnout_state_start;
    wire [1:0] spawnout_ret; //0 wait, 1 ok, 2 reject
    wire inStream_spawnout_TREADY;
    logic inStream_main_TREADY;

    reg [ACC_BITS-1:0] last_acc_id[MAX_ACC_TYPES];
    reg [ACC_BITS-1:0] accID;         //< Accelerator ID where the current task will be executed
    reg [ACC_BITS-1:0] srcAccID;
    reg [ACC_BITS-1:0] scheddata_type_count;
    reg [ACC_BITS-1:0] scheddata_type_first;
    reg comes_from_dep_mod;  //< The incoming task is sent by the dependencies module
    reg [31:0] last_task_id; //< Last assigned task identifier to tasks created inside the FPGA
    reg [3:0] num_args;
    reg [3:0] count_args;
    reg [3:0] arg_idx;
    reg [3:0] num_deps;
    reg [3:0] num_cops;
    reg [3:0] count_cops;
    reg [63:0] taskID;
    reg [63:0] pTaskID;
    reg [SCHED_TASKTYPE_BITS-1:0] task_type;
    reg [SCHED_ARCHBITS_BITS-1:0] task_arch;
    reg [SCHED_INSNUM_BITS-1:0] task_instance_num;
    reg [5:0] needed_slots;
    reg [SUBQUEUE_BITS-1:0] rIdx;
    reg [SUBQUEUE_BITS-1:0] wIdx;
    reg [SUBQUEUE_BITS-1:0] wIdx_copy;
    reg [SUBQUEUE_BITS  :0] avail_slots;
    reg [63:0] inStream_data_buf;
    reg inStream_last_buf;
    wire [ACC_BITS-1:0] next_acc_id;
    wire [5:0] cmd_num_slots;
    wire [SUBQUEUE_BITS-1:0] next_wIdx;

    reg [ACC_TYPE_BITS-1:0] data_idx;
    reg [ACC_TYPE_BITS-1:0] data_idx_d;
    wire [7:0] sched_count[MAX_ACC_TYPES];
    wire [7:0] sched_accid[MAX_ACC_TYPES];
    wire [31:0] sched_ttype[MAX_ACC_TYPES];

    for (genvar i = 0; i < MAX_ACC_TYPES; ++i) begin
        assign sched_count[i] = SCHED_COUNT[i*8 +: 8];
        assign sched_accid[i] = SCHED_ACCID[i*8 +: 8];
        assign sched_ttype[i] = SCHED_TTYPE[i*32 +: 32];
    end

    assign spawnout_queue_rst = 1'b0;

    if (ENABLE_SPAWN_QUEUES) begin
        assign spawnout_queue_clk = clk;

        Scheduler_spawnout #(
            .QUEUE_LEN(SPAWNOUT_QUEUE_LEN),
            .ARCHBITS_BITS(SCHED_ARCHBITS_BITS),
            .TASKTYPE_BITS(SCHED_TASKTYPE_BITS)
        ) sched_spawnout (
            .*
        );
    end else begin
        assign spawnout_queue_addr = 32'd0;
        assign spawnout_queue_en = 1'b0;
        assign spawnout_queue_we = 8'd0;
        assign spawnout_queue_din = 64'd0;
        assign spawnout_queue_clk = 1'b0;

        assign inStream_spawnout_TREADY = 1'b0;
        assign spawnout_ret = 2'd2;
    end

    assign inStream_TREADY = inStream_main_TREADY | inStream_spawnout_TREADY;

    assign next_acc_id = last_acc_id[data_idx_d] + 1;
    assign intCmdInQueue_addr[SUBQUEUE_BITS+ACC_BITS-1:SUBQUEUE_BITS] = accID;
    assign cmd_num_slots = 6'd3 + {1'd0, intCmdInQueue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
    assign next_wIdx = wIdx + 1;
    assign outStream_TDEST = srcAccID;
    assign outStream_TLAST = 1'b1;
    assign picosRejectTask_id = taskID[31:0];
    assign picosRejectTask_valid = state == SCHED_REJECT_TASK && comes_from_dep_mod;

    always_comb begin

        intCmdInQueue_addr[SUBQUEUE_BITS-1:0] = wIdx[SUBQUEUE_BITS-1:0];
        intCmdInQueue_en = 0;
        intCmdInQueue_we = 0;
        intCmdInQueue_din = taskID;

        inStream_main_TREADY = 0;

        outStream_TVALID = 0;
        outStream_TDATA = {56'd0, ACK_REJECT_CODE};

        case (state)

            SCHED_READ_HEADER_1: begin
                inStream_main_TREADY = 1;
            end

            SCHED_READ_TASK_ID: begin
                inStream_main_TREADY = 1;
            end

            SCHED_READ_HEADER_OTHER_1: begin
                inStream_main_TREADY = 1;
            end

            SCHED_READ_HEADER_OTHER_2: begin
                inStream_main_TREADY = 1;
            end

            SCHED_READ_REST: begin
                inStream_main_TREADY = 1;
            end

            SCHED_CMDIN_CHECK: begin
                intCmdInQueue_en = 1;
                intCmdInQueue_addr[SUBQUEUE_BITS-1:0] = rIdx;
            end

            SCHED_CMDIN_WRITE_1: begin
                intCmdInQueue_en = 1;
                intCmdInQueue_we = 1;
            end

            SCHED_CMDIN_WRITE_2: begin
                intCmdInQueue_en = 1;
                intCmdInQueue_we = 1;
                intCmdInQueue_din = pTaskID;
            end

            SCHED_READ_COPS_1: begin
                inStream_main_TREADY = 1;
            end

            SCHED_READ_COPS_2: begin
                inStream_main_TREADY = 1;
            end

            SCHED_CMDIN_WRITE_FLAGS: begin
                inStream_main_TREADY = 1;
                intCmdInQueue_en = 1;
                intCmdInQueue_we = 1;
                intCmdInQueue_din[63:ARG_IDX_H+1] = 0;
                intCmdInQueue_din[ARG_IDX_H:ARG_IDX_L] = arg_idx;
                intCmdInQueue_din[ARG_FLAG_H:ARG_FLAG_L] = {2'd0, cur_flag, 4'd0};
            end

            SCHED_CMDIN_WRITE_ARG: begin
                intCmdInQueue_en = 1;
                intCmdInQueue_we = 1;
                intCmdInQueue_din = inStream_data_buf;
            end

            SCHED_CMDIN_WRITE_4: begin
                intCmdInQueue_en = 1;
                intCmdInQueue_we = 1;
                intCmdInQueue_din[ENTRY_VALID_OFFSET] = 1;
                intCmdInQueue_din[DESTID_H:DESTID_L] = HWR_CMDOUT_ID_BYTE;
                intCmdInQueue_din[COMPF_H:COMPF_L] = 8'h01;
                intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] = {4'd0, num_args};
                intCmdInQueue_din[CMD_TYPE_L+7:CMD_TYPE_L] = 8'h1;
            end

            SCHED_REJECT_TASK: begin
                outStream_TVALID = !comes_from_dep_mod;
            end

            SCHED_ACCEPT_TASK: begin
                outStream_TDATA = {56'd0, ACK_OK_CODE};
                outStream_TVALID = !comes_from_dep_mod;
            end

            default: begin

            end

        endcase
    end

    always_ff @(posedge clk) begin

        sched_queue_nempty_write <= 0;

        inStream_data_buf <= inStream_TDATA;
        inStream_last_buf <= inStream_TLAST;

        spawnout_state_start <= 0;

        data_idx_d <= data_idx;

        case (state)

            SCHED_READ_HEADER_1: begin
                int i;
                for (i = 0; i < 15; i = i+1) begin
                    bufferArgFlags[i] <= 2'b11;
                end
                count_cops <= 0;
                count_args <= 1;
                srcAccID <= inStream_TID;
                arg_idx <= 0;
                data_idx <= 0;
                comes_from_dep_mod <= inStream_TDATA[0];
                num_args <= inStream_TDATA[NUM_ARGS_OFFSET+3 : NUM_ARGS_OFFSET];
                num_deps <= inStream_TDATA[NUM_DEPS_OFFSET+3 : NUM_DEPS_OFFSET];
                num_cops <= inStream_TDATA[NUM_COPS_OFFSET+3 : NUM_COPS_OFFSET];
                if (inStream_TVALID) begin
                    state <= inStream_TDATA[0] ? SCHED_READ_TASK_ID : SCHED_GEN_TASK_ID;
                end
            end

            SCHED_READ_TASK_ID: begin
                taskID <= {32'hB0000000, inStream_TDATA[31:0]};
                if (inStream_TVALID) begin
                    state <= SCHED_READ_HEADER_OTHER_1;
                end
            end

            //This state could be removed
            SCHED_GEN_TASK_ID: begin
                taskID <= {28'hF000000, last_task_id, 4'hF};
                state <= SCHED_READ_HEADER_OTHER_1;
            end

            SCHED_READ_HEADER_OTHER_1: begin
                pTaskID <= inStream_TDATA;
                if (inStream_TVALID) begin
                    state <= SCHED_READ_HEADER_OTHER_2;
                end
            end

            SCHED_READ_HEADER_OTHER_2: begin
                task_type <= inStream_TDATA[CMD_NEWTASK_TASKTYPE_H:CMD_NEWTASK_TASKTYPE_L];
                task_arch <= inStream_TDATA[CMD_NEWTASK_ARCHBITS_H:CMD_NEWTASK_ARCHBITS_L];
                task_instance_num <= inStream_TDATA[CMD_NEWTASK_INSNUM_H:CMD_NEWTASK_INSNUM_L];
                data_idx_d <= 0;
                if (inStream_TVALID) begin
                    //If task is not an FPGA task or has deps forward to spawnOut queue
                    if (ENABLE_SPAWN_QUEUES && (inStream_TDATA[CMD_NEWTASK_ARCHBITS_FPGA_B] == 0 || num_deps != 0)) begin
                        spawnout_state_start <= 1;
                        state <= SCHED_WAIT_SPAWNOUT;
                    end else begin
                        state <= SCHED_ASSIGN_SEARCH;
                    end
                end
            end

            SCHED_WAIT_SPAWNOUT: begin
                if (spawnout_ret == 2'd1) begin
                    last_task_id <= last_task_id + 1;
                    state <= SCHED_ACCEPT_TASK;
                end else if (spawnout_ret == 2'd2) begin
                    if (num_deps != 0 || num_args != 0 || num_cops != 0) begin
                        state <= SCHED_READ_REST;
                    end else begin
                        state <= SCHED_REJECT_TASK;
                    end
                end
            end

            SCHED_ASSIGN_SEARCH: begin
                data_idx <= data_idx + 1;
                scheddata_type_count <= sched_count[data_idx];
                scheddata_type_first <= sched_accid[data_idx];
                if (sched_ttype[data_idx] == task_type) begin
                    state <= SCHED_ASSIGN_ACCID;
                end
            end

            SCHED_ASSIGN_ACCID: begin
                if (task_instance_num != SCHED_INSNUM_ANY) begin
                    accID <= scheddata_type_first + task_instance_num;
                    last_acc_id[data_idx_d] <= task_instance_num;
                end else begin
                    accID <= scheddata_type_first + last_acc_id[data_idx_d];
                    if (last_acc_id[data_idx_d] == scheddata_type_count) begin
                        last_acc_id[data_idx_d] <= 0;
                    end else begin
                        last_acc_id[data_idx_d] <= next_acc_id;
                    end
                end
                state <= SCHED_ASSIGN;
            end

            SCHED_ASSIGN: begin
                needed_slots <= 6'd3 + {1'd0, num_args, 1'd0};
                rIdx <= subqueue_info[accID].rIdx;
                wIdx <= subqueue_info[accID].wIdx;
                avail_slots <= subqueue_info[accID].availSlots;
                state <= SCHED_CMDIN_CHECK;
            end

            SCHED_CMDIN_CHECK: begin
                wIdx_copy <= wIdx;
                if (needed_slots <= avail_slots) begin
                    wIdx <= next_wIdx;
                    state <= SCHED_CMDIN_WRITE_1;
                end else begin
                    state <= SCHED_CMDIN_READ;
                end
            end

            SCHED_CMDIN_READ: begin
                if (!intCmdInQueue_dout[ENTRY_VALID_OFFSET]) begin
                    rIdx <= rIdx + cmd_num_slots;
                    avail_slots <= avail_slots + cmd_num_slots;
                    state <= SCHED_CMDIN_CHECK;
                end else begin
                    if (num_args != 0 || num_cops != 0) begin
                        state <= SCHED_READ_REST;
                    end else begin
                        state <= SCHED_REJECT_TASK;
                    end
                end
            end

            SCHED_READ_REST: begin
                if (inStream_TVALID && inStream_TLAST) begin
                    state <= SCHED_REJECT_TASK;
                end
            end

            SCHED_REJECT_TASK: begin
                if (comes_from_dep_mod || outStream_TREADY) begin
                    state <= SCHED_READ_HEADER_1;
                end
            end

            SCHED_CMDIN_WRITE_1: begin
                avail_slots <= avail_slots - needed_slots;
                wIdx <= next_wIdx;
                state <= SCHED_CMDIN_WRITE_2;
            end

            SCHED_CMDIN_WRITE_2: begin
                subqueue_info[accID].rIdx <= rIdx;
                subqueue_info[accID].availSlots <= avail_slots;
                if (num_args == 0) begin
                    wIdx_copy <= next_wIdx;
                    wIdx <= wIdx_copy;
                end else begin
                    wIdx <= next_wIdx;
                end
                //Cmd in queue holds ready tasks only (no dependencies)
                if (num_cops != 0) begin
                    state <= SCHED_READ_COPS_1;
                end else if (num_args != 0) begin
                    state <= SCHED_CMDIN_WRITE_FLAGS;
                end else begin
                    state <= SCHED_CMDIN_WRITE_4;
                end
            end

            //Address
            SCHED_READ_COPS_1: begin
                if (inStream_TVALID) begin
                    state <= SCHED_READ_COPS_2;
                end
            end

            //[ size | padding | arg_idx | flags ]
            SCHED_READ_COPS_2: begin
                bufferArgFlags[inStream_TDATA[11:8]] <= inStream_TDATA[1:0];
                if (inStream_TDATA[11:8] == 4'd0) begin
                    cur_flag <= inStream_TDATA[1:0];
                end else begin
                    cur_flag <= bufferArgFlags[0];
                end
                if (inStream_TVALID) begin
                    count_cops <= count_cops + 4'd1;
                    if (count_cops+4'd1 == num_cops) begin
                        if (num_args != 0) begin
                            state <= SCHED_CMDIN_WRITE_FLAGS;
                        end else begin
                            state <= SCHED_CMDIN_WRITE_4;
                        end
                    end else begin
                        state <= SCHED_READ_COPS_1;
                    end
                end
            end

            SCHED_CMDIN_WRITE_FLAGS: begin
                if (inStream_TVALID) begin
                    state <= SCHED_CMDIN_WRITE_ARG;
                    wIdx <= next_wIdx;
                end
            end

            SCHED_CMDIN_WRITE_ARG: begin
                arg_idx <= arg_idx + 1;
                cur_flag <= bufferArgFlags[count_args];
                count_args <= count_args+1;
                if (inStream_last_buf) begin
                    wIdx <= wIdx_copy;
                    wIdx_copy <= next_wIdx;
                    state <= SCHED_CMDIN_WRITE_4;
                end else begin
                    wIdx <= next_wIdx;
                    state <= SCHED_CMDIN_WRITE_FLAGS;
                end
            end

            SCHED_CMDIN_WRITE_4: begin
                subqueue_info[accID].wIdx <= wIdx_copy;
                sched_queue_nempty_write <= 1;
                sched_queue_nempty_address[ACC_BITS-1:0] <= accID;
                last_task_id <= last_task_id + 1;
                state <= SCHED_ACCEPT_TASK;
            end

            SCHED_ACCEPT_TASK: begin
                if (comes_from_dep_mod || outStream_TREADY) begin
                    state <= SCHED_READ_HEADER_1;
                end
            end

        endcase

        if (!rstn) begin
            int i;
            for (i = 0; i < MAX_ACCS; i = i+1) begin
                subqueue_info[i].rIdx <= 0;
                subqueue_info[i].wIdx <= 0;
                subqueue_info[i].availSlots <= SUBQUEUE_LEN;
            end
            for (i = 0; i < MAX_ACC_TYPES; i = i+1) begin
                last_acc_id[i] <= 0;
            end
            last_task_id <= 0;
            state <= SCHED_READ_HEADER_1;
        end

    end

endmodule
