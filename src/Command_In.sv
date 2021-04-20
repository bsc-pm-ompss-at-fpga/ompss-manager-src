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

module Command_In #(
    parameter MAX_ACCS = 16,
    parameter ACC_BITS = $clog2(MAX_ACCS),
    parameter SUBQUEUE_BITS = 6
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
    output intCmdInQueue_clk,
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
    input acc_avail_wr
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
        CLEAR_HEADER
    } State_t;

    (* fsm_encoding = "one_hot" *)
    State_t state;

    struct packed {
        logic [SUBQUEUE_BITS-1:0] cmd_in;
        logic [SUBQUEUE_BITS-1:0] int_cmd_in;
    } subqueue_idx[MAX_ACCS];

    reg [MAX_ACCS-1:0] acc_avail;
    reg [MAX_ACCS-1:0] queue_nempty;
    //NOTE: For the moment, I don't think the shift feature is really necessary
    //reg shift;
    //reg [ACC_BITS-1:0] queue_nempty_offset;

    reg [ACC_BITS-1:0] cmd_in_acc_id;
    reg [ACC_BITS-1:0] acc_id;
    //reg [ACC_BITS-1:0] shift_acc_id;
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
        .SUBQUEUE_BITS(SUBQUEUE_BITS)
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
        .cmd_type(cmd_type)
    );

    assign cmdin_queue_clk = clk;
    assign cmdin_queue_rst = 0;
    assign intCmdInQueue_clk = clk;

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

        /*if (shift) begin
            queue_nempty <= {queue_nempty[0], queue_nempty[MAX_ACCS-1:1]};
            acc_avail <= {acc_avail[0], acc_avail[MAX_ACCS-1:1]};
        end*/

        //shift <= 0;
        //shift_acc_id <= acc_id + queue_nempty_offset;

        copy_opt_start <= 0;

        case (state)

            IDLE: begin
                int i;
                acc_id <= cmd_in_acc_id;
                queue_select <= 0;
                for (i = 0; i < MAX_ACCS; i = i+1) begin
                    if (queue_nempty[i] && acc_avail[i]) begin
                        queue_select <= 1;
                        acc_id <= i[ACC_BITS-1:0] /*- queue_nempty_offset*/;
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
                if (!acc_avail[acc_id/* + queue_nempty_offset*/]) begin
                    state <= IDLE;
                end else begin
                    state <= ISSUE_CMD_READ;
                end
                cmd_in_idx <= subqueue_idx[acc_id].cmd_in;
                int_cmd_in_idx <= subqueue_idx[acc_id].int_cmd_in;
            end

            ISSUE_CMD_READ: begin
                //queue_nempty_offset <= queue_nempty_offset - 1;
                //shift <= 1;
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
                state <= CHECK_NEXT_CMD;
            end

            CHECK_NEXT_CMD: begin
                //If any cmd is setup inst, argument flag optimization is not necessary
                if (cmd_type != 2'd1 && ((!queue_select && cmdin_queue_dout[ENTRY_VALID_OFFSET] && cmdin_queue_dout[CMD_TYPE_L] != 0)
                                       || (queue_select && intCmdInQueue_dout[ENTRY_VALID_OFFSET] && intCmdInQueue_dout[CMD_TYPE_L] != 0))) begin
                    state <= WAIT_COPY_OPT;
                    copy_opt_start <= 1;
                end else begin
                    state <= SEND_CMD;
                    if (queue_select) begin
                        int_cmd_in_idx <= int_cmd_in_idx+1;
                    end else begin
                        cmd_in_idx <= cmd_in_idx+1;
                    end
                end
            end

            WAIT_COPY_OPT: begin
                if (copy_opt_finished) begin
                    state <= SEND_CMD;
                    if (queue_select) begin
                        int_cmd_in_idx <= int_cmd_in_idx+1;
                    end else begin
                        cmd_in_idx <= cmd_in_idx+1;
                    end
                end
            end

            SEND_CMD: begin
                if (outStream_TREADY) begin
                    cmd_length <= cmd_length - 1;
                    if (outStream_TLAST) begin
                        state <= CLEAR_HEADER;
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
                if (queue_select && !intCmdInQueue_dout[ENTRY_VALID_OFFSET]) begin
                    queue_nempty[acc_id/*shift_acc_id*/] <= 0;
                end
                if (cmd_type != 1) begin //Setup instrumentation commands do not block the accelerator
                    acc_avail[acc_id/*shift_acc_id*/] <= 0;
                end
                subqueue_idx[acc_id].cmd_in <= cmd_in_idx;
                subqueue_idx[acc_id].int_cmd_in <= int_cmd_in_idx;
                state <= IDLE;
            end

        endcase

        if (sched_queue_nempty_write) begin
            queue_nempty[sched_queue_nempty_address /*+ queue_nempty_offset*/] <= 1;
        end

        if (acc_avail_wr) begin
            acc_avail[acc_avail_wr_address /*+ queue_nempty_offset*/] <= 1;
        end

        if (!rstn) begin
            int i;
            for (i = 0; i < MAX_ACCS; i = i+1) begin
                subqueue_idx[i] <= 0;
            end
            state <= IDLE;
            queue_nempty <= 0;
            acc_avail <= {MAX_ACCS{1'b1}};
            cmd_in_acc_id <= 0;
            //queue_nempty_offset <= 0;
        end
    end

endmodule
