/*--------------------------------------------------------------------
  Copyright (C) Barcelona Supercomputing Center
                Centro Nacional de Supercomputacion (BSC-CNS)

  All Rights Reserved. 
  This file is part of OmpSs@FPGA toolchain.

  Unauthorized copying and/or distribution of this file,
  via any medium is strictly prohibited.
  The intellectual and technical concepts contained herein are
  propietary to BSC-CNS and may be covered by Patents.
--------------------------------------------------------------------*/

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

    localparam SUBQUEUE_SIZE = 64;
    localparam SUBQUEUE_BITS = $clog2(SUBQUEUE_SIZE);

    localparam MAX_ACCS_TYPES = 16;
    localparam DEFAULT_ARG_FLAGS = 2'b11;

    localparam TW_MEM_SIZE = 16;
    localparam TW_MEM_BITS = $clog2(TW_MEM_SIZE);

    //Taskwait inStream
    localparam INSTREAM_COMPONENTS_L = 0;
    localparam INSTREAM_COMPONENTS_H = 31;
    localparam TYPE_B = 32;

    //TW mem struct
    localparam TW_INFO_VALID_ENTRY_B = 0;
    localparam TW_INFO_ACCID_L = 8;
    localparam TW_INFO_COMPONENTS_L = 16;
    localparam TW_INFO_COMPONENTS_H = 47;
    localparam TW_INFO_TASKID_L = 48;
    localparam TW_INFO_TASKID_H = 111;

    localparam ACK_REJECT_CODE = 64'h00;
    localparam ACK_OK_CODE = 64'h01;
    localparam ACK_FINAL_CODE = 64'h02;

    localparam HWR_DEPS_ID = 5'h12;
    localparam HWR_SCHED_ID = 5'h13;
    localparam HWR_TASKWAIT_ID = 5'h14;
    localparam HWR_LOCK_ID = 5'h15;

    //Scheduler data mem struct
    localparam SCHED_DATA_ACCID_L = 0; 
    localparam SCHED_DATA_COUNT_L = 8;
    localparam SCHED_DATA_TASK_TYPE_L = 16;
    localparam SCHED_DATA_TASK_TYPE_H = 49;

    //Lock module
    localparam LOCK_ID_BITS = 8;
    localparam LOCK_ID_L = 8;
    localparam LOCK_ID_H = 15;

endpackage
