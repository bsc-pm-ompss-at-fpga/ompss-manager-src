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

module Spawn_In(
    input  ap_clk,
    input  ap_rst_n,
    //SpawnInQueue memory
    output logic [31:0] SpawnInQueue_Addr_A,
    output SpawnInQueue_EN_A,
    output logic [7:0] SpawnInQueue_WEN_A,
    output [63:0] SpawnInQueue_Din_A,
    input [63:0] SpawnInQueue_Dout_A,
    output SpawnInQueue_Clk_A,
    output SpawnInQueue_Rst_A,
    //outStream
    output logic [63:0] outStream_TDATA,
    output logic outStream_TVALID,
    input outStream_TREADY,
    output logic outStream_TLAST,
    //picosFinishTask
    output reg [31:0] picosFinishTask_V_TDATA,
    output logic picosFinishTask_V_TVALID,
    input picosFinishTask_V_TREADY
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
    logic [9:0] spawnInQueue_addr;
    reg [63:0] pTask_id;
    reg spawnIn_valid;
    reg spawnIn_picos;
    
    assign SpawnInQueue_Addr_A = {19'd0, spawnInQueue_addr, 3'd0};
    assign SpawnInQueue_Clk_A = ap_clk;
    assign SpawnInQueue_Rst_A = 0;
    assign SpawnInQueue_Din_A[63:56] = 0;
    assign SpawnInQueue_EN_A = 1;
    
    assign next_rIdx = rIdx+1;
    
    always_comb begin
    

        SpawnInQueue_WEN_A = 0;
        spawnInQueue_addr = rIdx;
        
        outStream_TDATA = pTask_id;
        outStream_TVALID = 0;
        outStream_TLAST = 0;
        
        picosFinishTask_V_TVALID = 0;
    
        case (state)
        
            READ_HEADER: begin
                if (spawnIn_valid) begin
                    spawnInQueue_addr = next_rIdx;
                end
            end
            
            READ_TID_2: begin
                SpawnInQueue_WEN_A[7] = 1;
                spawnInQueue_addr = first_rIdx;
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
                picosFinishTask_V_TVALID = 1;
            end
        
        endcase
    
    end
    
    always_ff @(posedge ap_clk) begin
    
        spawnIn_valid <= SpawnInQueue_Dout_A[ENTRY_VALID_OFFSET];
        spawnIn_picos <= SpawnInQueue_Dout_A[62];
        
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
                picosFinishTask_V_TDATA <= SpawnInQueue_Dout_A[31:0];
                state <= READ_TID_2;
                rIdx <= next_rIdx;
            end
            
            READ_TID_2: begin
                pTask_id <= SpawnInQueue_Dout_A;
                if (!spawnIn_picos) begin
                    state <= NOTIFY_PICOS;
                end else begin
                    state <= NOTIFY_TW_1;
                end
            end
            
            NOTIFY_PICOS: begin
                if (picosFinishTask_V_TREADY) begin
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
    
        if (!ap_rst_n) begin
            rIdx <= 0;
            state <= START_LOOP_1;
        end
    
    end

endmodule
