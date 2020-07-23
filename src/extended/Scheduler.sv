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

module Scheduler
(
    input  ap_clk,
    input  ap_rst_n,
    //Internal command queue
    output logic [9:0] intCmdInQueue_V_address0,
    output logic intCmdInQueue_V_ce0,
    output logic intCmdInQueue_V_we0,
    output logic [63:0] intCmdInQueue_V_d0,
    input  [63:0] intCmdInQueue_V_q0,
    output intCmdInQueue_clk,
    //Spawn out queue
    output logic [31:0] spawnOutQueue_Addr,
    output logic spawnOutQueue_EN,
    output logic [7:0] spawnOutQueue_WEN,
    output logic [63:0] spawnOutQueue_Din,
    input [63:0] spawnOutQueue_Dout,
    output spawnOutQueue_Clk,
    output spawnOutQueue_Rst,
    //Bitinfo memory
    output [31:0] bitinfo_addr,
    output bitinfo_en,
    input [31:0] bitinfo_dout,
    output bitinfo_clk,
    output bitinfo_rst,
    //inStream
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    output inStream_TREADY,
    input  [3:0] inStream_TID,
    input  inStream_TLAST,
    //outStream
    output logic [7:0] outStream_TDATA,
    output logic outStream_TVALID,
    input  outStream_TREADY,
    output [3:0] outStream_TDEST,
    //Picos reject interface
    output [31:0] picosRejectTask,
    output picosRejectTask_ap_vld,
    //Queue not empty interface
    output logic [3:0] sched_queue_nempty_addr,
    output logic sched_queue_nempty_write
);

    import OmpSsManager::*;

    localparam ACC_BITS = $clog2(MAX_ACCS);

    enum {
        SCHED_READ_HEADER_1,
        SCHED_READ_HEADER_OTHER_1,
        SCHED_READ_HEADER_OTHER_2,
        SCHED_READ_TASK_ID,
        SCHED_GEN_TASK_ID,
        SCHED_WAIT_SPAWNOUT,
        SCHED_ASSIGN_SEARCH,
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
    } state;
    
    struct packed {
        logic [SUBQUEUE_BITS-1:0] wIdx;       //< Slot where the current task creation starts
        logic [SUBQUEUE_BITS-1:0] rIdx;       //< Slot where the last known read task starts
        logic [SUBQUEUE_BITS  :0] availSlots; //< Number of available slots in the subqueue
    } subqueue_info[MAX_ACCS];
    
    reg [1:0] bufferArgFlags[15];
    reg [1:0] cur_flag;
    reg [3:0] arg_flag_idx;
    
    reg spawnout_state_start;
    wire [1:0] spawnout_ret; //0 wait, 1 ok, 2 reject
    wire inStream_spawnout_TREADY;
    logic inStream_main_TREADY;
    
    reg [ACC_BITS-1:0] last_acc_id[MAX_ACCS_TYPES];
    reg [ACC_BITS-1:0] accID;         //< Accelerator ID where the current task will be executed
    reg [ACC_BITS-1:0] srcAccID;
    reg [ACC_BITS-1:0] count;
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
    reg [33:0] task_type;
    reg [3:0] data_idx;
    reg [3:0] data_idx_d;
    reg [5:0] needed_slots;
    reg [SUBQUEUE_BITS-1:0] rIdx;
    reg [SUBQUEUE_BITS-1:0] wIdx;
    reg [SUBQUEUE_BITS-1:0] wIdx_copy;
    reg [SUBQUEUE_BITS  :0] avail_slots;
    reg [63:0] inStream_data_buf;
    reg inStream_last_buf;
    wire [ACC_BITS-1:0] next_acc_id;
    wire [5:0] tmp_num_slots;
    wire [SUBQUEUE_BITS-1:0] next_wIdx;
    
    wire [ACC_BITS-1:0] scheduleData_address1;
    wire scheduleData_ce1;
    wire [49:0] scheduleData_q1;
    wire [ACC_BITS-1:0] scheduleData_address0;
    wire scheduleData_ce0;
    wire [49:0] scheduleData_d0;
    
    Scheduler_spawnout sched_spawnout (
        .*
    );
    
    Scheduler_sched_info_mem sched_info_mem (
        .*
    );
    
    Scheduler_parse_bitinfo bitinfo_parser (
        .*
    );
    
    assign bitinfo_clk = ap_clk;
    assign bitinfo_rst = 0;
    
    assign intCmdInQueue_clk = ap_clk;
    
    assign inStream_TREADY = inStream_main_TREADY | inStream_spawnout_TREADY;
    
    assign spawnOutQueue_Rst = 0;
    assign spawnOutQueue_Clk = ap_clk;
    
    if (ACC_BITS != 4) begin
        assign intCmdInQueue_V_address0[9:SUBQUEUE_BITS+ACC_BITS] = 0;
        assign outStream_TDEST[3:ACC_BITS] = 0;
        assign sched_queue_nempty_addr[3:ACC_BITS] = 0;
    end
    
    assign next_acc_id = last_acc_id[data_idx_d] + 1;
    assign intCmdInQueue_V_address0[6+ACC_BITS-1:6] = accID;
    assign tmp_num_slots = 6'd3 + {1'd0, intCmdInQueue_V_q0[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
    assign next_wIdx = wIdx + 1;
    assign scheduleData_address1 = data_idx;
    assign scheduleData_ce1 = state == SCHED_ASSIGN_SEARCH || state == SCHED_READ_HEADER_OTHER_2;
    assign outStream_TDEST[ACC_BITS-1:0] = srcAccID;
    assign picosRejectTask = taskID[31:0];
    assign picosRejectTask_ap_vld = state == SCHED_REJECT_TASK && comes_from_dep_mod;
    
    always_comb begin
    
        intCmdInQueue_V_address0[5:0] = wIdx[5:0];
        intCmdInQueue_V_ce0 = 0;
        intCmdInQueue_V_we0 = 0;
        intCmdInQueue_V_d0 = taskID;
        
        inStream_main_TREADY = 0;
        
        outStream_TVALID = 0;
        outStream_TDATA = ACK_REJECT_CODE;
        
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
                intCmdInQueue_V_ce0 = 1;
                intCmdInQueue_V_address0[5:0] = rIdx;
            end
            
            SCHED_CMDIN_WRITE_1: begin
                intCmdInQueue_V_ce0 = 1;
                intCmdInQueue_V_we0 = 1;
            end
            
            SCHED_CMDIN_WRITE_2: begin
                intCmdInQueue_V_ce0 = 1;
                intCmdInQueue_V_we0 = 1;
                intCmdInQueue_V_d0 = pTaskID;
            end
            
            SCHED_READ_COPS_1: begin
                inStream_main_TREADY = 1;
            end
            
            SCHED_READ_COPS_2: begin
                inStream_main_TREADY = 1;
            end
            
            SCHED_READ_COPS_3: begin
                inStream_main_TREADY = 1;
            end
            
            SCHED_CMDIN_WRITE_FLAGS: begin
                inStream_main_TREADY = 1;
                intCmdInQueue_V_ce0 = 1;
                intCmdInQueue_V_we0 = 1;
                intCmdInQueue_V_d0[63:ARG_IDX_H+1] = 0;
                intCmdInQueue_V_d0[ARG_IDX_H:ARG_IDX_L] = arg_idx;
                intCmdInQueue_V_d0[ARG_FLAG_H:ARG_FLAG_L] = {2'd0, cur_flag, 4'd0};
            end
            
            SCHED_CMDIN_WRITE_ARG: begin
                intCmdInQueue_V_ce0 = 1;
                intCmdInQueue_V_we0 = 1;
                intCmdInQueue_V_d0 = inStream_data_buf;
            end
            
            SCHED_CMDIN_WRITE_4: begin
                intCmdInQueue_V_ce0 = 1;
                intCmdInQueue_V_we0 = 1;
                intCmdInQueue_V_d0[ENTRY_VALID_OFFSET] = 1;
                intCmdInQueue_V_d0[DESTID_H:DESTID_L] = 8'h11;
                intCmdInQueue_V_d0[COMPF_H:COMPF_L] = 8'h01;
                intCmdInQueue_V_d0[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET] = num_args;
                intCmdInQueue_V_d0[CMD_TYPE_L+7:CMD_TYPE_L] = 8'h1;
            end
            
            SCHED_REJECT_TASK: begin
                outStream_TVALID = !comes_from_dep_mod;
            end
            
            SCHED_ACCEPT_TASK: begin
                outStream_TDATA = ACK_OK_CODE;
                outStream_TVALID = !comes_from_dep_mod;
            end
            
            default: begin
            
            end
        
        endcase
    end
    
    always_ff @(posedge ap_clk) begin
    
        sched_queue_nempty_write <= 0;
        
        inStream_data_buf <= inStream_TDATA;
        inStream_last_buf <= inStream_TLAST;
        
        spawnout_state_start <= 0;
    
        case (state)
        
            SCHED_READ_HEADER_1: begin
                count_cops <= 0;
                count_args <= 1;
                srcAccID <= inStream_TID[ACC_BITS-1:0];
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
                last_task_id <= last_task_id + 1;
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
                task_type <= inStream_TDATA[33:0];
                data_idx_d <= 0;
                if (inStream_TVALID) begin
                    if (inStream_TDATA[33] || num_deps != 0) begin
                        spawnout_state_start <= 1;
                        state <= SCHED_WAIT_SPAWNOUT;
                    end else begin
                        state <= SCHED_ASSIGN_SEARCH;
                    end
                    data_idx <= 4'd1;
                end
            end
            
            SCHED_WAIT_SPAWNOUT: begin
                if (spawnout_ret == 2'd1) begin
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
                count <= scheduleData_q1[SCHED_DATA_COUNT_L+ACC_BITS-1:SCHED_DATA_COUNT_L];
                accID <= scheduleData_q1[SCHED_DATA_ACCID_L+ACC_BITS-1:SCHED_DATA_ACCID_L] + last_acc_id[data_idx_d];
                if (scheduleData_q1[SCHED_DATA_TASK_TYPE_H:SCHED_DATA_TASK_TYPE_L] == task_type) begin
                    state <= SCHED_ASSIGN;
                end else begin
                    data_idx_d <= data_idx;
                end
            end
            
            SCHED_ASSIGN: begin
                needed_slots <= 6'd3 + {1'd0, num_args, 1'd0};
                rIdx <= subqueue_info[accID].rIdx;
                wIdx <= subqueue_info[accID].wIdx;
                avail_slots <= subqueue_info[accID].availSlots;
                if (last_acc_id[data_idx_d] == count) begin
                    last_acc_id[data_idx_d] <= 0;
                end else begin
                    last_acc_id[data_idx_d] <= next_acc_id;
                end
                state <= SCHED_CMDIN_CHECK;
            end
            
            SCHED_CMDIN_CHECK: begin
                wIdx_copy <= wIdx;
                if ({1'b0, needed_slots} <= avail_slots) begin
                    wIdx <= next_wIdx;
                    state <= SCHED_CMDIN_WRITE_1;
                end else begin
                    state <= SCHED_CMDIN_READ;
                end
            end
            
            SCHED_CMDIN_READ: begin
                if (!intCmdInQueue_V_q0[ENTRY_VALID_OFFSET]) begin
                    rIdx <= rIdx + tmp_num_slots;
                    avail_slots <= avail_slots + {1'b0, tmp_num_slots};
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
                avail_slots <= avail_slots - {1'b0, needed_slots};
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
                cur_flag <= inStream_TDATA[1:0] != 2'd0 ? inStream_TDATA[1:0] : DEFAULT_ARG_FLAGS;
                arg_flag_idx <= inStream_TDATA[11:8];
                if (inStream_TVALID) begin
                    count_cops <= count_cops + 1;
                    state <= SCHED_READ_COPS_3;
                end
            end
            
            //[ accessed length | offset ]
            SCHED_READ_COPS_3: begin
                bufferArgFlags[arg_flag_idx] <= cur_flag;
                if (inStream_TVALID) begin
                    if (arg_flag_idx != 0) begin
                        cur_flag <= bufferArgFlags[0];
                    end
                    if (count_cops == num_cops) begin
                        if (num_args != 0) begin
                            state <= SCHED_CMDIN_WRITE_FLAGS;
                        end else  begin
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
                sched_queue_nempty_addr[ACC_BITS-1:0] <= accID;
                state <= SCHED_ACCEPT_TASK;
            end
            
            SCHED_ACCEPT_TASK: begin
                if (comes_from_dep_mod || outStream_TREADY) begin
                    state <= SCHED_READ_HEADER_1;
                end
            end
        
        endcase
        
        if (!ap_rst_n) begin
            int i;
            for (i = 0; i < MAX_ACCS; i = i+1) begin
                subqueue_info[i].rIdx <= 0;
                subqueue_info[i].wIdx <= 0;
                subqueue_info[i].availSlots <= 7'd64;
            end
            for (i = 0; i < MAX_ACCS_TYPES; i = i+1) begin
                last_acc_id[i] <= 0;
            end
            last_task_id <= 0;
            state <= SCHED_READ_HEADER_1;
        end
        
    end

endmodule
