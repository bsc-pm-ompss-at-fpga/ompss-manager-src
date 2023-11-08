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

module cmdin_sim #(
    parameter NUM_ACCS = 16,
    parameter NUM_CMDS = 16
) (
    input clk,
    MemoryPort32.master cmdinPort
);

    import Glb::*;
    import OmpSsManager::*;

    typedef enum {
        CHECK_AVAIL_SLOT,
        FREE_SLOT,
        WRITE_TID,
        WRITE_PTID,
        WRITE_PERIOD_NREP,
        WRITE_INST_ADDR,
        WRITE_ARG_FLAGS,
        WRITE_ARGS,
        WRITE_HEADER,
        IDLE
    } State_t;

    function int getCmdLength(input int code, input int nArgs);
        case (code)
            EXEC_TASK_CODE: begin
                return 3 + nArgs*2;
            end

            SETUP_HW_INST_CODE: begin
                return 2;
            end

            EXEC_PERI_TASK_CODE: begin
                return 4 + nArgs*2;
            end
        endcase
        $error("Invalid code %0d", code);
        $fatal;
    endfunction

    State_t state;
    int args_idx, cmd_idx;
    int acc_id;
    reg [5:0] header_idx;
    reg [5:0] write_idx[NUM_ACCS];
    reg [5:0] read_idx[NUM_ACCS];
    int avail_slots[NUM_ACCS];
    Command curCommand;

    initial begin
        int i, j;
        state = IDLE;
        args_idx = 0;
        header_idx = 0;
        cmd_idx = 0;
        for (i = 0; i < NUM_ACCS; i = i+1) begin
            write_idx[i] = 1;
            read_idx[i] = 0;
            avail_slots[i] = 64;
        end
        #1
        acc_id = commands[0].acc_id;
        #699
        state = CHECK_AVAIL_SLOT;
    end

    assign cmdinPort.en = state != IDLE;

    always_comb begin

        cmdinPort.wr = 8'hFF;
        cmdinPort.addr[2:0] = 3'd0;
        cmdinPort.addr[8:3] = write_idx[acc_id];
        cmdinPort.addr[31:9] = acc_id;

        case (state)

            IDLE: begin
                cmdinPort.wr = 0;
            end

            CHECK_AVAIL_SLOT: begin
                cmdinPort.wr = 0;
                cmdinPort.addr[8:3] = read_idx[acc_id];
            end

            FREE_SLOT: begin
                cmdinPort.wr = 0;
                cmdinPort.addr[8:3] = read_idx[acc_id];
            end

            WRITE_TID: begin
                cmdinPort.din = commands[cmd_idx].tid;
            end

            WRITE_PTID: begin
                cmdinPort.din = 64'hXXXXXXXXXXXXXXXX;
            end

            WRITE_PERIOD_NREP: begin
                cmdinPort.din[63:32] = commands[cmd_idx].period;
                cmdinPort.din[31:0] = commands[cmd_idx].repetitions;
            end

            WRITE_INST_ADDR: begin
                cmdinPort.din = commands[cmd_idx].tid;
            end

            WRITE_ARG_FLAGS: begin
                cmdinPort.din[63:32] = args_idx;
                cmdinPort.din[31:8] = 24'hXXXXXX;
                cmdinPort.din[7:0] = commands[cmd_idx].argFlags[args_idx];
            end

            WRITE_ARGS: begin
                cmdinPort.din = commands[cmd_idx].args[args_idx];
            end

            WRITE_HEADER: begin
                cmdinPort.din = 64'hXXXXXXXXXXXXXXXX;
                cmdinPort.din[CMD_TYPE_H:CMD_TYPE_L] = commands[cmd_idx].code;
                cmdinPort.din[ENTRY_VALID_BYTE_OFFSET +: 8] = 8'h80;
                case (commands[cmd_idx].code)
                    EXEC_TASK_CODE: begin
                        cmdinPort.din[DESTID_H:DESTID_L] = HWR_CMDOUT_ID_BYTE;
                        cmdinPort.din[COMPF_H:COMPF_L] = commands[cmd_idx].comp;
                        cmdinPort.din[NUM_ARGS_OFFSET +: 8] = commands[cmd_idx].nArgs;
                    end
                    EXEC_PERI_TASK_CODE: begin
                        cmdinPort.din[DESTID_H:DESTID_L] = HWR_CMDOUT_ID_BYTE;
                        cmdinPort.din[COMPF_H:COMPF_L] = commands[cmd_idx].comp;
                        cmdinPort.din[NUM_ARGS_OFFSET +: 8] = commands[cmd_idx].nArgs;
                    end
                    SETUP_HW_INST_CODE: begin
                        cmdinPort.din[31:8] = commands[cmd_idx].period[23:0];
                    end
                endcase

            end

        endcase
    end

    always @(posedge clk) begin
        case (state)

            CHECK_AVAIL_SLOT: begin
                int needed_slots;
                needed_slots = getCmdLength(commands[cmd_idx].code, commands[cmd_idx].nArgs);

                if (avail_slots[acc_id] < needed_slots) begin
                    state <= FREE_SLOT;
                end else begin
                    curCommand = commands[cmd_idx];
                    if (commands[cmd_idx].code == SETUP_HW_INST_CODE) begin
                        state <= WRITE_INST_ADDR;
                    end else begin
                        state <= WRITE_TID;
                    end
                end
            end

            FREE_SLOT: begin
                state <= CHECK_AVAIL_SLOT;
                if (cmdinPort.dout[63:56] == 8'h00) begin
                    avail_slots[acc_id] <= avail_slots[acc_id] + getCmdLength(cmdinPort.dout[CMD_TYPE_H:CMD_TYPE_L], cmdinPort.dout[NUM_ARGS_OFFSET +: 8]);
                    read_idx[acc_id] <= read_idx[acc_id] + getCmdLength(cmdinPort.dout[CMD_TYPE_H:CMD_TYPE_L], cmdinPort.dout[NUM_ARGS_OFFSET +: 8]);
                end
            end

            WRITE_TID: begin
                header_idx = write_idx[acc_id] - 1;
                write_idx[acc_id] <= write_idx[acc_id] + 1;
                state <= WRITE_PTID;
            end

            WRITE_PTID: begin
                if (commands[cmd_idx].code == EXEC_PERI_TASK_CODE) begin
                    write_idx[acc_id] <= write_idx[acc_id] + 1;
                    state <= WRITE_PERIOD_NREP;
                end else begin
                    if (commands[cmd_idx].nArgs == 0) begin
                        header_idx <= write_idx[acc_id] + 1;
                        write_idx[acc_id] <= header_idx;
                        state <= WRITE_HEADER;
                    end else begin
                        write_idx[acc_id] <= write_idx[acc_id] + 1;
                        state <= WRITE_ARG_FLAGS;
                    end
                end
            end

            WRITE_PERIOD_NREP: begin
                if (commands[cmd_idx].nArgs == 0) begin
                    header_idx <= write_idx[acc_id] + 1;
                    write_idx[acc_id] <= header_idx;
                    state <= WRITE_HEADER;
                end else begin
                    write_idx[acc_id] <= write_idx[acc_id] + 1;
                    state <= WRITE_ARG_FLAGS;
                end
            end

            WRITE_INST_ADDR: begin
                header_idx = write_idx[acc_id] + 1;
                write_idx[acc_id] = write_idx[acc_id] - 1;
                state <= WRITE_HEADER;
            end

            WRITE_ARG_FLAGS: begin
                write_idx[acc_id] <= write_idx[acc_id] + 1;
                state <= WRITE_ARGS;
            end

            WRITE_ARGS: begin
                args_idx <= args_idx+1;
                if (args_idx == commands[cmd_idx].nArgs-1) begin
                    state <= WRITE_HEADER;
                    header_idx <= write_idx[acc_id] + 1;
                    write_idx[acc_id] <= header_idx;
                end else begin
                    write_idx[acc_id] <= write_idx[acc_id] + 1;
                    state <= WRITE_ARG_FLAGS;
                end
            end

            WRITE_HEADER: begin
                cmd_idx <= cmd_idx+1;
                args_idx <= 0;
                write_idx[acc_id] <= header_idx+1;
                avail_slots[acc_id] <= avail_slots[acc_id] - getCmdLength(commands[cmd_idx].code, commands[cmd_idx].nArgs);;
                if (cmd_idx == NUM_CMDS-1) begin
                    state <= IDLE;
                end else begin
                    acc_id = commands[cmd_idx+1].acc_id;
                    state <= CHECK_AVAIL_SLOT;
                end
            end

            IDLE: begin

            end

        endcase
    end

endmodule
