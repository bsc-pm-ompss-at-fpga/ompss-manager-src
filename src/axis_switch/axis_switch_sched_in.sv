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

module axis_switch_sched_in #(
    parameter ID_WIDTH = 0,
    localparam DATA_WIDTH = 64
) (
    input clk,
    input rstn,
    input  S00_AXIS_tvalid,
    output S00_AXIS_tready,
    input  [DATA_WIDTH-1:0] S00_AXIS_tdata,
    input  [ID_WIDTH-1:0]   S00_AXIS_tid,
    input  S00_AXIS_tlast,
    input  S01_AXIS_tvalid,
    output S01_AXIS_tready,
    input  [DATA_WIDTH-1:0] S01_AXIS_tdata,
    input  [ID_WIDTH-1:0]   S01_AXIS_tid,
    input  S01_AXIS_tlast,
    output M00_AXIS_tvalid,
    input  M00_AXIS_tready,
    output [DATA_WIDTH-1:0] M00_AXIS_tdata,
    output [ID_WIDTH-1:0]   M00_AXIS_tid,
    output M00_AXIS_tlast
);

    localparam NSLAVES = 1;
    localparam NMASTERS = 1;

    wire [NSLAVES-1:0] s_valid;
    wire [NSLAVES-1:0] s_ready;
    wire [NSLAVES*DATA_WIDTH-1:0] s_data;
    wire [NSLAVES*ID_WIDTH-1:0] s_id;
    wire [NSLAVES-1:0] s_last;
    wire [NMASTERS-1:0] m_valid;
    wire [NMASTERS-1:0] m_ready;
    wire [NMASTERS*DATA_WIDTH-1:0] m_data;
    wire [NMASTERS*ID_WIDTH-1:0] m_id;
    wire [NMASTERS-1:0] m_last;

    assign s_valid[0] = S00_AXIS_tvalid;
    assign S00_AXIS_tready = s_ready[0];
    assign s_data[DATA_WIDTH*0 +: DATA_WIDTH] = S00_AXIS_tdata;
    assign s_id[ID_WIDTH*0 +: ID_WIDTH] = S00_AXIS_tid;
    assign s_last[0] = S00_AXIS_tlast;

	assign S01_AXIS_tready = 1'b0;

    assign M00_AXIS_tvalid = m_valid[0];
    assign m_ready[0] = M00_AXIS_tready;
    assign M00_AXIS_tdata = m_data[DATA_WIDTH*0 +: DATA_WIDTH];
    assign M00_AXIS_tid = m_id[ID_WIDTH*0 +: ID_WIDTH];
    assign M00_AXIS_tlast = m_last[0];

    axis_switch #(
        .NSLAVES(NSLAVES),
        .NMASTERS(NMASTERS),
        .REG_PIPELINE_DEPTH(0),
        .SINGLE_ST(0),
        .DATA_WIDTH(DATA_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .HAS_ID(1),
        .HAS_LAST(1),
        .HAS_DEST(0)
    )
    switch (
        .aclk(clk),
        .aresetn(rstn),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_dest('0),
        .s_id(s_id),
        .s_last(s_last),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data),
        .m_dest(),
        .m_id(m_id),
        .m_last(m_last)
    );

endmodule
