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

module axis_switch_sv_int #(
    parameter NSLAVES = 2,
    parameter NMASTERS = 1,
    parameter DATA_WIDTH = 64,
    parameter HAS_ID = 0,
    parameter HAS_LAST = 0,
    parameter HAS_DEST = 0,
    parameter ID_WIDTH = 1,
    parameter DEST_WIDTH = 1,
    parameter DEST_BASE = 0,
    parameter DEST_STRIDE = 1,
    parameter DEST_RANGE = 0
) (
    input aclk,
    input aresetn,
    GenAxis.slave slaves[NSLAVES],
    GenAxis.master masters[NMASTERS]
);

    wire [NSLAVES-1:0] s_valid;
    wire [NSLAVES-1:0] s_ready;
    wire [NSLAVES*DATA_WIDTH-1:0] s_data;
    wire [NSLAVES*DEST_WIDTH-1:0] s_dest;
    wire [NSLAVES*ID_WIDTH-1:0] s_id;
    wire [NSLAVES-1:0] s_last;
    wire [NMASTERS-1:0] m_valid;
    wire [NMASTERS-1:0] m_ready;
    wire [NMASTERS*DATA_WIDTH-1:0] m_data;
    wire [NMASTERS*DEST_WIDTH-1:0] m_dest;
    wire [NMASTERS*ID_WIDTH-1:0] m_id;
    wire [NMASTERS-1:0] m_last;

    genvar i;
    for (i = 0; i < NSLAVES; i = i+1) begin
        assign s_valid[i] = slaves[i].valid;
        assign slaves[i].ready = s_ready[i];
        assign s_data[i*DATA_WIDTH +: DATA_WIDTH] = slaves[i].data;
        if (HAS_ID) begin
            assign s_id[i*ID_WIDTH +: ID_WIDTH] = slaves[i].id;
        end
        if (HAS_DEST) begin
            assign s_dest[i*DEST_WIDTH +: DEST_WIDTH] = slaves[i].dest;
        end
        if (HAS_LAST) begin
            assign s_last[i] = slaves[i].last;
        end
    end

    for (i = 0; i < NMASTERS; i = i+1) begin
        assign masters[i].valid = m_valid[i];
        assign m_ready[i] = masters[i].ready;
        assign masters[i].data = m_data[i*DATA_WIDTH +: DATA_WIDTH];
        if (HAS_ID)  begin
            assign masters[i].id = m_id[i*ID_WIDTH +: ID_WIDTH];
        end
        if (HAS_DEST) begin
            assign masters[i].dest = m_dest[i*DEST_WIDTH +: DEST_WIDTH];
        end
        if (HAS_LAST) begin
            assign masters[i].last = m_last[i];
        end
    end

    axis_switch_rrobin #(
        .NSLAVES(NSLAVES),
        .NMASTERS(NMASTERS),
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .HAS_ID(HAS_ID),
        .HAS_LAST(HAS_LAST),
        .HAS_DEST(HAS_DEST),
        .DEST_BASE(DEST_BASE),
        .DEST_STRIDE(DEST_STRIDE),
        .DEST_RANGE(DEST_RANGE)
    )
    switch (
        .*
    );

endmodule
