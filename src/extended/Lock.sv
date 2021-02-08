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

module Lock #(
    parameter MAX_ACCS = 16
) (
    input  clk,
    input  rstn,
    //inStream
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    input  [$clog2(MAX_ACCS)-1:0] inStream_TID,
    output logic inStream_TREADY,
    //outStream
    output [63:0] outStream_TDATA,
    output outStream_TVALID,
    input  outStream_TREADY,
    output outStream_TLAST,
    output [$clog2(MAX_ACCS)-1:0] outStream_TDEST
);

    import OmpSsManager::*;
    localparam ACC_BITS = $clog2(MAX_ACCS);

    enum {
        READ_HEADER,
        CHECK_LOCK,
        SEND_ACK
    } state;

    reg locked;
    reg next_locked;
    reg [ACC_BITS-1:0] acc_id;
    reg [7:0] cmd_code;
    reg [LOCK_ID_BITS-1:0] lock_id;
    reg [7:0] ack_data;

    assign outStream_TDATA = {56'd0, ack_data};
    assign outStream_TVALID = state == SEND_ACK;
    assign outStream_TDEST = acc_id;
    assign outStream_TLAST = 1'b1;

    always_comb begin

        inStream_TREADY = 0;

        case (state)

            READ_HEADER: begin
                inStream_TREADY = 1;
            end

        endcase

    end

    always_ff @(posedge clk) begin

        locked <= next_locked;

        case (state)

            READ_HEADER: begin
                acc_id <= inStream_TID;
                cmd_code <= inStream_TDATA[CMD_TYPE_H:CMD_TYPE_L];
                lock_id <= inStream_TDATA[LOCK_ID_H:LOCK_ID_L];
                if (inStream_TVALID) begin
                    state <= CHECK_LOCK;
                end
            end

            CHECK_LOCK: begin
                if (cmd_code == CMD_LOCK_CODE) begin
                    // Trying to lock
                    if (locked) begin
                        ack_data <= ACK_REJECT_CODE;
                    end else begin
                        ack_data <= ACK_OK_CODE;
                    end
                    next_locked <= 1;
                    state <= SEND_ACK;
                end else begin
                    if (cmd_code == CMD_UNLOCK_CODE) begin
                        // Unlocking
                        next_locked <= 0;
                    end
                    state <= READ_HEADER;
                end
            end

            SEND_ACK: begin
                if (outStream_TREADY) begin
                    state <= READ_HEADER;
                end
            end

        endcase

        if (!rstn) begin
            next_locked <= 0;
            state <= READ_HEADER;
        end
    end

endmodule
