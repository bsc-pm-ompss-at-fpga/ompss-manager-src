/*-------------------------------------------------------------------------*/
/*  Copyright (C) 2020-2023 Barcelona Supercomputing Center                */
/*                  Centro Nacional de Supercomputacion (BSC-CNS)          */
/*                                                                         */
/*  This file is part of OmpSs@FPGA toolchain.                             */
/*                                                                         */
/*  This program is free software: you can redistribute it and/or modify   */
/*  it under the terms of the GNU General Public License as published      */
/*  by the Free Software Foundation, either version 3 of the License,      */
/*  or (at your option) any later version.                                 */
/*                                                                         */
/*  This program is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                   */
/*  See the GNU General Public License for more details.                   */
/*                                                                         */
/*  You should have received a copy of the GNU General Public License      */
/*  along with this program. If not, see <https://www.gnu.org/licenses/>.  */
/*-------------------------------------------------------------------------*/

module Scheduler_spawnout #(
    parameter QUEUE_LEN = 1024,
    parameter QUEUE_BITS = $clog2(QUEUE_LEN),
    parameter TASKTYPE_BITS = 32,
    parameter ARCHBITS_BITS = 2
) (
    input  clk,
    input  rstn,
    //Spawn out queue
    output logic [31:0] spawnout_queue_addr,
    output logic spawnout_queue_en,
    output logic [7:0] spawnout_queue_we,
    output logic [63:0] spawnout_queue_din,
    input [63:0] spawnout_queue_dout,
    //inStream
    input  inStream_TVALID,
    output logic inStream_spawnout_TREADY,
    //Other signals
    input [63:0] taskID,
    input [63:0] pTaskID,
    input [TASKTYPE_BITS-1:0] task_type,
    input [ARCHBITS_BITS-1:0] task_arch,
    input [3:0] num_args,
    input [3:0] num_cops,
    input [3:0] num_deps,
    input [63:0] inStream_data_buf,
    input inStream_last_buf,
    input spawnout_state_start,
    output reg [1:0] spawnout_ret //0 wait, 1 ok, 2 reject
);

    import OmpSsManager::*;

    typedef enum bit [3:0] {
        SPAWNOUT_IDLE,
        SPAWNOUT_CHECK,
        SPAWNOUT_READ,
        SPAWNOUT_COMPUTE_CMD_LEN,
        SPAWNOUT_UPDATE_AVAIL_SLOTS,
        SPAWNOUT_WRITE_TASKID,
        SPAWNOUT_WRITE_PTASKID,
        SPAWNOUT_WRITE_TASKTYPE,
        SPAWNOUT_WRITE_REST_1,
        SPAWNOUT_WRITE_REST_2,
        SPAWNOUT_WRITE_HEADER
    } SpawnOutState_t;

    SpawnOutState_t spawnout_state;

    reg [QUEUE_BITS-1:0] header_wIdx;
    reg [QUEUE_BITS-1:0] wIdx;
    reg [QUEUE_BITS-1:0] rIdx;
    wire [QUEUE_BITS-1:0] next_wIdx;
    reg [QUEUE_BITS:0] avail_slots;
    reg [6:0] needed_slots;
    reg [3:0] spawnout_num_deps;
    reg [3:0] spawnout_num_args;
    reg [3:0] spawnout_num_cops;
    reg [5:0] num_slots_1;
    reg [5:0] num_slots_2;
    wire [6:0] num_slots;

    assign num_slots = 7'd4 + {1'd0, num_slots_1} + {1'd0, num_slots_2};
    assign next_wIdx = wIdx + 1;

    always_comb begin

        spawnout_queue_addr = 0;
        spawnout_queue_addr[3 + QUEUE_BITS-1:3] = wIdx;
        spawnout_queue_en = 0;
        spawnout_queue_we = 8'hFF;
        spawnout_queue_din = taskID;

        inStream_spawnout_TREADY = 0;

        case (spawnout_state)

            SPAWNOUT_CHECK: begin
                spawnout_queue_en = 1;
                spawnout_queue_we = 0;
                spawnout_queue_addr[3 + QUEUE_BITS-1:3] = rIdx;
            end

            SPAWNOUT_WRITE_TASKID: begin
                spawnout_queue_en = 1;
            end

            SPAWNOUT_WRITE_PTASKID: begin
                spawnout_queue_en = 1;
                spawnout_queue_din = pTaskID;
            end

            SPAWNOUT_WRITE_TASKTYPE: begin
                spawnout_queue_en = 1;
                spawnout_queue_din[63:CMD_NEWTASK_ARCHBITS_H+1] = 0;
                spawnout_queue_din[CMD_NEWTASK_ARCHBITS_H:CMD_NEWTASK_ARCHBITS_L] = task_arch;
                spawnout_queue_din[CMD_NEWTASK_TASKTYPE_H:CMD_NEWTASK_TASKTYPE_L] = task_type;
            end

            SPAWNOUT_WRITE_REST_1: begin
                inStream_spawnout_TREADY = 1;
            end

            SPAWNOUT_WRITE_REST_2: begin
                spawnout_queue_en = 1;
                spawnout_queue_din = inStream_data_buf;
            end

            SPAWNOUT_WRITE_HEADER: begin
                spawnout_queue_en = 1;
                spawnout_queue_din[ENTRY_VALID_BYTE_OFFSET+7:ENTRY_VALID_BYTE_OFFSET] = 8'h80;
                spawnout_queue_din[NUM_ARGS_OFFSET+7:NUM_ARGS_OFFSET] = {4'd0, num_args};
                spawnout_queue_din[NUM_DEPS_OFFSET+7:NUM_DEPS_OFFSET] = {4'd0, num_deps};
                spawnout_queue_din[NUM_COPS_OFFSET+7:NUM_COPS_OFFSET] = {4'd0, num_cops};
            end

            default: begin

            end

        endcase

    end

    always_ff @(posedge clk) begin

        num_slots_1 <= spawnout_num_cops*IOInterface::COPY_WORDS[3:0];
        num_slots_2 <= {2'd0, spawnout_num_args} + {2'd0, spawnout_num_deps};

        spawnout_ret <= 0;

        case (spawnout_state)

            SPAWNOUT_IDLE: begin
                needed_slots <= 7'd4 + {3'd0, num_deps} + {3'd0, num_args} + num_cops*IOInterface::COPY_WORDS[3:0];
                if (spawnout_state_start) begin
                    spawnout_state <= SPAWNOUT_CHECK;
                end
            end

            SPAWNOUT_CHECK: begin
                header_wIdx <= wIdx;
                if (needed_slots <= avail_slots) begin
                    wIdx <= next_wIdx;
                    spawnout_state <= SPAWNOUT_WRITE_TASKID;
                end else begin
                    spawnout_state <= SPAWNOUT_READ;
                end
            end

            SPAWNOUT_READ: begin
                spawnout_num_deps <= spawnout_queue_dout[NUM_DEPS_OFFSET+3:NUM_DEPS_OFFSET];
                spawnout_num_args <= spawnout_queue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET];
                spawnout_num_cops <= spawnout_queue_dout[NUM_COPS_OFFSET+3:NUM_COPS_OFFSET];
                if (!spawnout_queue_dout[ENTRY_VALID_OFFSET]) begin
                    spawnout_state <= SPAWNOUT_COMPUTE_CMD_LEN;
                end else begin
                    spawnout_ret <= 2'd2;
                    spawnout_state <= SPAWNOUT_IDLE;
                end
            end

            SPAWNOUT_COMPUTE_CMD_LEN: begin
                spawnout_state <= SPAWNOUT_UPDATE_AVAIL_SLOTS;
            end

            SPAWNOUT_UPDATE_AVAIL_SLOTS: begin
                avail_slots <= avail_slots + {4'd0, num_slots};
                rIdx <= rIdx + {3'd0, num_slots};
                spawnout_state <= SPAWNOUT_CHECK;
            end

            SPAWNOUT_WRITE_TASKID: begin
                wIdx <= next_wIdx;
                spawnout_state <= SPAWNOUT_WRITE_PTASKID;
            end

            SPAWNOUT_WRITE_PTASKID: begin
                wIdx <= next_wIdx;
                spawnout_state <= SPAWNOUT_WRITE_TASKTYPE;
            end

            SPAWNOUT_WRITE_TASKTYPE: begin
                wIdx <= next_wIdx;
                if (needed_slots == 7'd4) begin
                    wIdx <= header_wIdx;
                    header_wIdx <= next_wIdx;
                    spawnout_state <= SPAWNOUT_WRITE_HEADER;
                end else begin
                    spawnout_state <= SPAWNOUT_WRITE_REST_1;
                end
            end

            SPAWNOUT_WRITE_REST_1: begin
                if (inStream_TVALID) begin
                    spawnout_state <= SPAWNOUT_WRITE_REST_2;
                end
            end

            SPAWNOUT_WRITE_REST_2: begin
                if (inStream_last_buf) begin
                    wIdx <= header_wIdx;
                    header_wIdx <= next_wIdx;
                    spawnout_state <= SPAWNOUT_WRITE_HEADER;
                end else begin
                    wIdx <= next_wIdx;
                    spawnout_state <= SPAWNOUT_WRITE_REST_1;
                end
            end

            SPAWNOUT_WRITE_HEADER: begin
                wIdx <= header_wIdx;
                spawnout_ret <= 2'd1;
                spawnout_state <= SPAWNOUT_IDLE;
                avail_slots <= avail_slots - needed_slots;
            end

        endcase

        if (!rstn) begin
            spawnout_state <= SPAWNOUT_IDLE;
            avail_slots <= QUEUE_LEN;
            wIdx <= 0;
            rIdx <= 0;
        end
    end

endmodule
