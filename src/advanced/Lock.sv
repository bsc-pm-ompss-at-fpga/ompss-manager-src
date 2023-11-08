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

module Lock #(
    parameter ACC_BITS = 4
) (
    input  clk,
    input  rstn,
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
    output [ACC_BITS-1:0] outStream_TDEST
);

    import OmpSsManager::*;

    typedef enum bit [1:0] {
        READ_HEADER,
        CHECK_LOCK,
        SEND_ACK
    } State_t;

    State_t state;

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
