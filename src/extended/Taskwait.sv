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

module Taskwait
(
    input  ap_clk,
    input  ap_rst_n,
    //inStream
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    input  [3:0] inStream_TID,
    output logic inStream_TREADY,
    output [7:0] outStream_TDATA,
    //outStream
    output outStream_TVALID,
    input  outStream_TREADY,
    output [3:0] outStream_TDEST,
    //Taskwait memory
    output [3:0] twInfo_address0,
    output logic twInfo_ce0,
    output twInfo_we0,
    output logic [111:0] twInfo_d0,
    input  [111:0] twInfo_q0,
    output twInfo_clk
);

    import OmpSsManager::*;

    localparam ACC_BITS = $clog2(MAX_ACCS);
    
    enum {
        READ_HEADER,
        READ_TID,
        GET_ENTRY_1,
        GET_ENTRY_2,
        CHECK_RESULTS,
        WAKEUP_ACC
    } state;
    
    reg [TW_MEM_BITS-1:0] not_valid_idx;
    reg not_valid_entry_found;
    reg task_id_not_found;
    reg [TW_MEM_BITS-1:0] count;
    wire [TW_MEM_BITS-1:0] prev_count;
    wire [TW_MEM_BITS-1:0] next_count;
    reg [31:0] components;
    reg [31:0] tw_info_components;
    reg [31:0] result_components;
    reg [ACC_BITS-1:0] acc_id;
    reg [ACC_BITS-1:0] inStream_tid_r;
    reg [63:0] task_id;
    reg [63:0] tw_info_task_id;
    reg tw_info_valid;
    reg _type;
    reg update_entry;
    
    assign twInfo_clk = ap_clk;
    
    assign next_count = count+1;
    assign prev_count = count-1;
    
    if (ACC_BITS != 4) begin
        assign outStream_TDEST[3:ACC_BITS] = 0;
    end
    
    if (TW_MEM_BITS != 4) begin
        assign twInfo_address0[3:TW_MEM_BITS] = 0;
    end
    
    assign outStream_TDATA = 8'd1;
    assign outStream_TVALID = state == WAKEUP_ACC;
    assign outStream_TDEST[ACC_BITS-1:0] = acc_id;
    
    assign twInfo_address0[TW_MEM_BITS-1:0] = count;
    assign twInfo_we0 = update_entry;
    
    always_comb begin
    
        inStream_TREADY = 0;
        
        twInfo_ce0 = update_entry;
        twInfo_d0 = 112'dX;
        twInfo_d0[TW_INFO_VALID_ENTRY_B] = tw_info_valid;
        twInfo_d0[TW_INFO_ACCID_L+ACC_BITS-1:TW_INFO_ACCID_L] = acc_id;
        twInfo_d0[TW_INFO_COMPONENTS_H:TW_INFO_COMPONENTS_L] = result_components;
        twInfo_d0[TW_INFO_TASKID_H:TW_INFO_TASKID_L] = task_id;
        
        case (state)
        
            READ_HEADER: begin
                inStream_TREADY = 1;
            end
            
            READ_TID: begin
                inStream_TREADY = 1;
                twInfo_ce0 = 1;
            end
            
            GET_ENTRY_2: begin
                twInfo_ce0 = 1;
            end
        
        endcase
    
    end
    
    always_ff @(posedge ap_clk) begin
    
        tw_info_task_id <= twInfo_q0[TW_INFO_TASKID_H:TW_INFO_TASKID_L];
        tw_info_valid <= twInfo_q0[TW_INFO_VALID_ENTRY_B];
        if (!twInfo_q0[TW_INFO_VALID_ENTRY_B]) begin
            tw_info_components <= 0;
        end else begin
            tw_info_components <= twInfo_q0[TW_INFO_COMPONENTS_H:TW_INFO_COMPONENTS_L];
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
                inStream_tid_r <= inStream_TID[ACC_BITS-1:0];
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
                acc_id <= twInfo_q0[TW_INFO_ACCID_L+ACC_BITS-1:TW_INFO_ACCID_L];
                state <= GET_ENTRY_2;
            end
            
            GET_ENTRY_2: begin
                if (!not_valid_entry_found && !tw_info_valid) begin
                    not_valid_idx <= prev_count;
                    not_valid_entry_found <= 1;
                end
                if (tw_info_valid && tw_info_task_id == task_id) begin
                    state <= CHECK_RESULTS;
                end else if (count == 0) begin
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
                    count <= not_valid_idx;
                end else begin
                    count <= prev_count;
                end
                update_entry <= 1;
                if (result_components == 0) begin
                    tw_info_valid <= 0;
                    state <= WAKEUP_ACC;
                end else begin
                    tw_info_valid <= 1;
                    state <= READ_HEADER;
                end
            end
            
            WAKEUP_ACC: begin
                if (outStream_TREADY) begin
                    state <= READ_HEADER;;
                end
            end
            
        endcase
        
        if (!ap_rst_n) begin
            state <= READ_HEADER;
        end
    end

endmodule
