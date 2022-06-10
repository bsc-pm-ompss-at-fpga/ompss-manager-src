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

module Taskwait #(
    parameter ACC_BITS = 4,
    parameter MAX_ACC_CREATORS = 16,
    parameter TW_MEM_BITS = $clog2(MAX_ACC_CREATORS),
    parameter TW_MEM_WIDTH = 101
) (
    input clk,
    input rstn,
    //inStream
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    input  [ACC_BITS-1:0] inStream_TID,
    output logic inStream_TREADY,
    //outStream
    output [63:0] outStream_TDATA,
    output outStream_TVALID,
    input  outStream_TREADY,
    output outStream_TLAST,
    output [ACC_BITS-1:0] outStream_TDEST,
    //Taskwait memory
    output [TW_MEM_BITS-1:0] twInfo_addr,
    output logic twInfo_en,
    output twInfo_we,
    output logic [TW_MEM_WIDTH-1:0] twInfo_din,
    input  [TW_MEM_WIDTH-1:0] twInfo_dout,
    output twInfo_clk
);

    import OmpSsManager::*;

    typedef enum bit [2:0] {
        READ_HEADER,
        READ_TID,
        GET_ENTRY_1,
        GET_ENTRY_2,
        CHECK_RESULTS,
        WAKEUP_ACC
    } State_t;

    State_t state;

    reg [TW_MEM_BITS-1:0] not_valid_idx;
    reg not_valid_entry_found;
    reg task_id_not_found;
    reg [TW_MEM_BITS-1:0] count;
    wire [TW_MEM_BITS-1:0] prev_count;
    wire [TW_MEM_BITS-1:0] next_count;
    reg [31:0] components;
    reg [31:0] tw_info_components;
    reg [31:0] result_components;
    reg [31:0] tw_info_din_components;
    reg [ACC_BITS-1:0] acc_id;
    reg [ACC_BITS-1:0] inStream_tid_r;
    reg [63:0] task_id;
    reg [63:0] tw_info_task_id;
    reg tw_info_valid;
    reg _type;
    reg update_entry;

    assign twInfo_clk = clk;

    assign next_count = count+1;
    assign prev_count = count-1;

    assign outStream_TDATA = 64'd1;
    assign outStream_TVALID = state == WAKEUP_ACC;
    assign outStream_TDEST = acc_id;
    assign outStream_TLAST = 1'b1;

    assign twInfo_addr = count;
    assign twInfo_we = update_entry;

    always_comb begin

        inStream_TREADY = 0;

        twInfo_en = update_entry;
        twInfo_din = 112'd0;
        twInfo_din[TW_INFO_VALID_ENTRY_B] = tw_info_valid;
        twInfo_din[TW_INFO_ACCID_L+ACC_BITS-1:TW_INFO_ACCID_L] = acc_id;
        twInfo_din[TW_INFO_COMPONENTS_H:TW_INFO_COMPONENTS_L] = tw_info_din_components;
        twInfo_din[TW_INFO_TASKID_H:TW_INFO_TASKID_L] = task_id;

        case (state)

            READ_HEADER: begin
                inStream_TREADY = 1;
            end

            READ_TID: begin
                inStream_TREADY = 1;
                twInfo_en = 1;
            end

            GET_ENTRY_2: begin
                twInfo_en = 1;
            end

        endcase

    end

    always_ff @(posedge clk) begin

        tw_info_task_id <= twInfo_dout[TW_INFO_TASKID_H:TW_INFO_TASKID_L];
        tw_info_valid <= twInfo_dout[TW_INFO_VALID_ENTRY_B];
        tw_info_components <= twInfo_dout[TW_INFO_COMPONENTS_H:TW_INFO_COMPONENTS_L];
        if (_type) begin
            if (task_id_not_found) begin
                tw_info_din_components <= 0-components;
            end else begin
                tw_info_din_components <= result_components;
            end
        end else begin
            if (task_id_not_found) begin
                tw_info_din_components <= 1;
            end else begin
                tw_info_din_components <= result_components;
            end
        end
        if (_type) begin
            result_components <= tw_info_components - components;
        end else begin
            result_components <= tw_info_components + 1;
        end

        update_entry <= 0;

        task_id_not_found <= 0;

        case (state)

            READ_HEADER: begin
                inStream_tid_r <= inStream_TID;
                not_valid_entry_found <= 0;
                count <= 0;
                components <= inStream_TDATA[INSTREAM_COMPONENTS_H:INSTREAM_COMPONENTS_L];
                _type <= inStream_TDATA[TYPE_B];
                if (inStream_TVALID) begin
                    state <= READ_TID;
                end
            end

            READ_TID: begin
                task_id <= inStream_TDATA;
                if (inStream_TVALID) begin
                    state <= GET_ENTRY_1;
                end
            end

            GET_ENTRY_1: begin
                count <= next_count;
                acc_id <= twInfo_dout[TW_INFO_ACCID_L+ACC_BITS-1:TW_INFO_ACCID_L];
                state <= GET_ENTRY_2;
            end

            GET_ENTRY_2: begin
                if (!not_valid_entry_found && !tw_info_valid) begin
                    not_valid_idx <= prev_count;
                    not_valid_entry_found <= 1;
                end
                if (tw_info_valid && tw_info_task_id == task_id) begin
                    state <= CHECK_RESULTS;
                end else if (count == MAX_ACC_CREATORS[TW_MEM_BITS-1:0]) begin
                    task_id_not_found <= 1;
                    state <= CHECK_RESULTS;
                end else begin
                    state <= GET_ENTRY_1;
                end
            end

            CHECK_RESULTS: begin
                if (_type) begin
                    acc_id <= inStream_tid_r;
                end
                if (task_id_not_found) begin
                    tw_info_valid <= 1;
                    count <= not_valid_idx;
                end else begin
                    tw_info_valid <= result_components != 0;
                    count <= prev_count;
                end
                // If an accelerator asks for a taskwait without creating any tasks, there's no need to allocate
                // memory and it can be waken up immediately
                if (task_id_not_found && _type) begin
                    update_entry <= components != 0;
                    state <= components != 0 ? READ_HEADER : WAKEUP_ACC;
                end else begin
                    update_entry <= 1;
                    if (!task_id_not_found && result_components == 0) begin
                        state <= WAKEUP_ACC;
                    end else begin
                        state <= READ_HEADER;
                    end
                end
            end

            WAKEUP_ACC: begin
                if (outStream_TREADY) begin
                    state <= READ_HEADER;;
                end
            end

        endcase

        if (!rstn) begin
            state <= READ_HEADER;
        end
    end

endmodule
