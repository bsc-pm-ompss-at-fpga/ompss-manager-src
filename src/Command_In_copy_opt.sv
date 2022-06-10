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

module Command_In_copy_opt #(
    parameter SUBQUEUE_BITS = 6
) (
    input  clk,
    input  rstn,
    //Command in queue
    output logic [SUBQUEUE_BITS-1:0] cmdin_queue_addr,
    output logic cmdin_queue_en,
    output logic [7:0] cmdin_queue_we,
    output logic [63:0] cmdin_queue_din,
    input  [63:0] cmdin_queue_dout,
    //Internal command in queue
    output logic [SUBQUEUE_BITS-1:0] intcmdin_queue_addr,
    output logic intCmdInQueue_en,
    output logic intCmdInQueue_we,
    output logic [63:0] intCmdInQueue_din,
    input  [63:0] intCmdInQueue_dout,
    //Other signals
    input [3:0] num_args,
    input start,
    output reg finished,
    input [SUBQUEUE_BITS-1:0] first_idx,
    input [SUBQUEUE_BITS-1:0] first_next_idx,
    input queue_select, //0 --> cmd in, 1 --> int cmd in
    input [1:0] cmd_type //0 --> exec task, 1 --> setup inst, 2 --> exec periodic task
);

    typedef enum bit [2:0] {
        IDLE,
        READ_ARG_0,
        READ_ARG_1,
        READ_FLAG_0,
        READ_FLAG_1,
        WRITE_FLAG_0,
        WRITE_FLAG_1
    } State_t;

    (* fsm_encoding = "one_hot" *)
    State_t state;

    reg [SUBQUEUE_BITS-1:0] idx; //Current subqueue index of the current command
    reg [SUBQUEUE_BITS-1:0] cmd_next_idx; //Current subqueue index of the next command
    wire [SUBQUEUE_BITS-1:0] next_arg_idx;
    reg [63:0] arg;
    reg [2:0] flag;
    reg [2:0] flag_d;
    reg [63:0] intCmdInQueue_buf;
    wire copyflag_bit;
    wire [SUBQUEUE_BITS-1:0] idx_prev;

    assign next_arg_idx = idx + 2;

    assign copyflag_bit = flag[0] & !flag_d[2] & !flag_d[0];

    assign idx_prev = idx-1;

    always_comb begin

        cmdin_queue_en = !queue_select;
        cmdin_queue_we = 0;
        cmdin_queue_addr = idx;
        cmdin_queue_din[7] = flag[2];
        cmdin_queue_din[5] = flag[1] & !cmdin_queue_dout[5];
        cmdin_queue_din[4] = flag[0];

        intCmdInQueue_en = queue_select;
        intCmdInQueue_we = 0;
        intcmdin_queue_addr = idx;
        intCmdInQueue_din = intCmdInQueue_buf;
        intCmdInQueue_din[7] = flag[2];
        intCmdInQueue_din[5] = flag[1] & !intCmdInQueue_dout[5];
        intCmdInQueue_din[4] = flag[0];

        case (state)

            IDLE: begin
                cmdin_queue_en = 0;
                intCmdInQueue_en = 0;
            end

            READ_ARG_1: begin
                cmdin_queue_addr = cmd_next_idx;
                intcmdin_queue_addr = cmd_next_idx;
            end

            READ_FLAG_1: begin
                cmdin_queue_addr = cmd_next_idx;
                intcmdin_queue_addr = cmd_next_idx;
            end

            //memory data: flags next cmd
            //flag register: flags current cmd
            //memory buffer: flags current cmd
            WRITE_FLAG_0: begin
                cmdin_queue_we = 8'h01;
                intCmdInQueue_we = 1;
            end

            //memory data: flags current cmd
            //flag register: flags next cmd
            //flag_d register: flags current cmd
            //memory buffer: flags next cmd
            WRITE_FLAG_1: begin
                cmdin_queue_we = 8'h01;
                intCmdInQueue_we = 1;
                cmdin_queue_addr = cmd_next_idx;
                cmdin_queue_din[7] = !copyflag_bit & flag[0];
                cmdin_queue_din[5] = flag[1];
                cmdin_queue_din[4] = copyflag_bit;
                intcmdin_queue_addr = cmd_next_idx;
                intCmdInQueue_din[7] = !copyflag_bit & flag[0];
                intCmdInQueue_din[5] = flag[1];
                intCmdInQueue_din[4] = copyflag_bit;
            end

            default: begin

            end

        endcase
    end

    always_ff @(posedge clk) begin

        finished <= 0;
        arg <= queue_select ? intCmdInQueue_dout : cmdin_queue_dout;
        flag <= queue_select ? {intCmdInQueue_dout[7], intCmdInQueue_dout[5], intCmdInQueue_dout[4]} : {cmdin_queue_dout[7], cmdin_queue_dout[5], cmdin_queue_dout[4]};
        flag_d <= flag;
        intCmdInQueue_buf <= intCmdInQueue_dout;

        case (state)

            IDLE: begin
                idx <= first_idx + (cmd_type == 0 ? 4 : 5);
                cmd_next_idx <= first_next_idx + (cmd_type == 0 ? 4 : 5);
                if (start) begin
                    if (num_args > 0) begin
                        state <= READ_ARG_0;
                    end else begin
                        finished <= 1;
                    end
                end
            end

            READ_ARG_0: begin
                idx <= idx - 1;
                state <= READ_ARG_1;
            end

            READ_ARG_1: begin
                cmd_next_idx <= cmd_next_idx - 1;
                state <= READ_FLAG_0;
            end

            READ_FLAG_0: begin
                if ((queue_select && arg == intCmdInQueue_dout) || (!queue_select && arg == cmdin_queue_dout)) begin
                    state <= READ_FLAG_1;
                end else if (next_arg_idx == first_next_idx) begin
                    state <= IDLE;
                    finished <= 1;
                end else begin
                    state <= READ_ARG_0;
                    idx <= idx + 3;
                    cmd_next_idx <= cmd_next_idx + 3;
                end
            end

            READ_FLAG_1: begin
                state <= WRITE_FLAG_0;
            end

            WRITE_FLAG_0: begin
                idx <= idx + 3;
                state <= WRITE_FLAG_1;
            end

            WRITE_FLAG_1: begin
                cmd_next_idx <= cmd_next_idx + 3;
                if (idx_prev == first_next_idx) begin
                    state <= IDLE;
                    finished <= 1;
                end else begin
                    state <= READ_ARG_0;
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
