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

module Spawn_In(
    input  clk,
    input  rstn,
    //SpawnInQueue memory
    output logic [31:0] spawnInQueue_addr,
    output spawnInQueue_en,
    output logic [7:0] spawnInQueue_we,
    output [63:0] spawnInQueue_din,
    input [63:0] spawnInQueue_dout,
    output spawnInQueue_clk,
    output spawnInQueue_rst,
    //outStream
    output logic [63:0] outStream_TDATA,
    output logic outStream_TVALID,
    input outStream_TREADY,
    output logic outStream_TLAST,
    //picosFinishTask
    output reg [31:0] picosFinishTask_TDATA,
    output logic picosFinishTask_TVALID,
    input picosFinishTask_TREADY
);

    import OmpSsManager::*;

    (* fsm_encoding = "one_hot" *)
    enum {
        START_LOOP_1,
        START_LOOP_2,
        READ_HEADER,
        READ_TID_1,
        READ_TID_2,
        NOTIFY_PICOS,
        NOTIFY_TW_1,
        NOTIFY_TW_2
    } state;

    reg [9:0] rIdx;
    wire [9:0] next_rIdx;
    reg [9:0] first_rIdx;
    logic [9:0] spawnInQueue_useful_addr;
    reg [63:0] pTask_id;
    reg spawnIn_valid;
    reg spawnIn_picos;

    assign spawnInQueue_addr = {19'd0, spawnInQueue_useful_addr, 3'd0};
    assign spawnInQueue_clk = clk;
    assign spawnInQueue_rst = 0;
    assign spawnInQueue_din[63:56] = 0;
    assign spawnInQueue_en = 1;

    assign next_rIdx = rIdx+1;

    always_comb begin

        spawnInQueue_we = 0;
        spawnInQueue_useful_addr = rIdx;

        outStream_TDATA = pTask_id;
        outStream_TVALID = 0;
        outStream_TLAST = 0;

        picosFinishTask_TVALID = 0;

        case (state)

            READ_HEADER: begin
                if (spawnIn_valid) begin
                    spawnInQueue_we[7] = 1;
                    spawnInQueue_useful_addr = next_rIdx;
                end
            end

            READ_TID_1: begin
                spawnInQueue_we[7] = 1;
            end

            READ_TID_2: begin
                spawnInQueue_we[7] = 1;
                spawnInQueue_useful_addr = first_rIdx;
            end

            NOTIFY_TW_1: begin
                outStream_TDATA[TYPE_B] = 0;
                outStream_TVALID = 1;
            end

            NOTIFY_TW_2: begin
                outStream_TVALID = 1;
                outStream_TLAST = 1;
            end

            NOTIFY_PICOS: begin
                picosFinishTask_TVALID = 1;
            end

        endcase

    end

    always_ff @(posedge clk) begin

        spawnIn_valid <= spawnInQueue_dout[ENTRY_VALID_OFFSET];
        spawnIn_picos <= spawnInQueue_dout[62];

        case (state)

            START_LOOP_1: begin
                state <= START_LOOP_2;
            end

            START_LOOP_2: begin
                state <= READ_HEADER;
            end

            READ_HEADER: begin
                first_rIdx <= rIdx;
                if (spawnIn_valid) begin
                    state <= READ_TID_1;
                    rIdx <= rIdx + 2;
                end
            end

            READ_TID_1: begin
                picosFinishTask_TDATA <= spawnInQueue_dout[31:0];
                state <= READ_TID_2;
                rIdx <= next_rIdx;
            end

            READ_TID_2: begin
                pTask_id <= spawnInQueue_dout;
                if (!spawnIn_picos) begin
                    state <= NOTIFY_PICOS;
                end else begin
                    state <= NOTIFY_TW_1;
                end
            end

            NOTIFY_PICOS: begin
                if (picosFinishTask_TREADY) begin
                    state <= NOTIFY_TW_1;
                end
            end

            NOTIFY_TW_1: begin
                if (outStream_TREADY) begin
                    state <= NOTIFY_TW_2;
                end
            end

            NOTIFY_TW_2: begin
                if (outStream_TREADY) begin
                    state <= START_LOOP_1;
                end
            end

        endcase

        if (!rstn) begin
            rIdx <= 0;
            state <= START_LOOP_1;
        end

    end

endmodule
