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


module Cutoff_Manager #(
    parameter ACC_BITS = 4,
    parameter MAX_ACC_CREATORS = 16,
    parameter MAX_DEPS_PER_TASK = 0,
    localparam TW_MEM_BITS = $clog2(MAX_ACC_CREATORS),
    localparam TW_MEM_WIDTH = 32
) (
    input clk,
    input rstn,
    input picos_full,
    //inStream
    input inStream_tvalid,
    output reg inStream_tready,
    input [63:0] inStream_tdata,
    input inStream_tlast,
    input [ACC_BITS-1:0] inStream_tid,
    //Scheduler interface
    output sched_inStream_tvalid,
    input sched_inStream_tready,
    output [63:0] sched_inStream_tdata,
    output sched_inStream_tlast,
    output [ACC_BITS-1:0] sched_inStream_tid,
    //Picos interface
    output deps_new_task_tvalid,
    input deps_new_task_tready,
    output [63:0] deps_new_task_tdata,
    //Ack interface
    output ack_tvalid,
    input ack_tready,
    output logic [63:0] ack_tdata,
    output [ACC_BITS-1:0] ack_tdest,
    //Taskwait memory
    output reg [TW_MEM_BITS-1:0] tw_info_addr,
    output logic tw_info_en,
    output logic tw_info_we,
    output logic [TW_MEM_WIDTH-1:0] tw_info_din,
    input [TW_MEM_WIDTH-1:0] tw_info_dout
);

    import OmpSsManager::*;

    localparam MAX_ADDR = MAX_ACC_CREATORS-1;
    localparam DEPS_BITS = $clog2(MAX_DEPS_PER_TASK+1);

    typedef enum bit [3:0] {
        IDLE,
        WRITE_TW_INFO,
        ISSUE_READ_TW_INFO,
        READ_TW_INFO,
        READ_REST,
        BUF_FULL,
        BUF_EMPTY,
        ACK,
        WAIT_PICOS
    } State_t;

    State_t state;

    reg [ACC_BITS-1:0] acc_id;
    reg [63:0] buf_tdata;
    reg buf_tlast;
    reg accept;
    reg final_mode;
    reg deps_selected;
    reg buf_header;
    wire selected_slave_tready;
    wire has_deps;

    assign has_deps = inStream_tdata[NUM_DEPS_OFFSET +: DEPS_BITS] != {DEPS_BITS{1'b0}};

    assign tw_info_addr = acc_id[TW_MEM_BITS-1:0];
    assign tw_info_din = 32'd0;
    assign tw_info_en = state == WRITE_TW_INFO || state == ISSUE_READ_TW_INFO;
    assign tw_info_we = state == WRITE_TW_INFO;

    assign ack_tvalid = state == ACK;
    assign ack_tdest = acc_id;
    assign ack_tdata = accept ? ACK_OK_CODE : (final_mode ? ACK_FINAL_CODE : ACK_REJECT_CODE);

    assign selected_slave_tready = deps_selected ? deps_new_task_tready : sched_inStream_tready;

    assign sched_inStream_tvalid = state == BUF_FULL && !deps_selected;
    assign sched_inStream_tdata = buf_tdata;
    assign sched_inStream_tlast = buf_tlast;
    assign sched_inStream_tid = acc_id;
    assign deps_new_task_tvalid = state == BUF_FULL && deps_selected;
    assign deps_new_task_tdata = buf_tdata;

    assign inStream_tready = state == IDLE || state == BUF_EMPTY || state == READ_REST || (state == BUF_FULL && selected_slave_tready && !buf_tlast);

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                acc_id <= inStream_tid;
                deps_selected <= has_deps;
                buf_tdata <= inStream_tdata;
                buf_tlast <= 1'b0;
                buf_header <= 1'b1;
                if (inStream_tvalid) begin
                    if (inStream_tdata[TASK_SEQ_ID_H:TASK_SEQ_ID_L] == 32'd0) begin
                        state <= WRITE_TW_INFO;
                    end else if (has_deps && !picos_full && deps_new_task_tready) begin
                        state <= BUF_FULL;
                    end else if (has_deps && !deps_new_task_tready) begin
                        state <= WAIT_PICOS;
                    end else if (has_deps && picos_full) begin
                        state <= ISSUE_READ_TW_INFO;
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end

            WRITE_TW_INFO: begin
                final_mode <= 1'b1;
                if (deps_selected && deps_new_task_tready && picos_full) begin
                    state <= READ_REST;
                end else if (!deps_selected || deps_new_task_tready) begin
                    state <= BUF_FULL;
                end else begin
                    state <= WAIT_PICOS;
                end
            end

            WAIT_PICOS: begin
                if (deps_new_task_tready) begin
                    if (picos_full) begin
                        state <= ISSUE_READ_TW_INFO;
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end

            ISSUE_READ_TW_INFO: begin
                state <= READ_TW_INFO;
            end

            READ_TW_INFO: begin
                final_mode <= tw_info_dout == buf_tdata[TASK_SEQ_ID_H:TASK_SEQ_ID_L];
                state <= READ_REST;
            end

            READ_REST: begin
                accept <= 1'b0;
                if (inStream_tvalid && inStream_tlast) begin
                    state <= ACK;
                end
            end

            BUF_FULL: begin
                accept <= 1'b1;
                if (!inStream_tvalid && selected_slave_tready && !buf_tlast) begin
                    state <= BUF_EMPTY;
                end else if (selected_slave_tready && buf_tlast) begin
                    if (deps_selected) begin
                        state <= ACK;
                    end else begin
                        state <= IDLE;
                    end
                end
                if (inStream_tvalid && selected_slave_tready) begin
                    // Overwrite the ptid with the acc id
                    buf_tdata[TW_MEM_BITS-1:0] <= buf_header ? acc_id[TW_MEM_BITS-1:0] : inStream_tdata[TW_MEM_BITS-1:0];
                    buf_tdata[63:TW_MEM_BITS] <= inStream_tdata[63:TW_MEM_BITS];
                    buf_tlast <= inStream_tlast;
                    buf_header <= 1'b0;
                end
            end

            BUF_EMPTY: begin
                buf_tdata[TW_MEM_BITS-1:0] <= buf_header ? acc_id[TW_MEM_BITS-1:0] : inStream_tdata[TW_MEM_BITS-1:0];
                buf_tdata[63:TW_MEM_BITS] <= inStream_tdata[63:TW_MEM_BITS];
                buf_tlast <= inStream_tlast;
                if (inStream_tvalid) begin
                    buf_header <= 1'b0;
                    state <= BUF_FULL;
                end
            end

            ACK: begin
                if (ack_tready) begin
                    state <= IDLE;
                end
            end

        endcase

        if (!rstn) begin
            state <= IDLE;
        end
    end

endmodule
