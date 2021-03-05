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

module Scheduler_parse_bitinfo #(
    parameter MAX_ACCS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter ACC_TYPE_BITS = $clog2(MAX_ACC_TYPES)
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
    output logic [49:0] scheduleData_portA_din
);

    import OmpSsManager::*;
    localparam ACC_BITS = $clog2(MAX_ACCS);
    localparam OFFSET_BITS = $clog2(9 + MAX_ACC_TYPES*12); //9 header words + 12 words per task type

    typedef enum bit [3:0] {
        START,
        READ_ACC_TYPE,
        STORE_ACC_TYPE,
        COMPUTE_ACC_TYPE_MUL,
        COMPUTE_ACC_TYPE_ADD,
        READ_NUM_INSTANCES,
        STORE_NUM_INSTANCES,
        COMPUTE_NUM_INSTANCES_MUL,
        COMPUTE_NUM_INSTANCES_ADD,
        WRITE_SCHEDULE_DATA,
        READ_NEXT_ITERATION_WORD,
        CHECK_FINISH,
        IDLE
    } State_t;
    
    State_t state;

    reg [OFFSET_BITS-1:0] offset;
    reg [31:0] bitinfoCast;
    reg [33:0] task_type;
    reg [ACC_BITS:0] num_instances;
    reg [3:0] bitinfoDigit;
    reg [1:0] c;
    reg [2:0] w;
    reg [ACC_BITS-1:0] first_free_id;

    assign scheduleData_portA_din[SCHED_DATA_ACCID_L+ACC_BITS-1:SCHED_DATA_ACCID_L] = first_free_id;
    assign scheduleData_portA_din[SCHED_DATA_COUNT_L+ACC_BITS-1:SCHED_DATA_COUNT_L] = num_instances - {{ACC_BITS-1{1'b0}}, 1'b1};
    assign scheduleData_portA_din[SCHED_DATA_TASK_TYPE_H:SCHED_DATA_TASK_TYPE_L] = task_type;
    assign scheduleData_portA_en = state == WRITE_SCHEDULE_DATA;

    assign bitinfo_addr[31:2+OFFSET_BITS] = 0;
    assign bitinfo_addr[2+OFFSET_BITS-1:2] = offset;
    assign bitinfo_addr[1:0] = 0;
    assign bitinfo_en = state == READ_ACC_TYPE || state == READ_NUM_INSTANCES || state == READ_NEXT_ITERATION_WORD;

    always_ff @(posedge clk) begin

        bitinfoCast <= bitinfo_dout;
        //'0' in ascii is 6'b110000 (48) which means that the lower 4 bits correspond to the binary representation of the digit
        bitinfoDigit <= bitinfoCast[c*8 +: 4];

        case (state)

            START: begin
                w <= 0;
                first_free_id <= 0;
                task_type <= 0;
                scheduleData_portA_addr <= 0;
                offset <= 4 /*words before the xtasks.config data*/ + 5 /*words of xtasks.config header*/;
                state <= READ_ACC_TYPE;
            end 

            //Issue mem read
            READ_ACC_TYPE: begin
                c <= 0;
                offset <= offset+1;
                state <= STORE_ACC_TYPE;
            end

            //Store mem data in bitinfoCast
            STORE_ACC_TYPE: begin
                state <= COMPUTE_ACC_TYPE_MUL;
            end

            //Store current char in bitinfoChar
            COMPUTE_ACC_TYPE_MUL: begin
                task_type <= task_type*10;
                state <= COMPUTE_ACC_TYPE_ADD;
            end

            COMPUTE_ACC_TYPE_ADD: begin
                task_type <= task_type + {30'd0, bitinfoDigit};
                c <= c+1;
                if (c == 2'd3) begin
                    w <= w+1;
                end
                //NOTE: Skip the \t character at the end of 5th word
                if (w == 3'd4) begin
                    if (c == 2'd2) begin
                        state <= READ_NUM_INSTANCES;
                    end else begin
                        state <= COMPUTE_ACC_TYPE_MUL;
                    end
                end else if (c == 2'd3) begin
                    state <= READ_ACC_TYPE;
                end else begin
                    state <= COMPUTE_ACC_TYPE_MUL;
                end
            end

            READ_NUM_INSTANCES: begin
                c <= 0;
                offset <= offset+1;
                num_instances <= 0;
                state <= STORE_NUM_INSTANCES;
            end

            STORE_NUM_INSTANCES: begin
                state <= COMPUTE_NUM_INSTANCES_MUL;
            end

            COMPUTE_NUM_INSTANCES_MUL: begin
                num_instances <= num_instances*10;
                state <= COMPUTE_NUM_INSTANCES_ADD;
            end

            COMPUTE_NUM_INSTANCES_ADD: begin
                num_instances <= num_instances + bitinfoDigit;
                c <= c+1;
                if (c == 2'd2) begin
                    state <= WRITE_SCHEDULE_DATA;
                end else begin
                    state <= COMPUTE_NUM_INSTANCES_MUL;
                end
            end

            WRITE_SCHEDULE_DATA: begin
                first_free_id <= first_free_id + num_instances[ACC_BITS-1:0];
                scheduleData_portA_addr <= scheduleData_portA_addr+1;
                offset <= offset+9; //8 words of name + 1 word of frequency
                state <= READ_NEXT_ITERATION_WORD;
            end

            READ_NEXT_ITERATION_WORD: begin
                offset <= offset+1;
                state <= CHECK_FINISH;
            end

            CHECK_FINISH: begin
                c <= 0;
                w <= 0;
                task_type <= 0;
                if (bitinfo_dout == 32'hFFFFFFFF) begin
                    state <= IDLE;
                end else begin
                    state <= COMPUTE_ACC_TYPE_MUL;
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
