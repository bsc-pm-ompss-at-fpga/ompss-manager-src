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

module Spawn_In #(
    parameter SPAWNIN_QUEUE_LEN = 1024
) (
    input  clk,
    input  rstn,
    //SpawnInQueue memory
    output logic [31:0] spawnin_queue_addr,
    output spawnin_queue_en,
    output logic [7:0] spawnin_queue_we,
    output [63:0] spawnin_queue_din,
    input [63:0] spawnin_queue_dout,
    output spawnin_queue_clk,
    output spawnin_queue_rst,
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
    localparam QUEUE_BITS = $clog2(SPAWNIN_QUEUE_LEN);

    typedef enum bit [2:0] {
        START_LOOP_1,
        START_LOOP_2,
        READ_HEADER,
        READ_TID_1,
        READ_TID_2,
        NOTIFY_PICOS,
        NOTIFY_TW_1,
        NOTIFY_TW_2
    } State_t;

    (* fsm_encoding = "one_hot" *)
    State_t state;

    reg [QUEUE_BITS-1:0] rIdx;
    wire [QUEUE_BITS-1:0] next_rIdx;
    reg [QUEUE_BITS-1:0] first_rIdx;
    logic [QUEUE_BITS-1:0] spawnin_queue_useful_addr;
    reg [63:0] pTask_id;
    reg spawnIn_valid;
    reg spawnIn_picos;

    assign spawnin_queue_addr = {{29-QUEUE_BITS{1'b0}}, spawnin_queue_useful_addr, 3'd0};
    assign spawnin_queue_clk = clk;
    assign spawnin_queue_rst = 0;
    assign spawnin_queue_din = 64'd0;
    assign spawnin_queue_en = 1;

    assign next_rIdx = rIdx+1;

    always_comb begin

        spawnin_queue_we = 0;
        spawnin_queue_useful_addr = rIdx;

        outStream_TDATA = pTask_id;
        outStream_TVALID = 0;
        outStream_TLAST = 0;

        picosFinishTask_TVALID = 0;

        case (state)

            READ_HEADER: begin
                if (spawnIn_valid) begin
                    spawnin_queue_we[7] = 1;
                    spawnin_queue_useful_addr = next_rIdx;
                end
            end

            READ_TID_1: begin
                spawnin_queue_we[7] = 1;
            end

            READ_TID_2: begin
                spawnin_queue_we[7] = 1;
                spawnin_queue_useful_addr = first_rIdx;
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

        spawnIn_valid <= spawnin_queue_dout[ENTRY_VALID_OFFSET];
        spawnIn_picos <= spawnin_queue_dout[62];

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
                picosFinishTask_TDATA <= spawnin_queue_dout[31:0];
                state <= READ_TID_2;
                rIdx <= next_rIdx;
            end

            READ_TID_2: begin
                pTask_id <= spawnin_queue_dout;
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
