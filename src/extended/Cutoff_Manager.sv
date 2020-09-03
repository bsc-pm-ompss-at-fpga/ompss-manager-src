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

module Cutoff_Manager
(
    input clk,
    input aresetn,
    input picos_full,
    //inStream
    input ext_inStream_tvalid,
    output reg ext_inStream_tready,
    input [63:0] ext_inStream_tdata,
    input ext_inStream_tlast,
    input [3:0] ext_inStream_tid,
    input [4:0] ext_inStream_tdest,
    //Scheduler interface
    output sched_inStream_tvalid,
    input sched_inStream_tready,
    output [63:0] sched_inStream_tdata,
    output sched_inStream_tlast,
    output [3:0] sched_inStream_tid,
    //Picos interface
    output deps_new_task_tvalid,
    input deps_new_task_tready,
    output [63:0] deps_new_task_tdata,
    //Ack interface
    output ack_tvalid,
    input ack_tready,
    output logic [7:0] ack_tdata,
    output [3:0] ack_tdest,
    //Taskwait memory
    output reg [3:0] tw_info_addr,
    output logic tw_info_en,
    output logic tw_info_we,
    output logic [111:0] tw_info_din,
    input [111:0] tw_info_dout,
    output tw_info_clk
);

    import OmpSsManager::*;

    localparam ACC_BITS = $clog2(MAX_ACCS);
    localparam MAX_ADDR = TW_MEM_SIZE-1;

    localparam IDLE = 0;
    localparam SEARCH_ENTRY = 1;
    localparam SEARCH_FREE_ENTRY = 2;
    localparam CREATE_ENTRY = 3;
    localparam READ_PTID = 4;
    localparam READ_REST = 5;
    localparam BUF_FULL = 6;
    localparam BUF_EMPTY = 7;
    localparam ACK = 8;
    localparam WAIT_PICOS = 9;
    
    reg [3:0] state;
    
    reg[TW_MEM_BITS-1:0] tw_info_addr_delay;
    reg[ACC_BITS-1:0] acc_id;
    reg[63:0] buf_tdata;
    reg buf_tlast;
    reg[63:0] tid;
    reg first_task;
    reg accept;
    reg final_mode;
    reg deps_selected;
    wire selected_slave_tready;
    reg selected_slave_tvalid;
    reg empty_entry_found;
    reg [TW_MEM_BITS-1:0] empty_entry;
    
    assign tw_info_clk = clk;
    
    if (ACC_BITS != 4) begin
        assign sched_inStream_tid[3:ACC_BITS] = 0;
        assign ack_tdest[3:ACC_BITS] = 0;
    end
    
    if (TW_MEM_BITS != 4) begin
        assign tw_info_addr[3:TW_MEM_BITS] = 0;
    end
        
    assign ack_tvalid = state == ACK;
    assign ack_tdest[ACC_BITS-1:0] = acc_id;
    
    assign selected_slave_tready = deps_selected ? deps_new_task_tready : sched_inStream_tready;
    
    assign sched_inStream_tvalid = selected_slave_tvalid && !deps_selected;
    assign sched_inStream_tdata = buf_tdata;
    assign sched_inStream_tlast = buf_tlast;
    assign sched_inStream_tid = acc_id;
    assign deps_new_task_tvalid = selected_slave_tvalid && deps_selected;
    assign deps_new_task_tdata = buf_tdata;
    
    always @(*) begin
    
        tw_info_en = 0;
        tw_info_we = 0;
        
        tw_info_din = 0;
        tw_info_din[TW_INFO_VALID_ENTRY_B] = 1;
        tw_info_din[TW_INFO_ACCID_L+ACC_BITS-1:TW_INFO_ACCID_L] = acc_id;
        tw_info_din[TW_INFO_COMPONENTS_H:TW_INFO_COMPONENTS_L] = 0;
        tw_info_din[TW_INFO_TASKID_H:TW_INFO_TASKID_L] = tid;
        
        ack_tdata = ACK_REJECT_CODE;
        if (accept) begin
            ack_tdata = ACK_OK_CODE;
        end else if (final_mode) begin
            ack_tdata = ACK_FINAL_CODE;
        end
        
        ext_inStream_tready = 0;
        selected_slave_tvalid = 0;
        case (state)
        
            IDLE: begin
                ext_inStream_tready = 1;
            end
            
            READ_PTID: begin
                tw_info_en = 1;
            end
            
            SEARCH_FREE_ENTRY: begin
                tw_info_en = 1;
            end
            
            SEARCH_ENTRY: begin
                tw_info_en = 1;
            end
            
            CREATE_ENTRY: begin
                tw_info_en = 1;
                tw_info_we = 1;
            end
            
            READ_REST: begin
                ext_inStream_tready = 1;
            end
            
            BUF_FULL: begin
                selected_slave_tvalid = 1;
                if (selected_slave_tready && !buf_tlast) begin
                    ext_inStream_tready = 1;
                end else begin
                    ext_inStream_tready = 0;
                end
            end
            
            BUF_EMPTY: begin
                ext_inStream_tready = 1;
            end
            
        endcase
    end
    
    always @(posedge clk) begin
    
        tw_info_addr_delay <= tw_info_addr[TW_MEM_BITS-1:0];

        case (state)
        
            IDLE: begin
                tw_info_addr[TW_MEM_BITS-1:0] <= 0;
                empty_entry_found <= 0;
                acc_id <= ext_inStream_tid[ACC_BITS-1:0];
                deps_selected <= ext_inStream_tdest == HWR_DEPS_ID;
                buf_tdata <= ext_inStream_tdata;
                buf_tlast <= 0;
                if (ext_inStream_tdata[TASK_SEQ_ID_H:TASK_SEQ_ID_L] == 0) begin
                    first_task <= 1;
                end else begin
                    first_task <= 0;
                end
                if (ext_inStream_tvalid) begin
                    if (ext_inStream_tdata[TASK_SEQ_ID_H:TASK_SEQ_ID_L] == 0) begin
                        state <= READ_PTID;
                    end else if (ext_inStream_tdest == HWR_DEPS_ID && !picos_full && deps_new_task_tready) begin
                        state <= BUF_FULL;
                    end else if (ext_inStream_tdest == HWR_DEPS_ID && !deps_new_task_tready) begin
                        state <= WAIT_PICOS;
                    end else if (ext_inStream_tdest == HWR_DEPS_ID && picos_full) begin
                        state <= READ_PTID;
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end
            
            READ_PTID: begin
                tid <= ext_inStream_tdata;
                if (ext_inStream_tvalid) begin
                    tw_info_addr[TW_MEM_BITS-1:0] <= 1;
                    if (first_task) begin
                        state <= SEARCH_FREE_ENTRY;
                    end else begin
                        state <= SEARCH_ENTRY;
                    end
                end
            end
            
            SEARCH_FREE_ENTRY: begin
                final_mode <= 0;
                if (!tw_info_dout[TW_INFO_VALID_ENTRY_B] && !empty_entry_found) begin
                    empty_entry <= tw_info_addr_delay;
                    empty_entry_found <= 1;
                end
                if (tw_info_addr_delay == MAX_ADDR[TW_MEM_BITS-1:0]) begin
                    if (!tw_info_dout[TW_INFO_VALID_ENTRY_B] && !empty_entry_found) begin
                        tw_info_addr[TW_MEM_BITS-1:0] <= MAX_ADDR[TW_MEM_BITS-1:0];
                        state <= CREATE_ENTRY;
                    end else if (empty_entry_found) begin
                        tw_info_addr[TW_MEM_BITS-1:0] <= empty_entry;
                        state <= CREATE_ENTRY;
                    end else begin
                        state <= READ_REST;
                    end
                end else begin
                    tw_info_addr[TW_MEM_BITS-1:0] <= tw_info_addr[TW_MEM_BITS-1:0] + 1;
                end
                if (tw_info_dout[TW_INFO_VALID_ENTRY_B] && tw_info_dout[TW_INFO_TASKID_H:TW_INFO_TASKID_L] == tid) begin
                    if (deps_selected) begin
                        state <= WAIT_PICOS;
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end
            
            WAIT_PICOS: begin
                final_mode <= 1;
                if (deps_new_task_tready) begin
                    if (picos_full) begin
                        if (first_task) begin
                            state <= READ_REST;
                        end else begin
                            state <= READ_PTID;
                        end
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end
            
            CREATE_ENTRY: begin
                if (deps_selected) begin
                   state <= WAIT_PICOS;
                end else begin
                    state <= BUF_FULL;
                end
            end
            
            SEARCH_ENTRY: begin
                final_mode <= tw_info_dout[TW_INFO_COMPONENTS_H:TW_INFO_COMPONENTS_L] == buf_tdata[TASK_SEQ_ID_H:TASK_SEQ_ID_L];
                if (tw_info_din[TW_INFO_VALID_ENTRY_B] && tw_info_dout[TW_INFO_TASKID_H:TW_INFO_TASKID_L] == tid) begin
                    state <= READ_REST;
                end
                tw_info_addr[TW_MEM_BITS-1:0] <= tw_info_addr[TW_MEM_BITS-1:0] + 1;
            end
            
            READ_REST: begin
                accept <= 0;
                if (ext_inStream_tvalid && ext_inStream_tlast) begin
                    state <= ACK;
                end
            end
            
            BUF_FULL: begin
                accept <= 1;
                if (!ext_inStream_tvalid && selected_slave_tready && !buf_tlast) begin
                    state <= BUF_EMPTY;
                end else if (selected_slave_tready && buf_tlast) begin
                    if (deps_selected) begin
                        state <= ACK;
                    end else begin
                        state <= IDLE;
                    end
                end
                if (ext_inStream_tvalid && selected_slave_tready) begin
                    buf_tdata <= ext_inStream_tdata;
                    buf_tlast <= ext_inStream_tlast;
                end
            end
            
            BUF_EMPTY: begin
                buf_tdata <= ext_inStream_tdata;
                buf_tlast <= ext_inStream_tlast;
                if (ext_inStream_tvalid) begin
                    state <= BUF_FULL;
                end
            end
            
            ACK: begin
                if (ack_tready) begin
                    state <= IDLE;
                end
            end
            
        endcase
    
        if (!aresetn) begin
            state <= IDLE;
        end
    end

endmodule
