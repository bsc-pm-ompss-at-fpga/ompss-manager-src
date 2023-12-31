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

module Command_In_copy_opt #(
    parameter SUBQUEUE_BITS = 6,
    parameter DBG_REGS = 0
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
    input [1:0] cmd_type, //0 --> exec task, 1 --> setup inst, 2 --> exec periodic task
    //Debug registers
    output reg [31:0] copy_in_opt,
    output reg [31:0] copy_out_opt
);

    localparam COPY_IN_B = 4;
    localparam COPY_OUT_B = 5;
    localparam COPY_IN_CHAIN_B = 7;
    localparam FLAG_COPY_IN_B = 0;
    localparam FLAG_COPY_OUT_B = 1;
    localparam FLAG_COPY_IN_CHAIN_B = 2;

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

    assign copyflag_bit = flag[FLAG_COPY_IN_B] & !flag_d[FLAG_COPY_IN_CHAIN_B] & !flag_d[FLAG_COPY_IN_B];

    assign idx_prev = idx-1;

    always_comb begin

        cmdin_queue_en = !queue_select;
        cmdin_queue_we = 0;
        cmdin_queue_addr = idx;
        cmdin_queue_din[COPY_IN_CHAIN_B] = flag[FLAG_COPY_IN_CHAIN_B];
        cmdin_queue_din[COPY_OUT_B] = flag[FLAG_COPY_OUT_B] & !cmdin_queue_dout[COPY_OUT_B];
        cmdin_queue_din[COPY_IN_B] = flag[FLAG_COPY_IN_B];

        intCmdInQueue_en = queue_select;
        intCmdInQueue_we = 0;
        intcmdin_queue_addr = idx;
        intCmdInQueue_din = intCmdInQueue_buf;
        intCmdInQueue_din[COPY_IN_CHAIN_B] = flag[FLAG_COPY_IN_CHAIN_B];
        intCmdInQueue_din[COPY_OUT_B] = flag[FLAG_COPY_OUT_B] & !intCmdInQueue_dout[COPY_OUT_B];
        intCmdInQueue_din[COPY_IN_B] = flag[FLAG_COPY_IN_B];

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
                cmdin_queue_din[COPY_IN_CHAIN_B] = !copyflag_bit & flag[FLAG_COPY_IN_B];
                cmdin_queue_din[COPY_OUT_B] = flag[FLAG_COPY_OUT_B];
                cmdin_queue_din[COPY_IN_B] = copyflag_bit;
                intcmdin_queue_addr = cmd_next_idx;
                intCmdInQueue_din[COPY_IN_CHAIN_B] = !copyflag_bit & flag[FLAG_COPY_IN_B];
                intCmdInQueue_din[COPY_OUT_B] = flag[FLAG_COPY_OUT_B];
                intCmdInQueue_din[COPY_IN_B] = copyflag_bit;
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
                if (DBG_REGS) begin
                    // The output copy of the current cmd arg is optimized
                    if (flag[FLAG_COPY_OUT_B] & cmdin_queue_dout[COPY_OUT_B]) begin
                        copy_out_opt <= copy_out_opt + 32'd1;
                    end
                end
                state <= WRITE_FLAG_1;
            end

            WRITE_FLAG_1: begin
                cmd_next_idx <= cmd_next_idx + 3;
                if (DBG_REGS) begin
                    // The input copy of the next cmd arg is optimized
                    if (flag[FLAG_COPY_IN_B] & (flag_d[FLAG_COPY_IN_CHAIN_B] | flag_d[FLAG_COPY_IN_B])) begin
                        copy_in_opt <= copy_in_opt + 32'd1;
                    end
                end
                if (idx_prev == first_next_idx) begin
                    state <= IDLE;
                    finished <= 1;
                end else begin
                    state <= READ_ARG_0;
                end
            end

        endcase

        if (!rstn) begin
            if (DBG_REGS) begin
                copy_out_opt <= 32'd0;
                copy_in_opt <= 32'd0;
            end
            state <= IDLE;
        end
    end

endmodule
