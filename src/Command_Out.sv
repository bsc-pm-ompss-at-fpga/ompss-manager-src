/*--------------------------------------------------------------------
  (C) Copyright 2017-2020 Barcelona Supercomputing Center
                          Centro Nacional de Supercomputacion

  This file is part of OmpSs@FPGA toolchain.

  This code is free software; you can redistribute it and/or modify
  it under the terms of the GNU Lesser General Public License as
  published by the Free Software Foundation; either version 3 of
  the License, or (at your option) any later version.

  OmpSs@FPGA toolchain is distributed in the hope that it will be
  useful, but WITHOUT ANY WARRANTY; without even the implied
  warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this code. If not, see <www.gnu.org/licenses/>.
--------------------------------------------------------------------*/

`timescale 1ns / 1ps

module Command_Out
(
    input  ap_clk,
    input  ap_rst_n,
    output [31:0] cmdOutQueue_V_address0,
    output logic cmdOutQueue_V_ce0,
    output logic [7:0] cmdOutQueue_V_we0,
    output logic [63:0] cmdOutQueue_V_d0,
    input  [63:0] cmdOutQueue_V_q0,
    output cmdOutQueue_V_clk,
    output cmdOutQueue_V_rst,
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    output logic inStream_TREADY,
    input  [3:0] inStream_TID,
    output logic [63:0] outStream_TDATA,
    output logic outStream_TVALID,
    input  outStream_TREADY,
    output outStream_TLAST,
    output [31:0] picosFinishTask_TDATA,
    output logic picosFinishTask_TVALID,
    input  picosFinishTask_TREADY,
    output reg [3:0] acc_avail_wr_addr,
    output reg acc_avail_wr
);

    import OmpSsManager::*;
        
    reg r_READ_HEADER;
    reg r_READ_TID;
    reg r_READ_PTID;
    reg r_CMD_OUT_WAIT;
    reg r_WRITE_TID;
    reg r_WRITE_HEADER;
    reg r_NOTIFY_PICOS;
    reg r_NOTIFY_TW_1;
    reg r_NOTIFY_TW_2;
    
    reg [SUBQUEUE_BITS-1:0] wIdx_mem[MAX_ACCS];
    reg [SUBQUEUE_BITS-1:0] wIdx;
    reg [SUBQUEUE_BITS-1:0] wIdx_first;
    wire [SUBQUEUE_BITS-1:0] next_wIdx;
    reg [ACC_BITS-1:0] acc_id;
    reg [63:0] task_id;
    reg [63:0] parent_task_id;
    reg notify_tw;
    
    assign cmdOutQueue_V_clk = ap_clk;
    assign cmdOutQueue_V_rst = 0;
    
    assign cmdOutQueue_V_address0[31:3 + SUBQUEUE_BITS+ACC_BITS] = 0;
    assign cmdOutQueue_V_address0[3 + SUBQUEUE_BITS+ACC_BITS-1:3 + SUBQUEUE_BITS] = acc_id;
    assign cmdOutQueue_V_address0[3 + SUBQUEUE_BITS-1:3] = wIdx;
    assign cmdOutQueue_V_address0[2:0] = 0;
    
    assign outStream_TLAST = r_NOTIFY_TW_2;
    
    assign picosFinishTask_TDATA = task_id[31:0];
    
    assign next_wIdx = wIdx + 1;
    
    always_comb begin
    
        cmdOutQueue_V_ce0 = r_READ_PTID || r_CMD_OUT_WAIT || r_WRITE_TID || r_WRITE_HEADER;
        cmdOutQueue_V_we0 = r_WRITE_TID || r_WRITE_HEADER ? 8'hFF : 0;
        cmdOutQueue_V_d0 = task_id;
        
        inStream_TREADY = r_READ_HEADER || r_READ_TID || r_READ_PTID;
        outStream_TVALID = notify_tw && (r_NOTIFY_TW_1 || r_NOTIFY_TW_2);
        picosFinishTask_TVALID = r_NOTIFY_PICOS && !task_id[62];
        
        outStream_TDATA = 64'h8000001000000001;
        
        if (r_WRITE_HEADER) begin
            cmdOutQueue_V_d0[ENTRY_VALID_BYTE_OFFSET+7:ENTRY_VALID_BYTE_OFFSET] = 8'h80;
            cmdOutQueue_V_d0[15:8] = {{(8-ACC_BITS){1'd0}}, acc_id};
            cmdOutQueue_V_d0[7:0] = 8'h03;
        end
        if (r_NOTIFY_TW_2) begin
            outStream_TDATA = parent_task_id;
        end
 
    end
    
    always_ff @(posedge ap_clk) begin
        
        acc_avail_wr_addr[ACC_BITS-1:0] <= inStream_TID[ACC_BITS-1:0];
        acc_avail_wr <= 0;
        
        if (r_READ_HEADER) begin
            acc_id <= inStream_TID[ACC_BITS-1:0];
            acc_avail_wr <= inStream_TVALID;
            r_READ_TID <= inStream_TVALID;
            r_READ_HEADER <= !inStream_TVALID;
        end
        if (r_READ_TID) begin
            wIdx <= wIdx_mem[acc_id];
            task_id <= inStream_TDATA;
            r_READ_PTID <= inStream_TVALID;
            r_READ_TID <= !inStream_TVALID;
        end
        if (r_READ_PTID) begin
            wIdx_first <= wIdx;
            parent_task_id <= inStream_TDATA;
            if (inStream_TVALID) begin
                if (!task_id[63]) begin
                    r_CMD_OUT_WAIT <= 1;
                    r_READ_PTID <= 0;
                end else begin
                    r_NOTIFY_PICOS <= 1;
                    r_READ_PTID <= 0;
                end
            end
        end
        r_WRITE_TID <= 0;
        if (r_CMD_OUT_WAIT) begin
            if (!cmdOutQueue_V_q0[ENTRY_VALID_OFFSET]) begin
                wIdx <= next_wIdx;
                r_WRITE_TID <= 1;
                r_CMD_OUT_WAIT <= 0;
            end
        end
        if (r_WRITE_TID) begin
            wIdx <= wIdx_first;
            wIdx_first <= next_wIdx;
        end
        r_WRITE_HEADER <= r_WRITE_TID;
        if (r_WRITE_HEADER) begin
            r_READ_HEADER <= 1;
            wIdx_mem[acc_id] <= wIdx_first;
        end
        if (r_NOTIFY_PICOS) begin
            notify_tw <= parent_task_id != 0;
            if (task_id[62] || picosFinishTask_TREADY) begin
                r_NOTIFY_TW_1 <= 1;
                r_NOTIFY_PICOS <= 0;
            end
        end
        if (r_NOTIFY_TW_1) begin
            if (!notify_tw || outStream_TREADY) begin
                r_NOTIFY_TW_2 <= 1;
                r_NOTIFY_TW_1 <= 0;
            end
        end
        if (r_NOTIFY_TW_2) begin
            if (!notify_tw || outStream_TREADY) begin
                r_READ_HEADER <= 1;
                r_NOTIFY_TW_2 <= 0;
            end
        end
        
        if (!ap_rst_n) begin
            int i;
            for (i = 0; i < MAX_ACCS; i = i+1) begin
                wIdx_mem[i] <= 0;
            end
            r_READ_HEADER <= 1;
            r_READ_TID <= 0;
            r_READ_PTID <= 0;
            r_CMD_OUT_WAIT <= 0;
            r_WRITE_TID <= 0;
            r_WRITE_HEADER <= 0;
            r_NOTIFY_PICOS <= 0;
            r_NOTIFY_TW_1 <= 0;
            r_NOTIFY_TW_2 <= 0;
        end
    
    end

endmodule