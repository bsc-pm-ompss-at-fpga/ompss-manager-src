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
#ifndef __SOM_HPP__
#define __SOM_HPP__

#define QUEUE_VALID           0x80
#define QUEUE_INVALID         0x00
#define VALID_OFFSET          56
#define NUM_ARGS_OFFSET       8
#define NUM_DEPS_OFFSET       16
#define NUM_COPIES_OFFSET     24
#define MAX_ACCS              16
#define ACC_IDX_BITS          4    //< log2(MAX_ACCS)
#define MAX_ACCS_TYPES        MAX_ACCS

//Command codes
#define CMD_EXEC_TASK_CODE    0x01 ///< Command code for execute task commands
#define CMD_SETUP_INS_CODE    0x02 ///< Command code for setup instrumentation info
#define CMD_FINI_EXEC_CODE    0x03 ///< Command code for finished execute task commands
#define CMD_PERI_TASK_CODE    0x05 ///< Command code for execute periodic task commands

//Ack codes
#define ACK_REJECT_CODE       0x0
#define ACK_OK_CODE           0x1

//IDs of the HWR IPs
#define HWR_ID_BITS           5    //< Width of IDs for the stream messages
#define HWR_CMDOUT_ID         0x11
#define HWR_DEPS_ID           0x12
#define HWR_SCHED_ID          0x13
#define HWR_TASKWAIT_ID       0x14

//spawnOutQueue information
#define SPAWNOUT_Q_SLOTS           1024
#define SPAWNOUT_Q_IDX_BITS        10 //< log2(SPAWNOUT_Q_SLOTS)
#define SPAWNOUT_Q_TASK_HEAD_WORDS 4 //< cmdHeader,taskId,parentId,taskType
#define SPAWNOUT_Q_TASK_ARG_WORDS  1 //< argValue
#define SPAWNOUT_Q_TASK_DEP_WORDS  1 //< flags+address
#define SPAWNOUT_Q_TASK_COPY_WORDS 3 //< address,size+idx+flags,lenght+offset

typedef ap_axis<8,1,1,HWR_ID_BITS> axiData8_t;
typedef ap_axiu<64,1,HWR_ID_BITS,HWR_ID_BITS> axiData64_t;
typedef hls::stream<axiData8_t> axiStream8_t;
typedef hls::stream<axiData64_t> axiStream64_t;

#endif //__SOM_HPP__
