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


module Scheduler_parse_bitinfo #(
    parameter MAX_ACCS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter ACC_TYPE_BITS = $clog2(MAX_ACC_TYPES),
    parameter SCHED_DATA_BITS = 48
) (
    input clk,
    input rstn,
    //Bitinfo memory
    output [31:0] bitinfo_addr,
    output bitinfo_en,
    input [31:0] bitinfo_dout,
    //Scheduling data memory
    output reg [ACC_TYPE_BITS-1:0] scheduleData_portA_addr,
    output scheduleData_portA_en,
    output logic [SCHED_DATA_BITS-1:0] scheduleData_portA_din
);

    import OmpSsManager::*;
    localparam ACC_BITS = $clog2(MAX_ACCS);
    localparam WORDS_PER_ACC_TYPE = 11;
    localparam XTASKSCONFIG_OFFSET = 22;
    localparam OFFSET_BITS = $clog2(XTASKSCONFIG_OFFSET + MAX_ACC_TYPES*WORDS_PER_ACC_TYPE);

    typedef enum bit [2:0] {
        START,
        ISSUE_READ_WORD0,
        READ_WORD0,
        READ_WORD1,
        WRITE_SCHEDULE_DATA,
        CHECK_NEXT_ITERATION,
        IDLE
    } State_t;

    State_t state;

    reg [OFFSET_BITS-1:0] offset;
    reg [SCHED_TASKTYPE_BITS-1:0] task_type;
    reg [ACC_BITS-1:0] num_instances;
    reg [ACC_BITS-1:0] first_free_id;
    reg [31:0] bitinfo_buf;

    assign scheduleData_portA_din[SCHED_DATA_ACCID_L+ACC_BITS-1:SCHED_DATA_ACCID_L] = first_free_id;
    assign scheduleData_portA_din[SCHED_DATA_COUNT_L+ACC_BITS-1:SCHED_DATA_COUNT_L] = num_instances - {{ACC_BITS-1{1'b0}}, 1'b1};
    assign scheduleData_portA_din[SCHED_DATA_TASK_TYPE_H:SCHED_DATA_TASK_TYPE_L] = task_type;
    assign scheduleData_portA_en = state == WRITE_SCHEDULE_DATA;

    assign bitinfo_addr[31:2+OFFSET_BITS] = 0;
    assign bitinfo_addr[2+OFFSET_BITS-1:2] = offset;
    assign bitinfo_addr[1:0] = 0;
    assign bitinfo_en = state == ISSUE_READ_WORD0 || state == READ_WORD0 || state == READ_WORD1;

    always_ff @(posedge clk) begin

        bitinfo_buf <= bitinfo_dout;
        task_type[15:0] <= bitinfo_buf[31:16];
        task_type[SCHED_TASKTYPE_BITS-1:16] <= bitinfo_dout[23:0];
        num_instances <= bitinfo_buf[ACC_BITS-1:0];

        case (state)

            START: begin
                first_free_id <= 0;
                scheduleData_portA_addr <= 0;
                offset <= XTASKSCONFIG_OFFSET;
                state <= ISSUE_READ_WORD0;
            end

            ISSUE_READ_WORD0: begin
                offset <= offset + 1;
                state <= READ_WORD0;
            end

            READ_WORD0: begin
                offset <= offset + WORDS_PER_ACC_TYPE - 1;
                state <= READ_WORD1;
            end

            READ_WORD1: begin
                state <= WRITE_SCHEDULE_DATA;
            end

            WRITE_SCHEDULE_DATA: begin
                scheduleData_portA_addr <= scheduleData_portA_addr+1;
                state <= CHECK_NEXT_ITERATION;
                first_free_id <= first_free_id + num_instances;
            end

            CHECK_NEXT_ITERATION: begin
                if (bitinfo_buf == 32'hFFFFFFFF) begin
                    state <= IDLE;
                end else begin
                    state <= ISSUE_READ_WORD0;
                end
            end

            IDLE: begin
            end

        endcase

        if (!rstn) begin
            state <= START;
        end
    end

endmodule
