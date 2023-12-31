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


module Scheduler_spawnout #(
    parameter QUEUE_LEN = 1024,
    parameter QUEUE_BITS = $clog2(QUEUE_LEN),
    parameter TASKTYPE_BITS = 32,
    parameter ARCHBITS_BITS = 2
) (
    input  clk,
    input  rstn,
    //Spawn out queue
    output logic [31:0] spawnout_queue_addr,
    output logic spawnout_queue_en,
    output logic [7:0] spawnout_queue_we,
    output logic [63:0] spawnout_queue_din,
    input [63:0] spawnout_queue_dout,
    //inStream
    input  inStream_TVALID,
    output logic inStream_spawnout_TREADY,
    //Other signals
    input [63:0] taskID,
    input [63:0] pTaskID,
    input [ARCHBITS_BITS-1:0] task_arch,
    input [TASKTYPE_BITS-1:0] task_type,
    input [3:0] num_args,
    input [3:0] num_cops,
    input [3:0] num_deps,
    input [63:0] inStream_data_buf,
    input inStream_last_buf,
    input spawnout_state_start,
    output reg [1:0] spawnout_ret //0 wait, 1 ok, 2 reject
);

    assign spawnout_queue_addr = 32'hDEADBEEF;
    assign spawnout_queue_en = 0;
    assign spawnout_queue_we = 8'h00;
    assign spawnout_queue_din = 64'hDDEEAADDBBEEFF;
    assign inStream_spawnout_TREADY = 0;
    assign spawnout_ret = 2;

endmodule

