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

module axis_switch_single_master_rrobin #(
    parameter NSLAVES = 2,
    parameter DATA_WIDTH = 64,
    parameter DEST_WIDTH = 1,
    parameter ID_WIDTH = 1,
    parameter HAS_ID = 0,
    parameter HAS_LAST = 0,
    parameter HAS_DEST = 0
) (
    input aclk,
    input aresetn,
    input  logic [NSLAVES-1:0] s_valid,
    output logic [NSLAVES-1:0] s_ready,
    input  logic [NSLAVES*DATA_WIDTH-1:0] s_data,
    input  logic [NSLAVES*DEST_WIDTH-1:0] s_dest,
    input  logic [NSLAVES*ID_WIDTH-1:0] s_id,
    input  logic [NSLAVES-1:0] s_last,
    output logic m_valid,
    input  logic m_ready,
    output logic [DATA_WIDTH-1:0] m_data,
    output logic [DEST_WIDTH-1:0] m_dest,
    output logic [ID_WIDTH-1:0] m_id,
    output logic m_last
);

    if (NSLAVES == 1) begin

        assign m_valid = s_valid[0];
        assign s_ready[0] = m_ready;
        assign m_data = s_data;
        if (HAS_DEST) begin
            assign m_dest = s_dest;
        end
        if (HAS_LAST) begin
            assign m_last = s_last;
        end
        if (HAS_ID) begin
            assign m_id = s_id;
        end

    end else begin

    typedef enum bit [0:0] {
        IDLE,
        TRANSACTION
    } State_t;

    State_t state;

    localparam SEL_SLAVE_BITS = $clog2(NSLAVES+1);
    localparam NONE_SEL_VAL = {SEL_SLAVE_BITS{1'b1}};

    reg[SEL_SLAVE_BITS-1:0] sel_slave;
    int slave_priority;

    genvar i;

    for (i = 0; i < NSLAVES; i = i+1) begin : SLAVES_READY_SIGNAL
        always_comb begin
            if (sel_slave == i) begin
                s_ready[i] = m_ready;
            end else begin
                s_ready[i] = 0;
            end
        end
    end

    always_comb begin
        int j1, j2;
        m_data = s_data[DATA_WIDTH-1 : 0];
        if (HAS_DEST) begin
            m_dest = s_dest[DEST_WIDTH-1 : 0];
        end
        if (HAS_LAST) begin
            m_last = s_last[0];
        end
        if (HAS_ID) begin
            m_id = s_id[ID_WIDTH-1:0];
        end
        m_valid = 0;
        for (j1 = 0; j1 < NSLAVES; j1 = j1+1) begin
            if (sel_slave == j1) begin
                m_valid = s_valid[j1];
            end
        end
        for (j2 = 1; j2 < NSLAVES; j2 = j2+1) begin
            if (sel_slave == j2) begin
                m_data = s_data[j2*DATA_WIDTH +: DATA_WIDTH];
                if (HAS_DEST) begin
                    m_dest = s_dest[j2*DEST_WIDTH +: DEST_WIDTH];
                end
                if (HAS_LAST) begin
                    m_last = s_last[j2];
                end
                if (HAS_ID) begin
                    m_id = s_id[j2*ID_WIDTH +: ID_WIDTH];
                end
            end
        end
    end

    always_ff @(posedge aclk) begin

        case (state)

            IDLE: begin
                int j;
                for (j = 0; j < NSLAVES; j = j+1) begin
                    if (s_valid[(j + slave_priority)%NSLAVES]) begin
                        sel_slave <= (j + slave_priority)%NSLAVES;
                        state <= TRANSACTION;
                        slave_priority <= slave_priority + 1;
                        break;
                    end
                end
            end

            TRANSACTION: begin
                if (!HAS_LAST) begin
                    if (m_ready) begin
                        state <= IDLE;
                        sel_slave <= NONE_SEL_VAL;
                    end
                end else begin
                    int j;
                    for (j = 0; j < NSLAVES; j = j+1) begin
                        if (sel_slave == j && s_last[j] && s_valid[j] && m_ready) begin
                            state <= IDLE;
                            sel_slave <= NONE_SEL_VAL;
                        end
                    end
                end
            end

        endcase

        if (!aresetn) begin
            int i;
            slave_priority[i] <= 0;
            state <= IDLE;
            sel_slave <= NONE_SEL_VAL;
        end
    end

    end

endmodule
