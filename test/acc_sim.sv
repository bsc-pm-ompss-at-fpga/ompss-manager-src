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

module acc_sim #(
    parameter ID = 0
) (
    input clk,
    input rst,
    GenAxis.slave inStream,
    GenAxis.master outStream
);

    import OmpSsManager::*;

    typedef enum {
        IDLE,
        READ_TID,
        READ_PTID,
        READ_ARGS,
        WAIT_TIME,
        SEND_COMMAND,
        SEND_TID,
        SEND_PTID,
        READ_HWINS_ADDR
    } State_t;

    State_t state;
    int count;
    reg [63:0] tid;
    reg [63:0] ptid;
    logic [63:0] outPort;
    int wait_time;

    assign inStream.ready = state == IDLE || state == READ_HWINS_ADDR || state == READ_TID || state == READ_PTID || state == READ_ARGS;
    assign outStream.valid = state == SEND_COMMAND || state == SEND_TID || state == SEND_PTID;
    assign outStream.last = state == SEND_PTID;
    assign outStream.dest = HWR_CMDOUT_ID;
    assign outStream.data = outPort;
    assign outStream.id = ID;

    always_comb begin
        outPort = tid;
        if (state == SEND_COMMAND) begin
            outPort = 64'hXXXXXXXXXXXXXX03;
        end else if (state == SEND_PTID) begin
            outPort = ptid;
        end
    end

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                count <= 0;
                if (inStream.valid) begin
                    wait_time <= $urandom_range(100);
                    if (inStream.data[CMD_TYPE_H:CMD_TYPE_L] == SETUP_HW_INST_CODE) begin
                        state <= READ_HWINS_ADDR;
                    end else begin
                        state <= READ_TID;
                    end
                end
            end

            READ_HWINS_ADDR: begin
                if (inStream.valid) begin
                    state <= IDLE;
                end
            end

            READ_TID: begin
                tid <= inStream.data;
                if (inStream.valid) begin
                    state <= READ_PTID;
                end
            end

            READ_PTID: begin
                ptid <= inStream.data;
                if (inStream.valid & inStream.last) begin
                    state <= WAIT_TIME;
                end else if (inStream.valid) begin
                    state <= READ_ARGS;
                end
            end

            READ_ARGS: begin
                if (inStream.valid && inStream.last) begin
                    state <= WAIT_TIME;
                end
            end

            WAIT_TIME: begin
                count <= count+1;
                if (count == wait_time) begin
                    state <= SEND_COMMAND;
                end
            end

            SEND_COMMAND: begin
                if (outStream.ready) begin
                    state <= SEND_TID;
                end
            end

            SEND_TID: begin
                if (outStream.ready) begin
                    state <= SEND_PTID;
                end
            end

            SEND_PTID: begin
                if (outStream.ready) begin
                    state <= IDLE;
                end
            end

        endcase

        if (rst) begin
            state <= IDLE;
        end
    end

endmodule
