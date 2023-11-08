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

module axilite_controller #(
    parameter AXI_ADDR_WIDTH = 0,
    parameter MAX_ACCS = 0,
    parameter DBG_AVAIL_COUNT_W = 0
) (
    input clk,
    input rstn,
    input axilite_arvalid,
    output axilite_arready,
    input [AXI_ADDR_WIDTH-1:0] axilite_araddr,
    input [2:0] axilite_arprot,
    output axilite_rvalid,
    input axilite_rready,
    output [31:0] axilite_rdata,
    output [1:0] axilite_rresp,
    input [DBG_AVAIL_COUNT_W-1:0] dbg_avail_count[MAX_ACCS],
    input OmpSsManager::DbgRegs_t dbg_regs,
    input [MAX_ACCS-1:0] dbg_acc_avail,
    input [MAX_ACCS-1:0] dbg_queue_nempty,
    input [31:0] cmd_in_n_cmds[MAX_ACCS],
    input [31:0] cmd_out_n_cmds[MAX_ACCS]
);

    localparam CMD_IN_N_CMDS_START_ADDR = 'h800;
    localparam CMD_IN_N_CMDS_LEN = MAX_ACCS < 64 ? MAX_ACCS*4 : 256; //64 accs * 4 bytes per acc
    localparam CMD_IN_N_CMDS_END_ADDR = CMD_IN_N_CMDS_START_ADDR + CMD_IN_N_CMDS_LEN;

    localparam CMD_OUT_N_CMDS_START_ADDR = 'h900; //0x800 + 256
    localparam CMD_OUT_N_CMDS_LEN = MAX_ACCS < 64 ? MAX_ACCS*4 : 256; //64 accs * 4 bytes per acc
    localparam CMD_OUT_N_CMDS_END_ADDR = CMD_OUT_N_CMDS_START_ADDR + CMD_OUT_N_CMDS_LEN;

    localparam AVAIL_COUNT_START_ADDR = 'hA00;
    localparam AVAIL_COUNT_LEN = MAX_ACCS < 32 ? MAX_ACCS*8 : 256;
    localparam AVAIL_COUNT_END_ADDR  = AVAIL_COUNT_START_ADDR + AVAIL_COUNT_LEN;

    typedef enum bit [1:0] {
       AR,
       SELECT_REG_1,
       SELECT_REG_2,
       R 
    } RState_t;

    RState_t rstate;

    reg [AXI_ADDR_WIDTH-1:0] raddr;
    reg [31:0] rdata;
    reg [1:0] rresp;
    reg [31:0] cmd_in_select;
    reg [31:0] cmd_out_select;
    reg [DBG_AVAIL_COUNT_W-1:0] avail_count_select;
    wire [31:0] avail_count_select_low;
    wire [31:0] avail_count_select_high;
    wire [31:0] dbg_acc_avail_low;
    wire [31:0] dbg_acc_avail_high;
    wire [31:0] dbg_queue_nempty_low;
    wire [31:0] dbg_queue_nempty_high;

    if (MAX_ACCS < 32) begin
        assign dbg_acc_avail_low = {{32-MAX_ACCS{1'b0}}, dbg_acc_avail};
        assign dbg_queue_nempty_low = {{32-MAX_ACCS{1'b0}}, dbg_queue_nempty};
    end else begin
        assign dbg_acc_avail_low = dbg_acc_avail[31:0];
        assign dbg_queue_nempty_low = dbg_queue_nempty[31:0];
    end

    if (MAX_ACCS <= 32) begin
        assign dbg_acc_avail_high = 32'd0;
        assign dbg_queue_nempty_high = 32'd0;
    end else if (MAX_ACCS < 64) begin
        assign dbg_acc_avail_high = {{64-MAX_ACCS{1'b0}}, dbg_acc_avail[MAX_ACCS-1:32]};
        assign dbg_queue_nempty_high = {{64-MAX_ACCS{1'b0}}, dbg_queue_nempty[MAX_ACCS-1:32]};
    end else begin
        assign dbg_acc_avail_high = dbg_acc_avail[63:32];
        assign dbg_queue_nempty_high = dbg_queue_nempty[63:32];
    end

    if (DBG_AVAIL_COUNT_W < 32) begin
        assign avail_count_select_low = {{32-DBG_AVAIL_COUNT_W{1'b0}}, avail_count_select};
        assign avail_count_select_high = 32'd0;
    end else if (DBG_AVAIL_COUNT_W == 32) begin
        assign avail_count_select_low = avail_count_select;
        assign avail_count_select_high = 32'd0;
    end else if (DBG_AVAIL_COUNT_W < 64) begin
        assign avail_count_select_low = avail_count_select[31:0];
        assign avail_count_select_high = {{64-DBG_AVAIL_COUNT_W{1'b0}}, avail_count_select[DBG_AVAIL_COUNT_W-1:32]};
    end else begin
        assign avail_count_select_low = avail_count_select[31:0];
        assign avail_count_select_high = avail_count_select[63:32];
    end

    assign axilite_arready = rstate == AR;
    assign axilite_rvalid = rstate == R;
    assign axilite_rdata = rdata;
    assign axilite_rresp = rresp;

    always_ff @(posedge clk) begin

        case (rstate)

            AR: begin
                raddr <= axilite_araddr[AXI_ADDR_WIDTH-1:0];
                if (axilite_arvalid) begin
                    rstate <= SELECT_REG_1;
                end
            end

            SELECT_REG_1: begin
                rresp <= 2'b00;
                cmd_in_select <= cmd_in_n_cmds[(raddr-CMD_IN_N_CMDS_START_ADDR)/4];
                cmd_out_select <= cmd_out_n_cmds[(raddr-CMD_OUT_N_CMDS_START_ADDR)/4];
                avail_count_select <= dbg_avail_count[(raddr-AVAIL_COUNT_START_ADDR)/8];
                if (raddr < CMD_IN_N_CMDS_START_ADDR) begin
                    case (raddr)

                        'h0: begin
                            rdata <= dbg_regs.copy_in_opt;
                        end

                        'h4: begin
                            rdata <= dbg_regs.copy_out_opt;
                        end

                        'h8: begin
                            rdata <= dbg_acc_avail_low;
                        end

                        'hC: begin
                            rdata <= dbg_acc_avail_high;
                        end

                        'h10: begin
                            rdata <= dbg_queue_nempty_low;
                        end

                        'h14: begin
                            rdata <= dbg_queue_nempty_high;
                        end

                        default: begin
                            rresp <= 2'b10; //SLVERR
                        end

                    endcase
                    rstate <= R;
                end else begin
                    rstate <= SELECT_REG_2;
                end
            end

            SELECT_REG_2: begin
                if (raddr[1:0] != 2'd0) begin
                    rresp <= 2'b10;
                end else if (raddr >= CMD_IN_N_CMDS_START_ADDR && raddr < CMD_IN_N_CMDS_END_ADDR) begin
                    rdata <= cmd_in_select;
                end else if (raddr >= CMD_OUT_N_CMDS_START_ADDR && raddr < CMD_OUT_N_CMDS_END_ADDR) begin
                    rdata <= cmd_out_select;
                end else if (raddr >= AVAIL_COUNT_START_ADDR && raddr < AVAIL_COUNT_END_ADDR) begin
                    if (raddr[2] == 1'b0) begin
                        rdata <= avail_count_select_low;
                    end else begin
                        rdata <= avail_count_select_high;
                    end
                end else begin
                    rresp <= 2'b10;
                end
                rstate <= R;
            end

            R: begin
                if (axilite_rready) begin
                    rstate <= AR;
                end
            end

        endcase

        if (!rstn) begin
            rstate <= AR;
        end
    end

endmodule
