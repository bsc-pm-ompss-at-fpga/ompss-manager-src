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

package OmpSsManager;

    //Headers
    localparam ENTRY_VALID_OFFSET = 63;
    localparam ENTRY_VALID_BYTE_OFFSET = 56;
    localparam DESTID_L = 40;
    localparam DESTID_H = 47;
    localparam COMPF_L = 32;
    localparam COMPF_H = 39;
    localparam CMD_TYPE_L = 0;
    localparam CMD_TYPE_H = 7;
    localparam NUM_ARGS_OFFSET = 8;
    localparam NUM_DEPS_OFFSET = 16;
    localparam NUM_COPS_OFFSET = 24;
    localparam TASK_SEQ_ID_L = 32;
    localparam TASK_SEQ_ID_H = 63;

    //Cmd codes
    localparam EXEC_TASK_CODE_BYTE = 8'h1;
    localparam EXEC_TASK_CODE = 4'h1;
    localparam SETUP_HW_INST_CODE = 4'h2;
    localparam EXEC_PERI_TASK_CODE = 4'h5;
    localparam CMD_LOCK_CODE = 8'h04;
    localparam CMD_UNLOCK_CODE = 8'h06;

    //Argument flags
    localparam ARG_FLAG_L = 0;
    localparam ARG_FLAG_H = 7;
    localparam ARG_IDX_L = 32;
    localparam ARG_IDX_H = 35;
    localparam DEFAULT_ARG_FLAGS = 2'b11;

    //Taskwait inStream
    localparam INSTREAM_COMPONENTS_L = 0;
    localparam INSTREAM_COMPONENTS_H = 31;
    localparam TYPE_B = 32;

    localparam ACK_REJECT_CODE = 8'h00;
    localparam ACK_OK_CODE = 8'h01;
    localparam ACK_FINAL_CODE = 8'h02;

    localparam HWR_CMDOUT_ID_BYTE = 8'h0;
    localparam HWR_CMDOUT_ID = 2'h0;
    localparam HWR_LOCK_ID = 2'h1;
    localparam HWR_NEWTASK_ID = 2'h2;
    localparam HWR_TASKWAIT_ID = 2'h3;

    //Scheduler module
    localparam CMD_NEWTASK_ARCHBITS_FPGA_B = 32; //Bit idx of FPGA architecture bit in New Task Command
    localparam CMD_NEWTASK_ARCHBITS_SMP_B = 33; //Bit ifx of SMP architecture bit in New Task Command
    localparam SCHED_ARCHBITS_BITS = 2;
    localparam CMD_NEWTASK_ARCHBITS_L = 32; //Low bit idx of Arch bitmask field in New task command
    localparam CMD_NEWTASK_ARCHBITS_H = 33; //High bit idx of ^
    localparam SCHED_TASKTYPE_BITS = 32;
    localparam CMD_NEWTASK_TASKTYPE_L = 0; //Low bit idx of TaskType field in New task command
    localparam CMD_NEWTASK_TASKTYPE_H = 31; //High bit idx of ^
    localparam SCHED_INSNUM_BITS = 8;
    localparam SCHED_INSNUM_ANY = 8'hFF; //Value of InstanceNum field when a task can run in any instance
    localparam CMD_NEWTASK_INSNUM_L = 40; //Low bit idx of InstanceNum field in New Task command
    localparam CMD_NEWTASK_INSNUM_H = 47; //High bit idx of ^

    //Lock module
    localparam LOCK_ID_BITS = 8;
    localparam LOCK_ID_L = 8;
    localparam LOCK_ID_H = 15;

    localparam NDBGREGS = 2;

    typedef struct packed {
        logic [31:0] copy_in_opt;
        logic [31:0] copy_out_opt;
    } DbgRegs_t;

endpackage