module Scheduler_tb;
    localparam MAX_ACCS = 30;
    localparam ACC_BITS = 5; //$clog2(MAX_ACCS);
    localparam SUBQUEUE_LEN = 64;
    localparam SUBQUEUE_BITS = 6; //$clog2(SUBQUEUE_LEN);
    localparam MAX_ACC_TYPES = 3;
    localparam SPAWNOUT_QUEUE_LEN = 1024;
    localparam SCHED_DATA_BITS = 48;
    localparam [MAX_ACC_TYPES*8-1:0] SCHED_COUNT = 24'h000203;
    localparam [MAX_ACC_TYPES*8-1:0] SCHED_ACCID = 24'h070400;
    localparam [MAX_ACC_TYPES*32-1:0] SCHED_TTYPE = 96'h000000003334433312344321;

    import OmpSsManager::*;

    logic clk;
    logic rstn;
    //Internal command queue
    logic [SUBQUEUE_BITS+ACC_BITS-1:0] intCmdInQueue_addr;
    logic intCmdInQueue_en;
    logic intCmdInQueue_we;
    logic [63:0] intCmdInQueue_din;
    logic [63:0] intCmdInQueue_dout;
    logic intCmdInQueue_clk;
    //Spawn out queue
    logic [31:0] spawnout_queue_addr;
    logic spawnout_queue_en;
    logic [7:0] spawnout_queue_we;
    logic [63:0] spawnout_queue_din;
    logic [63:0] spawnout_queue_dout;
    logic spawnout_queue_clk;
    logic spawnout_queue_rst;
    //inStream
    logic [63:0] inStream_TDATA;
    logic inStream_TVALID;
    logic inStream_TREADY;
    logic [ACC_BITS-1:0] inStream_TID;
    logic inStream_TLAST;
    //outStream
    logic [63:0] outStream_TDATA;
    logic outStream_TVALID;
    logic outStream_TREADY;
    logic outStream_TLAST;
    logic [ACC_BITS-1:0] outStream_TDEST;
    //Picos reject interface
    logic [31:0] picosRejectTask_id;
    logic picosRejectTask_valid;
    //Queue not empty interface
    logic [ACC_BITS-1:0] sched_queue_nempty_address;
    logic sched_queue_nempty_write;

    Scheduler #(
        .MAX_ACCS(MAX_ACCS),
        .ACC_BITS(ACC_BITS),
        .SUBQUEUE_LEN(SUBQUEUE_LEN),
        .SUBQUEUE_BITS(SUBQUEUE_BITS),
        .MAX_ACC_TYPES(MAX_ACC_TYPES),
        .SPAWNOUT_QUEUE_LEN(SPAWNOUT_QUEUE_LEN),
        .SCHED_COUNT(SCHED_COUNT),
        .SCHED_ACCID(SCHED_ACCID),
        .SCHED_TTYPE(SCHED_TTYPE)
    ) dut (
        .*
    );

    initial begin
        $write("===== Starting test execution =====\n");
        rstn <= 0; //< Start reset
        #10;
        inStream_TVALID <= 0;
        outStream_TREADY <= 0;
        spawnout_queue_dout <= 64'hDDEEAADDBBEEFF;
        rstn <= 1; //< End reset
        repeat (1) @(posedge clk);

        // Check initial values
        assert(intCmdInQueue_en == 0) else $error("intCmdInQueue_en != 0 after reset");
        assert(intCmdInQueue_we == 0) else $error("intCmdInQueue_we != 0 after reset");
        //assert(spawnout_queue_en == 0) else $error("spawnout_queue_en != 0 after reset");
        //assert(spawnout_queue_we == 0) else $error("spawnout_queue_we != 0 after reset");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 after reset");
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reset");
        repeat (2) @(posedge clk);
        assert(intCmdInQueue_en == 0) else $error("intCmdInQueue_en != 0 after reset");
        assert(intCmdInQueue_we == 0) else $error("intCmdInQueue_we != 0 after reset");
        //assert(spawnout_queue_en == 0) else $error("spawnout_queue_en != 0 after reset");
        //assert(spawnout_queue_we == 0) else $error("spawnout_queue_we != 0 after reset");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 after reset");
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reset");

        //Create task with 0 args, 0 deps, 0 copies for any instance
        $write("Test 1: Create task 0 args, 0 deps, 0 copies, type 0x112344321, any instance\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 1.0: inStream_TREADY != 1");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 1.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 1.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000123456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 1.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 1.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000FF0112344321; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 1.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 1.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (4) @(posedge clk);
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 1.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 1.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 1.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h001) else $error("Test 1.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 1.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 1.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 1.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 1.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h002) else $error("Test 1.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000123456789) else $error("Test 1.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 1.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 1.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h000) else $error("Test 1.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 1.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 1.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 1.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 1.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 1.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 1.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 1.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 0) else $error("Test 1.11: outStream_TDEST != 0");
        assert(outStream_TDATA == 1) else $error("Test 1.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 1.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for any instance
        $write("Test 2: Create task 0 args, 0 deps, 0 copies, type 0x112344321, any instance\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 2.0: inStream_TREADY != 1");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 2.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 2.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000123456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 2.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 2.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000FF0112344321; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 2.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 2.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (4) @(posedge clk);
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 2.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 2.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 2.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h041) else $error("Test 2.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 2.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 2.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 2.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 2.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h042) else $error("Test 2.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000123456789) else $error("Test 2.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 2.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 2.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h040) else $error("Test 2.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 2.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 2.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 2.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 2.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 2.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 2.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 2.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 0) else $error("Test 2.11: outStream_TDEST != 0");
        assert(outStream_TDATA == 1) else $error("Test 2.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 2.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for any instance
        $write("Test 3: Create task 0 args, 0 deps, 0 copies, type 0x112344321, any instance\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 3.0: inStream_TREADY != 1");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 3.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 3.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000123456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 3.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 3.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000FF0112344321; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 3.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 3.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (4) @(posedge clk);
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 3.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 3.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 3.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h081) else $error("Test 3.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 3.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 3.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 3.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 3.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h082) else $error("Test 3.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000123456789) else $error("Test 3.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 3.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 3.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h080) else $error("Test 3.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 3.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 3.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 3.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 3.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 3.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 3.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 3.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 0) else $error("Test 3.11: outStream_TDEST != 0");
        assert(outStream_TDATA == 1) else $error("Test 3.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 3.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies, SMP+FPGA arch, any instance
        $write("Test 4: Create task 0 args, 0 deps, 0 copies, type 0x312344321 (SMP+FPGA), any instance\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 4.0: inStream_TREADY != 1");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 4.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 4.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000123456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 4.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 4.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000FF0312344321; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 4.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 4.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (4) @(posedge clk);
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 4.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 4.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 4.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h0C1) else $error("Test 4.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 4.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 4.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 4.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 4.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h0C2) else $error("Test 4.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000123456789) else $error("Test 4.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 4.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 4.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h0C0) else $error("Test 4.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 4.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 4.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 4.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 4.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 4.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 4.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 4.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 0) else $error("Test 4.11: outStream_TDEST != 0");
        assert(outStream_TDATA == 1) else $error("Test 4.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 4.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for any instance
        $write("Test 5: Create task 0 args, 0 deps, 0 copies, type 0x112344321, any instance\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 5.0: inStream_TREADY != 1");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 5.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 5.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000123456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 5.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 5.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000FF0112344321; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 5.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 5.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (4) @(posedge clk);
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 5.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 5.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 5.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h004) else $error("Test 5.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 5.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 5.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 5.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 5.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h005) else $error("Test 5.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000123456789) else $error("Test 5.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 5.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 5.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h003) else $error("Test 5.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 5.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 5.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 5.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 5.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 5.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 5.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 5.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 0) else $error("Test 5.11: outStream_TDEST != 0");
        assert(outStream_TDATA == 1) else $error("Test 5.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 5.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for instance 2
        $write("Test 6: Create task 0 args, 0 deps, 0 copies, type 0x112344321, instance 2\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 6.0: inStream_TREADY != 1");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 6.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 6.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000123456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 6.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 6.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000020112344321; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 6.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 6.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (4) @(posedge clk);
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 6.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 6.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 6.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h084) else $error("Test 6.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 6.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 6.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 6.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 6.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h085) else $error("Test 6.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000123456789) else $error("Test 6.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 6.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 6.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h083) else $error("Test 6.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 6.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 6.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 6.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 6.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 6.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 6.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 6.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 0) else $error("Test 6.11: outStream_TDEST != 0");
        assert(outStream_TDATA == 1) else $error("Test 6.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 6.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for instance 1
        $write("Test 7: Create task 0 args, 0 deps, 0 copies, type 0x133344333, instance 1\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 7.0: inStream_TREADY != 1");
        inStream_TID <= 1;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 7.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 7.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000223456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 7.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 7.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000010133344333; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 7.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 7.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (5) @(posedge clk); //NOTE: The number of cycles may change based on type entry
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 7.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 7.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 7.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h141) else $error("Test 7.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 7.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 7.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 7.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 7.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h142) else $error("Test 7.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000223456789) else $error("Test 7.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 7.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 7.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h140) else $error("Test 7.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 7.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 7.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 7.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 7.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 7.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 7.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 7.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 1) else $error("Test 7.11: outStream_TDEST != 1");
        assert(outStream_TDATA == 1) else $error("Test 7.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 7.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for instance 0
        $write("Test 8: Create task 0 args, 0 deps, 0 copies, type 0x133344333, instance 0\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 8.0: inStream_TREADY != 1");
        inStream_TID <= 1;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 8.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 8.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000223456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 8.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 8.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000133344333; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 8.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 8.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (5) @(posedge clk); //NOTE: The number of cycles may change based on type entry
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 8.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 8.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 8.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h101) else $error("Test 8.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 8.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 8.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 8.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 8.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h102) else $error("Test 8.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000223456789) else $error("Test 8.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 8.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 8.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h100) else $error("Test 8.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 8.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 8.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 8.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 8.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 8.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 8.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 8.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 1) else $error("Test 8.11: outStream_TDEST != 1");
        assert(outStream_TDATA == 1) else $error("Test 8.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 8.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies for instance 0
        $write("Test 9: Create task 0 args, 0 deps, 0 copies, type 0x133344333, instance 0\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 9.0: inStream_TREADY != 1");
        inStream_TID <= 1;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 9.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 9.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000223456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 9.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 9.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000133344333; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 9.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 9.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (5) @(posedge clk); //NOTE: The number of cycles may change based on type entry
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 9.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 9.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 9.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h104) else $error("Test 9.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 9.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 9.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 9.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 9.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h105) else $error("Test 9.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000223456789) else $error("Test 9.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 9.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 9.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h103) else $error("Test 9.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 9.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 9.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 9.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 9.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 9.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 9.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 9.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 1) else $error("Test 9.11: outStream_TDEST != 1");
        assert(outStream_TDATA == 1) else $error("Test 9.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 9.13: outStream_TVALID != 0");

        //Create task with 0 args, 0 deps, 0 copies, arch SMP+FPGA, instance 2
        $write("Test 10: Create task 0 args, 0 deps, 0 copies, type 0x333344333 (SMP+FPGA), instance 2\n");
        //SCHED_READ_HEADER_1
        assert(inStream_TREADY == 1) else $error("Test 10.0: inStream_TREADY != 1");
        inStream_TID <= 1;
        inStream_TDATA <= 64'h0000000000000000; //Task number + #Cpys + #Deps + #Args + 0
        inStream_TVALID <= 1;
        inStream_TLAST <= 0;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        assert(inStream_TREADY == 1) else $error("Test 10.2: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 10.2: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000000223456789; //Parent Task Identifier
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_1
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(inStream_TREADY == 1) else $error("Test 10.4: inStream_TREADY != 1");
        assert(outStream_TVALID == 0) else $error("Test 10.4: outStream_TVALID != 0");
        inStream_TVALID <= 1;
        inStream_TDATA <= 64'h0000020333344333; //Instance number + type hash
        inStream_TLAST <= 1;
        repeat (1) @(posedge clk);
        //SCHED_READ_HEADER_OTHER_2
        assert(intCmdInQueue_en == 0) else $error("Test 10.5: intCmdInQueue_en != 0");
        assert(outStream_TVALID == 0) else $error("Test 10.5: outStream_TVALID != 0");
        inStream_TVALID <= 0;
        repeat (5) @(posedge clk); //NOTE: The number of cycles may change based on type entry
        //SCHED_CMDIN_CHECK
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_1 taskId
        assert(outStream_TVALID == 0) else $error("Test 10.7: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 10.7: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 10.7: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h181) else $error("Test 10.7: intCmdInQueue_addr");
        //assert(intCmdInQueue_din == 64'h) else $error("Test 10.4: intCmdInQueue_din != 0xFF");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_2 parentTaskId
        assert(outStream_TVALID == 0) else $error("Test 10.8: outStream_TVALID != 0");
        assert(intCmdInQueue_en == 1) else $error("Test 10.8: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 10.8: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h182) else $error("Test 10.8: intCmdInQueue_addr");
        assert(intCmdInQueue_din == 64'h0000000223456789) else $error("Test 10.8: intCmdInQueue_din");
        repeat (1) @(posedge clk);
        //SCHED_CMDIN_WRITE_4 header
        assert(intCmdInQueue_en == 1) else $error("Test 10.9: intCmdInQueue_en != 1");
        assert(intCmdInQueue_we == 1) else $error("Test 10.9: intCmdInQueue_we != 1");
        assert(intCmdInQueue_addr == 10'h180) else $error("Test 10.9: intCmdInQueue_addr");
        assert(intCmdInQueue_din[ENTRY_VALID_OFFSET] == 1'h1) else $error("Test 10.9: intCmdInQueue_din.valid");
        assert(intCmdInQueue_din[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else $error("Test 10.9: intCmdInQueue_din.destID");
        assert(intCmdInQueue_din[COMPF_H:COMPF_L] == 8'h01) else $error("Test 10.9: intCmdInQueue_din.comF");
        assert(intCmdInQueue_din[NUM_ARGS_OFFSET +: 8] == 8'h00) else $error("Test 10.9: intCmdInQueue_din.#Args");
        assert(intCmdInQueue_din[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE_BYTE) else $error("Test 10.9: intCmdInQueue_din.CmdCode");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("Test 10.11: outStream_TVALID != 1");
        assert(outStream_TLAST == 1) else $error("Test 10.11: outStream_TLAST != 1");
        assert(outStream_TDEST == 1) else $error("Test 10.11: outStream_TDEST != 1");
        assert(outStream_TDATA == 1) else $error("Test 10.11: outStream_TDATA != 1");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("Test 10.13: outStream_TVALID != 0");

        $write("===== End of test execution =====\n");
    end

    always begin
        clk <= 1; #5;
        clk <= 0; #5;
    end

endmodule
