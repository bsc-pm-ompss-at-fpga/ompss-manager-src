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

module PicosOmpSsManager_wrapper #(
    parameter MAX_ACCS = 16,
    parameter MAX_ACC_CREATORS = 16,
    parameter MAX_ACC_TYPES = 16,
    parameter CMDIN_SUBQUEUE_LEN = 64,
    parameter CMDOUT_SUBQUEUE_LEN = 64,
    parameter SPAWNIN_QUEUE_LEN = 1024,
    parameter SPAWNOUT_QUEUE_LEN = 1024,
    parameter LOCK_SUPPORT = 0,
    parameter ENABLE_SPAWN_QUEUES = 0,
    parameter AXILITE_INTF = 0,
    parameter ENABLE_TASK_CREATION = 0,
    parameter DBG_AVAIL_COUNT_EN = 0,
    parameter DBG_AVAIL_COUNT_W = 1,
    //Scheduler parameters
    parameter [MAX_ACC_TYPES*8-1:0]  SCHED_COUNT = 0,
    parameter [MAX_ACC_TYPES*8-1:0]  SCHED_ACCID = 0,
    parameter [MAX_ACC_TYPES*32-1:0] SCHED_TTYPE = 0,
    //Picos parameters
    parameter MAX_ARGS_PER_TASK = 15,
    parameter MAX_DEPS_PER_TASK = 8,
    parameter MAX_COPS_PER_TASK = 15
) (
    //Clock and resets
    input  clk,
    input  rstn,
    //Taskwait request
    input  taskwait_in_tvalid,
    output taskwait_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] taskwait_in_tid,
    input  [63:0] taskwait_in_tdata,
    input  taskwait_in_tlast,
    //Taskwait ack
    output taskwait_out_tvalid,
    input  taskwait_out_tready,
    output [$clog2(MAX_ACCS)-1:0] taskwait_out_tdest,
    output [63:0] taskwait_out_tdata,
    output taskwait_out_tlast,
    //Task creation inStream
    input  spawn_in_tvalid,
    output spawn_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] spawn_in_tid,
    input  [63:0] spawn_in_tdata,
    input  spawn_in_tlast,
    //Task creation ack
    output spawn_out_tvalid,
    input  spawn_out_tready,
    output [$clog2(MAX_ACCS)-1:0] spawn_out_tdest,
    output [63:0] spawn_out_tdata,
    output spawn_out_tlast,
    //Lock request
    input  lock_in_tvalid,
    output lock_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] lock_in_tid,
    input  [63:0] lock_in_tdata,
    //Lock ack
    output lock_out_tvalid,
    input  lock_out_tready,
    output [$clog2(MAX_ACCS)-1:0] lock_out_tdest,
    output [63:0] lock_out_tdata,
    output lock_out_tlast,
    //inStream_CmdOut
    input  cmdout_in_tvalid,
    output cmdout_in_tready,
    input  [$clog2(MAX_ACCS)-1:0] cmdout_in_tid,
    input  [63:0] cmdout_in_tdata,
    //outStream_CmdIn
    output cmdin_out_tvalid,
    input  cmdin_out_tready,
    output [$clog2(MAX_ACCS)-1:0] cmdin_out_tdest,
    output [63:0] cmdin_out_tdata,
    output cmdin_out_tlast,
    //SpawnInQueue
    output spawnin_queue_clk,
    output spawnin_queue_rst,
    output spawnin_queue_en,
    output [7:0] spawnin_queue_we,
    output [31:0] spawnin_queue_addr,
    output [63:0] spawnin_queue_din,
    input  [63:0] spawnin_queue_dout,
    //SpawnOutQueue
    output spawnout_queue_clk,
    output spawnout_queue_rst,
    output spawnout_queue_en,
    output [7:0] spawnout_queue_we,
    output [31:0] spawnout_queue_addr,
    output [63:0] spawnout_queue_din,
    input  [63:0] spawnout_queue_dout,
    //CmdInQueue
    output cmdin_queue_clk,
    output cmdin_queue_rst,
    output cmdin_queue_en,
    output [7:0] cmdin_queue_we,
    output [31:0] cmdin_queue_addr,
    output [63:0] cmdin_queue_din,
    input  [63:0] cmdin_queue_dout,
    //CmdOutQueue
    output cmdout_queue_clk,
    output cmdout_queue_rst,
    output cmdout_queue_en,
    output [7:0] cmdout_queue_we,
    output [31:0] cmdout_queue_addr,
    output [63:0] cmdout_queue_din,
    input  [63:0] cmdout_queue_dout,
    //AXI Lite interface
    input axilite_arvalid,
    output axilite_arready,
    input [13:0] axilite_araddr,
    input [2:0] axilite_arprot,
    output axilite_rvalid,
    input axilite_rready,
    output [31:0] axilite_rdata,
    output [1:0] axilite_rresp
);
    PicosOmpSsManager #(
        .LOCK_SUPPORT(LOCK_SUPPORT),
        .SPAWNOUT_QUEUE_LEN(SPAWNOUT_QUEUE_LEN),
        .SPAWNIN_QUEUE_LEN(SPAWNIN_QUEUE_LEN),
        .CMDIN_SUBQUEUE_LEN(CMDIN_SUBQUEUE_LEN),
        .CMDOUT_SUBQUEUE_LEN(CMDOUT_SUBQUEUE_LEN),
        .MAX_ACC_TYPES(MAX_ACC_TYPES),
        .MAX_ACC_CREATORS(MAX_ACC_CREATORS),
        .MAX_ACCS(MAX_ACCS),
        .ENABLE_SPAWN_QUEUES(ENABLE_SPAWN_QUEUES),
        .AXILITE_INTF(AXILITE_INTF),
        .ENABLE_TASK_CREATION(ENABLE_TASK_CREATION),
        .DBG_AVAIL_COUNT_EN(DBG_AVAIL_COUNT_EN),
        .DBG_AVAIL_COUNT_W(DBG_AVAIL_COUNT_W),
        .SCHED_COUNT(SCHED_COUNT),
        .SCHED_ACCID(SCHED_ACCID),
        .SCHED_TTYPE(SCHED_TTYPE),
        .MAX_ARGS_PER_TASK(MAX_ARGS_PER_TASK),
        .MAX_DEPS_PER_TASK(MAX_DEPS_PER_TASK),
        .MAX_COPS_PER_TASK(MAX_COPS_PER_TASK)
    ) PicosOmpSsManager_I (
        .clk(clk),
        .rstn(rstn),
        .cmdin_queue_addr(cmdin_queue_addr),
        .cmdin_queue_clk(cmdin_queue_clk),
        .cmdin_queue_din(cmdin_queue_din),
        .cmdin_queue_dout(cmdin_queue_dout),
        .cmdin_queue_en(cmdin_queue_en),
        .cmdin_queue_rst(cmdin_queue_rst),
        .cmdin_queue_we(cmdin_queue_we),
        .cmdout_queue_addr(cmdout_queue_addr),
        .cmdout_queue_clk(cmdout_queue_clk),
        .cmdout_queue_din(cmdout_queue_din),
        .cmdout_queue_dout(cmdout_queue_dout),
        .cmdout_queue_en(cmdout_queue_en),
        .cmdout_queue_rst(cmdout_queue_rst),
        .cmdout_queue_we(cmdout_queue_we),
        .cmdout_in_tdata(cmdout_in_tdata),
        .cmdout_in_tid(cmdout_in_tid),
        .cmdout_in_tready(cmdout_in_tready),
        .cmdout_in_tvalid(cmdout_in_tvalid),
        .spawn_in_tdata(spawn_in_tdata),
        .spawn_in_tid(spawn_in_tid),
        .spawn_in_tlast(spawn_in_tlast),
        .spawn_in_tready(spawn_in_tready),
        .spawn_in_tvalid(spawn_in_tvalid),
        .lock_out_tdata(lock_out_tdata),
        .lock_out_tdest(lock_out_tdest),
        .lock_out_tlast(lock_out_tlast),
        .lock_out_tready(lock_out_tready),
        .lock_out_tvalid(lock_out_tvalid),
        .lock_in_tdata(lock_in_tdata),
        .lock_in_tid(lock_in_tid),
        .lock_in_tready(lock_in_tready),
        .lock_in_tvalid(lock_in_tvalid),
        .cmdin_out_tdata(cmdin_out_tdata),
        .cmdin_out_tdest(cmdin_out_tdest),
        .cmdin_out_tlast(cmdin_out_tlast),
        .cmdin_out_tready(cmdin_out_tready),
        .cmdin_out_tvalid(cmdin_out_tvalid),
        .spawnin_queue_addr(spawnin_queue_addr),
        .spawnin_queue_clk(spawnin_queue_clk),
        .spawnin_queue_din(spawnin_queue_din),
        .spawnin_queue_dout(spawnin_queue_dout),
        .spawnin_queue_en(spawnin_queue_en),
        .spawnin_queue_rst(spawnin_queue_rst),
        .spawnin_queue_we(spawnin_queue_we),
        .spawnout_queue_addr(spawnout_queue_addr),
        .spawnout_queue_clk(spawnout_queue_clk),
        .spawnout_queue_din(spawnout_queue_din),
        .spawnout_queue_dout(spawnout_queue_dout),
        .spawnout_queue_en(spawnout_queue_en),
        .spawnout_queue_rst(spawnout_queue_rst),
        .spawnout_queue_we(spawnout_queue_we),
        .taskwait_out_tdata(taskwait_out_tdata),
        .taskwait_out_tdest(taskwait_out_tdest),
        .taskwait_out_tlast(taskwait_out_tlast),
        .taskwait_out_tready(taskwait_out_tready),
        .taskwait_out_tvalid(taskwait_out_tvalid),
        .taskwait_in_tdata(taskwait_in_tdata),
        .taskwait_in_tid(taskwait_in_tid),
        .taskwait_in_tlast(taskwait_in_tlast),
        .taskwait_in_tready(taskwait_in_tready),
        .taskwait_in_tvalid(taskwait_in_tvalid),
        .spawn_out_tdata(spawn_out_tdata),
        .spawn_out_tdest(spawn_out_tdest),
        .spawn_out_tlast(spawn_out_tlast),
        .spawn_out_tready(spawn_out_tready),
        .spawn_out_tvalid(spawn_out_tvalid),
        .axilite_arvalid(axilite_arvalid),
        .axilite_arready(axilite_arready),
        .axilite_araddr(axilite_araddr),
        .axilite_arprot(axilite_arprot),
        .axilite_rvalid(axilite_rvalid),
        .axilite_rready(axilite_rready),
        .axilite_rdata(axilite_rdata),
        .axilite_rresp(axilite_rresp)
    );
endmodule
