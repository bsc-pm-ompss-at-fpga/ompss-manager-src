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

module Command_In #(
    parameter MAX_ACCS = 16,
    parameter ACC_BITS = $clog2(MAX_ACCS),
    parameter SUBQUEUE_BITS = 6,
    parameter DBG_REGS = 0
) (
    input clk,
    input rstn,
    //Command in queue
    output logic [31:0] cmdin_queue_addr,
    output logic cmdin_queue_en,
    output logic [7:0] cmdin_queue_we,
    output logic [63:0] cmdin_queue_din,
    input  [63:0] cmdin_queue_dout,
    output cmdin_queue_clk,
    output cmdin_queue_rst,
    //Internal command in queue
    output logic [SUBQUEUE_BITS+ACC_BITS-1:0] intCmdInQueue_addr,
    output logic intCmdInQueue_en,
    output logic intCmdInQueue_we,
    output logic [63:0] intCmdInQueue_din,
    input  [63:0] intCmdInQueue_dout,
    //outStream
    output [63:0] outStream_TDATA,
    output logic outStream_TVALID,
    input  outStream_TREADY,
    output [ACC_BITS-1:0] outStream_TDEST,
    output outStream_TLAST,
    //Queue not empty and accelerator availability interfaces
    input [ACC_BITS-1:0] sched_queue_nempty_address,
    input sched_queue_nempty_write,
    input [ACC_BITS-1:0] acc_avail_wr_address,
    input acc_avail_wr,
    //Debug registers
    output [31:0] copy_in_opt,
    output [31:0] copy_out_opt,
    output reg [MAX_ACCS-1:0] dbg_acc_avail,
    output reg [MAX_ACCS-1:0] dbg_queue_nempty,
    output reg [31:0] num_cmds[MAX_ACCS]
);

    import OmpSsManager::*;

    typedef enum bit [3:0] {
        IDLE,
        GET_QUEUE_IDX,
        ISSUE_CMD_READ,
        CHECK_CMD_QUEUE,
        READ_NEXT_CMD,
        CHECK_NEXT_CMD,
        WAIT_COPY_OPT,
        SEND_CMD,
        CLEAR_HEADER,
        UPDATE_QUEUE_NEMPTY
    } State_t;

    (* fsm_encoding = "one_hot" *)
    State_t state;

    struct packed {
        logic [SUBQUEUE_BITS-1:0] cmd_in;
        logic [SUBQUEUE_BITS-1:0] int_cmd_in;
    } subqueue_idx[MAX_ACCS];

    reg [MAX_ACCS-1:0] acc_avail;
    reg [MAX_ACCS-1:0] queue_nempty;
    reg [MAX_ACCS-1:0] front_sent; // Task in subqueue front has already been sent to the accelerator
    reg [MAX_ACCS-1:0] copy_optimized; // Task in subqueue front has already been optimized with the next command
    reg [MAX_ACCS-1:0] in_flight_queue_sel; // Task in flight queue select
    reg acc_avail_reg;
    reg front_sent_reg;
    reg copy_optimized_reg;

    reg [ACC_BITS-1:0] cmd_in_acc_id;
    reg [ACC_BITS-1:0] acc_id;
    reg [3:0] num_args;
    reg [5:0] cmd_length; //max 3 initial words + 15*2 arguments
    reg [1:0] cmd_type; //0 --> exec task, 1 --> setup inst, 2 --> exec periodic task
    reg [SUBQUEUE_BITS-1:0] first_idx;
    reg [SUBQUEUE_BITS-1:0] first_next_idx;
    reg [SUBQUEUE_BITS-1:0] first_cmd_in_idx;
    reg [SUBQUEUE_BITS-1:0] first_int_cmd_in_idx;
    reg [SUBQUEUE_BITS-1:0] cmd_in_idx;
    reg [SUBQUEUE_BITS-1:0] int_cmd_in_idx;

    wire [5:0] cmdin_task_num_slots;
    wire [5:0] intcmdin_task_num_slots;

    reg queue_select; //0 --> cmd in, 1 --> int cmd in

    wire [SUBQUEUE_BITS-1:0] copy_opt_intCmdInQueue_addr;
    wire copy_opt_intCmdInQueue_en;
    wire copy_opt_intCmdInQueue_we;
    wire [63:0] copy_opt_intCmdInQueue_din;

    wire [SUBQUEUE_BITS-1:0] copy_opt_cmdin_queue_addr;
    wire copy_opt_cmdin_queue_en;
    wire [7:0] copy_opt_cmdin_queue_we;
    wire [63:0] copy_opt_cmdin_queue_din;

    reg copy_opt_start;
    reg copy_opt_finished;

    Command_In_copy_opt #(
        .SUBQUEUE_BITS(SUBQUEUE_BITS),
        .DBG_REGS(DBG_REGS)
    ) copy_opt (
        .clk(clk),
        .rstn(rstn),
        .cmdin_queue_addr(copy_opt_cmdin_queue_addr),
        .cmdin_queue_en(copy_opt_cmdin_queue_en),
        .cmdin_queue_we(copy_opt_cmdin_queue_we),
        .cmdin_queue_din(copy_opt_cmdin_queue_din),
        .cmdin_queue_dout(cmdin_queue_dout),
        .intcmdin_queue_addr(copy_opt_intCmdInQueue_addr),
        .intCmdInQueue_en(copy_opt_intCmdInQueue_en),
        .intCmdInQueue_we(copy_opt_intCmdInQueue_we),
        .intCmdInQueue_dout(intCmdInQueue_dout),
        .intCmdInQueue_din(copy_opt_intCmdInQueue_din),
        .num_args(num_args),
        .start(copy_opt_start),
        .finished(copy_opt_finished),
        .first_idx(first_idx),
        .first_next_idx(first_next_idx),
        .queue_select(queue_select),
        .cmd_type(cmd_type),
        .copy_in_opt(copy_in_opt),
        .copy_out_opt(copy_out_opt)
    );

    assign cmdin_queue_clk = clk;
    assign cmdin_queue_rst = 0;

    assign cmdin_queue_addr[31:3 + SUBQUEUE_BITS+ACC_BITS] = 0;
    assign cmdin_queue_addr[2:0] = 0;
    assign cmdin_queue_addr[3 + SUBQUEUE_BITS+ACC_BITS-1:3 + SUBQUEUE_BITS] = acc_id;
    assign intCmdInQueue_addr[SUBQUEUE_BITS+ACC_BITS-1:SUBQUEUE_BITS] = acc_id;

    assign outStream_TDEST = acc_id;
    assign outStream_TDATA = queue_select ? intCmdInQueue_dout : cmdin_queue_dout;
    assign outStream_TLAST = cmd_length == 0;

    assign cmdin_task_num_slots = (cmdin_queue_dout[CMD_TYPE_L+3:CMD_TYPE_L] == EXEC_TASK_CODE ? 6'd3 : 6'd4) + {1'b0, cmdin_queue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
    assign intcmdin_task_num_slots = (intCmdInQueue_dout[CMD_TYPE_L+3:CMD_TYPE_L] == EXEC_TASK_CODE ? 6'd3 : 6'd4) + {1'b0, intCmdInQueue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};

    always_comb begin

        cmdin_queue_en = 0;
        cmdin_queue_we = 0;
        cmdin_queue_addr[3 + SUBQUEUE_BITS-1:3] = cmd_in_idx;
        cmdin_queue_din = 64'd0;
        cmdin_queue_din[ENTRY_VALID_BYTE_OFFSET+7:ENTRY_VALID_BYTE_OFFSET] = 0;

        intCmdInQueue_en = 0;
        intCmdInQueue_we = 0;
        intCmdInQueue_addr[SUBQUEUE_BITS-1:0] = int_cmd_in_idx;
        intCmdInQueue_din = 64'dX;
        intCmdInQueue_din[ENTRY_VALID_OFFSET] = 0;
        intCmdInQueue_din[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET] = num_args;

        outStream_TVALID = 0;

        case (state)

            ISSUE_CMD_READ: begin
                cmdin_queue_en = 1;
                intCmdInQueue_en = 1;
            end

            SEND_CMD: begin
                outStream_TVALID = 1;
                if (outStream_TREADY) begin
                    cmdin_queue_en = 1;
                    intCmdInQueue_en = 1;
                    if (!outStream_TLAST) begin
                        cmdin_queue_we = !queue_select ? 8'h80 : 0;
                        intCmdInQueue_we = queue_select;
                    end
                end
            end

            READ_NEXT_CMD: begin
                intCmdInQueue_addr[SUBQUEUE_BITS-1:0] = first_next_idx;
                cmdin_queue_addr[3 + SUBQUEUE_BITS-1:3] = first_next_idx;
                intCmdInQueue_en = 1;
                cmdin_queue_en = 1;
            end

            CHECK_NEXT_CMD: begin
                cmdin_queue_en = 1;
                intCmdInQueue_en = 1;
            end

            WAIT_COPY_OPT: begin
                if (copy_opt_finished) begin
                    cmdin_queue_en = 1;
                    intCmdInQueue_en = 1;
                end else begin
                    cmdin_queue_en = copy_opt_cmdin_queue_en;
                    intCmdInQueue_en = copy_opt_intCmdInQueue_en;
                    cmdin_queue_addr[3 + SUBQUEUE_BITS-1:3] = copy_opt_cmdin_queue_addr;
                    intCmdInQueue_addr[SUBQUEUE_BITS-1:0] = copy_opt_intCmdInQueue_addr;
                    cmdin_queue_we = copy_opt_cmdin_queue_we;
                    intCmdInQueue_we = copy_opt_intCmdInQueue_we;
                    cmdin_queue_din = copy_opt_cmdin_queue_din;
                    intCmdInQueue_din = copy_opt_intCmdInQueue_din;
                end
            end

            CLEAR_HEADER: begin
                cmdin_queue_addr[3 + SUBQUEUE_BITS-1:3] = first_cmd_in_idx;
                intCmdInQueue_addr[SUBQUEUE_BITS-1:0] = first_int_cmd_in_idx;
                intCmdInQueue_en = 1;
                cmdin_queue_en = 1;
                if (queue_select) begin
                    intCmdInQueue_we = 1;
                end else begin
                    cmdin_queue_we = 8'h80;
                end
            end

            default: begin

            end

        endcase

    end

    always_ff @(posedge clk) begin

        copy_opt_start <= 0;

        case (state)

            IDLE: begin
                acc_id <= cmd_in_acc_id;
                queue_select <= 0;
                for (int i = 0; i < MAX_ACCS; ++i) begin
                    if (((queue_nempty[i] || (front_sent[i] && in_flight_queue_sel[i])) && acc_avail[i]) ||
                        (front_sent[i] && queue_nempty[i] && !copy_optimized[i])) begin
                        queue_select <= 1;
                        acc_id <= i[ACC_BITS-1:0];
                        break;
                    end
                end
                state <= GET_QUEUE_IDX;
            end

            GET_QUEUE_IDX: begin
                if (MAX_ACCS & (MAX_ACCS-1) == 0) begin //Power of 2
                    cmd_in_acc_id <= cmd_in_acc_id+1;
                end else begin
                    if (cmd_in_acc_id == MAX_ACCS-1) begin
                        cmd_in_acc_id <= 0;
                    end else begin
                        cmd_in_acc_id <= cmd_in_acc_id+1;
                    end
                end
                front_sent_reg <= front_sent[acc_id];
                copy_optimized_reg <= copy_optimized[acc_id];
                acc_avail_reg <= acc_avail[acc_id];
                cmd_in_idx <= subqueue_idx[acc_id].cmd_in;
                int_cmd_in_idx <= subqueue_idx[acc_id].int_cmd_in;
                if ((!front_sent[acc_id] && !acc_avail[acc_id]) || (!queue_select && copy_optimized[acc_id] && !acc_avail[acc_id])) begin
                    state <= IDLE;
                end else begin
                    state <= ISSUE_CMD_READ;
                end
            end

            ISSUE_CMD_READ: begin
                first_cmd_in_idx <= cmd_in_idx;
                first_int_cmd_in_idx <= int_cmd_in_idx;
                state <= CHECK_CMD_QUEUE;
            end

            CHECK_CMD_QUEUE: begin
                if (cmdin_queue_dout[CMD_TYPE_L+3:CMD_TYPE_L] == SETUP_HW_INST_CODE) begin
                    cmd_length <= 1;
                    cmd_type <= 1;
                end else if (cmdin_queue_dout[CMD_TYPE_L+3:CMD_TYPE_L] == EXEC_TASK_CODE) begin
                    cmd_length <= 6'd2 + {1'b0, cmdin_queue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
                    cmd_type <= 0;
                end else begin //Periodic task
                    cmd_length <= 6'd3 + {1'b0, cmdin_queue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
                    cmd_type <= 2;
                end
                num_args <= cmdin_queue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET];
                first_idx <= queue_select ? int_cmd_in_idx : cmd_in_idx;
                first_next_idx <= cmd_in_idx + cmdin_task_num_slots;
                if (queue_select) begin
                    first_next_idx <= int_cmd_in_idx + intcmdin_task_num_slots;
                    num_args <= intCmdInQueue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET];
                    //Accelerators don't setup instrumentation
                    if (intCmdInQueue_dout[CMD_TYPE_L+3:CMD_TYPE_L] == EXEC_TASK_CODE) begin
                        cmd_length <= 6'd2 + {1'b0, intCmdInQueue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
                        cmd_type <= 0;
                    end else begin //Periodic task
                        cmd_length <= 6'd3 + {1'b0, intCmdInQueue_dout[NUM_ARGS_OFFSET+3:NUM_ARGS_OFFSET], 1'b0};
                        cmd_type <= 2;
                    end
                    state <= READ_NEXT_CMD;
                end else if (cmdin_queue_dout[ENTRY_VALID_OFFSET]) begin
                    state <= READ_NEXT_CMD;
                end else begin
                    state <= IDLE;
                end
            end

            READ_NEXT_CMD: begin
                if (front_sent_reg) begin
                    if (queue_select) begin
                        int_cmd_in_idx <= first_next_idx;
                    end else begin
                        cmd_in_idx <= first_next_idx;
                    end
                end
                state <= CHECK_NEXT_CMD;
            end

            CHECK_NEXT_CMD: begin
                //If any cmd is setup inst, argument flag optimization is not necessary
                if (!copy_optimized_reg && cmd_type != 2'd1 && ((!queue_select && cmdin_queue_dout[ENTRY_VALID_OFFSET] && cmdin_queue_dout[CMD_TYPE_L] != 0)
                                       || (queue_select && intCmdInQueue_dout[ENTRY_VALID_OFFSET] && intCmdInQueue_dout[CMD_TYPE_L] != 0))) begin
                    copy_opt_start <= 1;
                    state <= WAIT_COPY_OPT;
                end else begin
                    if (!front_sent_reg) begin
                        if (queue_select) begin
                            int_cmd_in_idx <= int_cmd_in_idx+1;
                        end else begin
                            cmd_in_idx <= cmd_in_idx+1;
                        end
                    end
                    if (!front_sent_reg) begin
                        state <= SEND_CMD;
                    end else if (acc_avail_reg) begin
                        state <= CLEAR_HEADER;
                    end else begin
                        state <= IDLE;
                    end
                end
            end

            WAIT_COPY_OPT: begin
                copy_optimized[acc_id] <= 1'b1;
                if (copy_opt_finished) begin
                    if (!front_sent_reg) begin
                        if (queue_select) begin
                            int_cmd_in_idx <= int_cmd_in_idx+1;
                        end else begin
                            cmd_in_idx <= cmd_in_idx+1;
                        end
                    end
                    if (!front_sent_reg) begin
                        state <= SEND_CMD;
                    end else if (acc_avail_reg) begin
                        state <= CLEAR_HEADER;
                    end else begin
                        state <= IDLE;
                    end
                end
            end

            SEND_CMD: begin
                if (outStream_TREADY) begin
                    cmd_length <= cmd_length - 1;
                    if (outStream_TLAST) begin
                        if (DBG_REGS) begin
                            num_cmds[acc_id] <= num_cmds[acc_id] + 32'd1;
                        end
                        if (cmd_type == 2'd1) begin
                            state <= CLEAR_HEADER;
                        end else begin
                            state <= UPDATE_QUEUE_NEMPTY;
                        end
                    end else begin
                        if (queue_select) begin
                            int_cmd_in_idx <= int_cmd_in_idx+1;
                        end else begin
                            cmd_in_idx <= cmd_in_idx+1;
                        end
                    end
                end
            end

            CLEAR_HEADER: begin
                copy_optimized[acc_id] <= 1'b0;
                front_sent[acc_id] <= 1'b0;
                subqueue_idx[acc_id].cmd_in <= cmd_in_idx;
                subqueue_idx[acc_id].int_cmd_in <= int_cmd_in_idx;
                state <= IDLE;
            end

            UPDATE_QUEUE_NEMPTY: begin
                front_sent[acc_id] <= 1'b1;
                in_flight_queue_sel[acc_id] <= queue_select;
                acc_avail[acc_id] <= 0;
                if (queue_select && !intCmdInQueue_dout[ENTRY_VALID_OFFSET]) begin
                    queue_nempty[acc_id] <= 0;
                end
                state <= IDLE;
            end

        endcase

        if (sched_queue_nempty_write) begin
            queue_nempty[sched_queue_nempty_address] <= 1;
        end

        if (acc_avail_wr) begin
            acc_avail[acc_avail_wr_address] <= 1;
        end

        if (!rstn) begin
            int i;
            for (i = 0; i < MAX_ACCS; i = i+1) begin
                subqueue_idx[i] <= 0;
                if (DBG_REGS) begin
                    num_cmds[i] <= 32'd0;
                end
            end
            state <= IDLE;
            queue_nempty <= 0;
            acc_avail <= {MAX_ACCS{1'b1}};
            front_sent <= {MAX_ACCS{1'b0}};
            copy_optimized <= {MAX_ACCS{1'b0}};
            cmd_in_acc_id <= 0;
        end
    end

    if (DBG_REGS) begin
        always_ff @(posedge clk) begin
            dbg_acc_avail <= acc_avail;
            dbg_queue_nempty <= queue_nempty;
        end
    end

endmodule
