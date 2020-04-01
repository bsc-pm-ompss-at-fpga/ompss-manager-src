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

#include <ap_axi_sdata.h>
#include <hls_stream.h>
#include <stdint.h>
#include <string.h>
#include "som.hpp"

#define BITS_MASK_48          0xFFFFFFFFFFFF
#define BITS_MASK_24          0xFFFFFF
#define BITS_MASK_16          0xFFFF
#define BITS_MASK_8           0xFF
#define BITS_MASK_2           0x3
#define EOUT_STREAM_ARG_WORDS          1    //< argValue
#define EOUT_STREAM_DEP_WORDS          1    //< flags+address
#define EOUT_STREAM_COPY_WORDS         3    //< address,size+idx+flags,lenght+offset

#define CMD_IN_QUEUE_SIZE              1024
#define CMD_IN_QUEUE_IDX_BITS          10   //< log2(CMD_IN_QUEUE_SIZE)
#define CMD_IN_SUBQUEUE_IDX_BITS       6    //< log2(CMD_IN_QUEUE_SIZE/MAX_ACCS)
#define CMD_IN_EXECTASK_VALID_OFFSET   56   //< Offset in bits of valid field
#define CMD_IN_EXECTASK_NUMARGS_OFFSET 8
#define CMD_IN_EXECTASK_NUMDEPS_OFFSET 16
#define CMD_IN_EXECTASK_NUMCPYS_OFFSET 24
#define CMD_IN_EXECTASK_DEST_ID_OFFSET 32
#define CMD_IN_EXECTASK_ARG_WORDS      2    //< argId+flags,value
#define CMD_IN_EXECTASK_HEAD_WORDS     3    //< cmdHeader,parentId,taskId
#define CMD_IN_EXECTASK_ARG_ID_OFFSET  32
#define CMD_IN_EXECTASK_COPY_ARG_IDX_OFFSET 8

#define COMPUTE_ENABLED_FLAG           0x1
#define MAX_ARGS                       32  //< 2^5
#define DEFAULT_ARG_FLAGS              0x31 //< enable wrapper copies,private

typedef struct schedInfo_s {
	ap_uint<34> type;    //< Type info (The upper 30 bits are always 0s)
	uint8_t     firstId; //< Accelerator id of first accelerator with the type
	uint8_t     count;   //< Number of accelerators with this type. [firstId, firstId+count) are accels of the type
} schedInfo_t;

typedef enum {
	SCHED_RESET = 0,
	SCHED_READ_HEADER_1,
	SCHED_READ_HEADER_OTHER,
	SCHED_READ_TASK_ID,
	SCHED_GEN_TASK_ID,
	SCHED_ASSIGN,
	SCHED_CMDIN_WAIT,
	SCHED_CMDIN_WRITE,
	SCHED_CMDIN_WRITE_VALID,
	SCHED_REJECT,
	SCHED_SPAWNOUT_WAIT,
	SCHED_SPAWNOUT_WRITE,
	SCHED_SPAWNOUT_WRITE_VALID
} sched_tm_state_t;

void Scheduler_wrapper(
		uint64_t volatile intCmdInQueue[CMD_IN_QUEUE_SIZE],
		uint64_t volatile spawnOutQueue[SPAWNOUT_Q_SLOTS],
		uint32_t bitInfo[256],
		axiStream64_t &inStream,
		axiStream8_t &outStream,
		uint32_t& picosRejectTask)
{
	#pragma HLS INTERFACE bram port=intCmdInQueue bundle=intCmdInQueue
	#pragma HLS RESOURCE variable=intCmdInQueue core=RAM_1P_BRAM
	#pragma HLS INTERFACE bram port=spawnOutQueue bundle=spawnOutQueue
	#pragma HLS RESOURCE variable=spawnOutQueue core=RAM_1P_BRAM
	#pragma HLS INTERFACE bram port=bitInfo
	#pragma HLS INTERFACE axis port=inStream
	#pragma HLS INTERFACE axis port=outStream
	#pragma HLS INTERFACE ap_ovld port=picosRejectTask
	#pragma HLS INTERFACE ap_ctrl_none port=return

	static sched_tm_state_t _state = SCHED_RESET; //< Current state
	#pragma HLS RESET variable=_state

	static ap_uint<CMD_IN_QUEUE_IDX_BITS> _queueOffset; //< Offset where the current writing subqueue of intCmdInQueue starts
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> _cmdIn_wIdx[MAX_ACCS]; //< Slot where the current task creation starts
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> _cmdIn_rIdx[MAX_ACCS]; //< Slot where the last known read task starts
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS+1> _cmdIn_avail[MAX_ACCS]; //< Number of available slots in the new queue

	static ap_uint<SPAWNOUT_Q_IDX_BITS> _spawnOut_wIdx; //< Slot where the current task creation starts
	static ap_uint<SPAWNOUT_Q_IDX_BITS> _spawnOut_rIdx; //< Slot where the last known read task starts
	static ap_uint<SPAWNOUT_Q_IDX_BITS+1> _spawnOut_avail; //< Number of available slots in the new queue

	static ap_uint<8> _numArgs = 0; //< Number of arguments that current task has
	static ap_uint<8> _numDeps = 0; //< Number of dependences that current task has
	static ap_uint<8> _numCopies = 0; //< Number of copies that current task has
	static ap_uint<8> _accId; //< Accelerator ID where the current task will be executed
	static ap_uint<8> _srcAccId; //< Accelerator ID that is sending the task
	static ap_uint<64> _taskId; //< Task ID of the current task
	static ap_uint<64> _parentTaskId; //< Parent task ID of the current task
	static ap_uint<34> _taskType; //< Type of the current task

	static schedInfo_t _scheduleData[MAX_ACCS_TYPES];
	static uint8_t _numAccsTypes;
	static uint8_t  _lastAccId[MAX_ACCS_TYPES];
	static uint8_t  _bufferArgFlags[MAX_ARGS];
	static ap_uint<48> _lastTaskId; //< Last assigned task identifier to tasks created inside the FPGA
	static bool comesFromDepMod; //< The incoming task is sent by the dependencies module

	if (_state == SCHED_RESET) {
		//Under reset
		for (size_t i = 0; i < MAX_ACCS; i++) {
		#pragma HLS PIPELINE
			_cmdIn_wIdx[i] = 0;
			_cmdIn_rIdx[i] = 0;
			_cmdIn_avail[i] = CMD_IN_QUEUE_SIZE/MAX_ACCS;
		};
		for (size_t i = 0; i < MAX_ACCS_TYPES; i++) {
		#pragma HLS PIPELINE
			_lastAccId[i] = 0;
		};
		for (size_t i = 0; i < CMD_IN_QUEUE_SIZE; i++) {
		#pragma HLS PIPELINE
			intCmdInQueue[i] = 0;
		};
		for (size_t i = 0; i < MAX_ARGS; i++) {
		#pragma HLS PIPELINE
			_bufferArgFlags[i] = 0;
		};
		_accId = 0;
		_lastTaskId = 0;
		_spawnOut_wIdx = 0;
		_spawnOut_rIdx = 0;
		_spawnOut_avail = SPAWNOUT_Q_SLOTS;

		while (!inStream.empty()) {
			inStream.read();
		}

		//Update the scheduleData reading the info from the bitstream info BRAM
		_numAccsTypes = 0;
		size_t offset = 4 /*words before the xtasks.config data*/ + 5 /*words of xtasks.config header*/;
		uint8_t firstFreeId = 0;
		union {
			uint32_t raw;
			char text[4];
		} bitinfoCast;

		bitinfoCast.raw = bitInfo[offset++];
		do {
			//Get the accelerator type
			uint64_t type = 0;
			for (uint8_t w = 0; w < 5; w++) {
				//NOTE: Skip the \t character at the end of 5th word
				for (uint8_t c = 0; c < 4 && (c < 3 || w != 4); c++) {
					type = type*10 + (bitinfoCast.text[c] - '0');
				}
				bitinfoCast.raw = bitInfo[offset++];
			}

			//Get the number of instances
			uint8_t numInstances = 0;
			for (uint8_t c = 0; c < 3; c++) {
				numInstances = numInstances*10 + (bitinfoCast.text[c] - '0');
			}

			//Add the type in the _scheduleData
			_scheduleData[_numAccsTypes].type = type;
			_scheduleData[_numAccsTypes].firstId = firstFreeId;
			_scheduleData[_numAccsTypes].count = numInstances;
			_numAccsTypes++;
			firstFreeId += numInstances;

			//Increase the offset until next accelerator type or the ending mark
			offset += 9 /*8 words of name + 1 word of frequency*/;
			bitinfoCast.raw = bitInfo[offset++];

		} while (bitinfoCast.raw != 0xFFFFFFFF && firstFreeId < MAX_ACCS && _numAccsTypes < MAX_ACCS_TYPES);

		_state = SCHED_READ_HEADER_1;
	} else if (_state == SCHED_READ_HEADER_1) {
		//Waiting for the 1st word of new task header
		axiData64_t pkg = inStream.read();
		_srcAccId = pkg.id;

		uint64_t tmpArgs = (pkg.data >> CMD_IN_EXECTASK_NUMARGS_OFFSET)&BITS_MASK_8;
		_numArgs = tmpArgs;
		uint64_t tmpDeps = (pkg.data >> CMD_IN_EXECTASK_NUMDEPS_OFFSET)&BITS_MASK_8;
		_numDeps = tmpDeps;
		uint64_t tmpCopies = (pkg.data >> CMD_IN_EXECTASK_NUMCPYS_OFFSET)&BITS_MASK_8;
		_numCopies = tmpCopies;

		comesFromDepMod = pkg.id >= MAX_ACCS;
		//NOTE: If the source ID is >MAX_ACCS, the pkg comes from the dependencies module and task already has an ID
		_state = pkg.id >= MAX_ACCS ? SCHED_READ_TASK_ID : SCHED_GEN_TASK_ID;
	} else if (_state == SCHED_READ_TASK_ID) {
		//Waiting for the task ID
		_taskId = inStream.read().data | 0xB000000000000000;

		_state = SCHED_READ_HEADER_OTHER;
	} else if (_state == SCHED_GEN_TASK_ID) {
		//Generate an ID for the task
		//NOTE: Using odd ids, so they will fail if used outside the FPGA
		_taskId = ((uint64_t)(++_lastTaskId) << 4) | 0xF00000000000000F;

		_state = SCHED_READ_HEADER_OTHER;
	} else if (_state == SCHED_READ_HEADER_OTHER) {
		//Waiting for the parent task ID and the task type words
		_parentTaskId = inStream.read().data;
		_taskType = inStream.read().data;

		_state = (_numDeps != 0 || _taskType[33/*SMP arch bit*/]) ? SCHED_SPAWNOUT_WAIT : SCHED_ASSIGN;
	} else if (_state == SCHED_ASSIGN) {
		//Decide where the task will be executed
		uint16_t dataIdx = 0; //< Using 0 as not_found value
		for (uint8_t i = 1; i < _numAccsTypes; i++) {
			if (_scheduleData[i].type == _taskType) {
				dataIdx = i;
				break;
			}
		}
		_accId = _lastAccId[dataIdx] + _scheduleData[dataIdx].firstId;
		_queueOffset = _accId*(CMD_IN_QUEUE_SIZE/MAX_ACCS);
		_lastAccId[dataIdx] = (_lastAccId[dataIdx] + 1) == _scheduleData[dataIdx].count ? 0 : _lastAccId[dataIdx] + 1 /*round robin between the accelerators*/;

		_state = SCHED_CMDIN_WAIT;
	} else if (_state == SCHED_CMDIN_WAIT) {
		//Waiting for enough available slots in intCmdInQueue
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> neededSlots =
			CMD_IN_EXECTASK_HEAD_WORDS +
			CMD_IN_EXECTASK_ARG_WORDS*_numArgs;
		if (neededSlots <= _cmdIn_avail[_accId]) {
			_state = SCHED_CMDIN_WRITE;
		} else {
			ap_uint<CMD_IN_QUEUE_IDX_BITS> idx = _queueOffset + _cmdIn_rIdx[_accId];
			uint64_t head0 = intCmdInQueue[idx];
			if (((head0 >> CMD_IN_EXECTASK_VALID_OFFSET)&BITS_MASK_8) == QUEUE_INVALID) {
				uint64_t tmpArgs = (head0 >> CMD_IN_EXECTASK_NUMARGS_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumArgs = tmpArgs;
				ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> tmpNumSlots = CMD_IN_EXECTASK_HEAD_WORDS + CMD_IN_EXECTASK_ARG_WORDS*tmpNumArgs;
				_cmdIn_avail[_accId] += tmpNumSlots;
				_cmdIn_rIdx[_accId] += tmpNumSlots;
			} else {
				//Read remainig words and reject the task as there is not enough space to handle it
				ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> remWords =
					EOUT_STREAM_COPY_WORDS*_numCopies +
					EOUT_STREAM_DEP_WORDS*_numDeps +
					EOUT_STREAM_ARG_WORDS*_numArgs;
				for (ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> idx = 0; idx < remWords; ++idx) {
					inStream.read();
				}

				_state = SCHED_REJECT;
			}
		}
	} else if (_state == SCHED_REJECT) {
		//Send the reject ack
		axiData8_t data;
		data.keep = 0xFF;
		data.dest = _srcAccId;
		data.last = 1;
		data.data = ACK_REJECT_CODE;
		if (comesFromDepMod) {
			picosRejectTask = (uint32_t)_taskId;
		}
		else {
			outStream.write(data);
		}

		_state = SCHED_READ_HEADER_1;
	} else if (_state == SCHED_CMDIN_WRITE) {
		//Waiting for the dependences of new task (ignored if any)
		for (ap_uint<8> idx = 0; idx < _numDeps; ++idx) {
			inStream.read(); //< flags+address
		}

		//Waiting for the copies of new task
		for (ap_uint<8> idx = 0; idx < _numCopies; ++idx) {
			inStream.read(); //< address
			uint64_t word = inStream.read().data; //< [ size | padding | arg_idx | flags ]
			inStream.read(); //< [ accessed length | offset ]

			uint8_t flags = word&BITS_MASK_8;
			uint8_t arg_idx = (word >> CMD_IN_EXECTASK_COPY_ARG_IDX_OFFSET)&BITS_MASK_8;
			//NOTE: Copies of new task use bits [1:0] and ready task uses bits [5:4]
			_bufferArgFlags[arg_idx] |= (flags << 4);
		}

		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> subqueueIdx = _cmdIn_wIdx[_accId] + 1/*Skip valid word*/;
		ap_uint<CMD_IN_QUEUE_IDX_BITS> idx = _queueOffset + subqueueIdx;

		intCmdInQueue[idx] = _taskId;
		idx = ++subqueueIdx + _queueOffset;
		intCmdInQueue[idx] = _parentTaskId;
		idx = ++subqueueIdx + _queueOffset;

		//Waiting for the arguments of new task
		for (ap_uint<8> wArgIdx = 0; wArgIdx < _numArgs; ++wArgIdx) {
			//Argument idx and flags
			uint8_t flags = _bufferArgFlags[wArgIdx];
			uint64_t argInfo = wArgIdx;
			argInfo = (argInfo << CMD_IN_EXECTASK_ARG_ID_OFFSET);
			argInfo |= flags ? flags : DEFAULT_ARG_FLAGS;
			intCmdInQueue[idx] = argInfo;
			idx = ++subqueueIdx + _queueOffset;

			//Argument value
			intCmdInQueue[idx] = inStream.read().data;
			idx = ++subqueueIdx + _queueOffset;

			//Cleanup for next task
			_bufferArgFlags[wArgIdx] = 0;
		}
		_state = SCHED_CMDIN_WRITE_VALID;
	} else if (_state == SCHED_CMDIN_WRITE_VALID) {
		//Write 1st word of header. Format:
		// 63                                                             0
		//+----------------------------------------------------------------+
		//| Valid |       | DesID | CompF |                | #Args | Code  |
		//+----------------------------------------------------------------+
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> subqueueIdx = _cmdIn_wIdx[_accId];
		ap_uint<CMD_IN_QUEUE_IDX_BITS> idx = _queueOffset + subqueueIdx;

		uint64_t tmp = QUEUE_VALID;
		tmp = (tmp << 16) | HWR_CMDOUT_ID;
		tmp = (tmp << 8) | COMPUTE_ENABLED_FLAG;
		tmp = (tmp << 24) | _numArgs;
		tmp = (tmp << 8) | CMD_EXEC_TASK_CODE;
		intCmdInQueue[idx] = tmp;

		//Send ack to accelerator
		axiData8_t data;
		data.keep = 0xFF;
		data.dest = _srcAccId;
		data.last = 1;
		data.data = ACK_OK_CODE;
		if (!comesFromDepMod) {
			outStream.write(data);
		}

		//Clean-up
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> filledSlots =
			CMD_IN_EXECTASK_HEAD_WORDS +
			CMD_IN_EXECTASK_ARG_WORDS*_numArgs;
		_cmdIn_wIdx[_accId] += filledSlots;
		_cmdIn_avail[_accId] -= filledSlots;

		_state = SCHED_READ_HEADER_1;
	} else if (_state == SCHED_SPAWNOUT_WAIT) {
		//Waiting for enough available slots in spawnOutQueue
		ap_uint<SPAWNOUT_Q_IDX_BITS> neededSlots =
			SPAWNOUT_Q_TASK_HEAD_WORDS +
			_numArgs*SPAWNOUT_Q_TASK_ARG_WORDS +
			_numDeps*SPAWNOUT_Q_TASK_DEP_WORDS +
			_numCopies*SPAWNOUT_Q_TASK_COPY_WORDS;
		if (neededSlots <= _spawnOut_avail) {
			_state = SCHED_SPAWNOUT_WRITE;
		} else {
			uint64_t head0 = spawnOutQueue[_spawnOut_rIdx];
			if (((head0 >> VALID_OFFSET)&BITS_MASK_8) == QUEUE_INVALID) {
				uint64_t tmpArgs = (head0 >> NUM_ARGS_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumArgs = tmpArgs;
				uint64_t tmpDeps = (head0 >> NUM_DEPS_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumDeps = tmpDeps;
				uint64_t tmpCopies = (head0 >> NUM_COPIES_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumCopies = tmpCopies;
				ap_uint<SPAWNOUT_Q_IDX_BITS> tmpNumSlots =
					SPAWNOUT_Q_TASK_HEAD_WORDS +
					tmpNumArgs*SPAWNOUT_Q_TASK_ARG_WORDS +
					tmpNumDeps*SPAWNOUT_Q_TASK_DEP_WORDS +
					tmpNumCopies*SPAWNOUT_Q_TASK_COPY_WORDS;
				_spawnOut_avail += tmpNumSlots;
				_spawnOut_rIdx += tmpNumSlots;
			} else {
				//Read remaining words and reject the task as there is not enough space to handle it
				ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> remWords =
					EOUT_STREAM_COPY_WORDS*_numCopies +
					EOUT_STREAM_DEP_WORDS*_numDeps +
					EOUT_STREAM_ARG_WORDS*_numArgs;
				for (ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> idx = 0; idx < remWords; ++idx) {
					inStream.read();
				}

				_state = SCHED_REJECT;
			}
		}
	} else if (_state == SCHED_SPAWNOUT_WRITE) {
		ap_uint<SPAWNOUT_Q_IDX_BITS> idx = _spawnOut_wIdx + 1/*Skip valid words*/;

		//Write the header but the 1st word
		spawnOutQueue[idx] = _taskId; idx += 1;
		spawnOutQueue[idx] = _parentTaskId; idx += 1;
		spawnOutQueue[idx] = (uint64_t)_taskType; idx += 1;

		ap_uint<SPAWNOUT_Q_IDX_BITS> remWords =
			EOUT_STREAM_COPY_WORDS*_numCopies +
			EOUT_STREAM_DEP_WORDS*_numDeps +
			EOUT_STREAM_ARG_WORDS*_numArgs;
		for (ap_uint<SPAWNOUT_Q_IDX_BITS> w = 0; w < remWords; ++w, ++idx) {
			spawnOutQueue[idx] = inStream.read().data;
		}

		_state = SCHED_SPAWNOUT_WRITE_VALID;
	} else if (_state == SCHED_SPAWNOUT_WRITE_VALID) {
		//Write 1st word of header
		uint64_t tmp =
				(((uint64_t)QUEUE_VALID) << VALID_OFFSET) |
				(((uint64_t)_numCopies) << NUM_COPIES_OFFSET) |
				(((uint64_t)_numDeps) << NUM_DEPS_OFFSET) |
				(((uint64_t)_numArgs) << NUM_ARGS_OFFSET);
		spawnOutQueue[_spawnOut_wIdx] = tmp;

		//Send ack to accelerator
		axiData8_t data;
		data.keep = 0xFF;
		data.dest = _srcAccId;
		data.last = 1;
		data.data = ACK_OK_CODE;
		outStream.write(data);

		//Clean-up
		ap_uint<10> filledSlots =
			SPAWNOUT_Q_TASK_HEAD_WORDS +
			_numArgs*SPAWNOUT_Q_TASK_ARG_WORDS +
			_numDeps*SPAWNOUT_Q_TASK_DEP_WORDS +
			_numCopies*SPAWNOUT_Q_TASK_COPY_WORDS;
		_spawnOut_wIdx += filledSlots;
		_spawnOut_avail -= filledSlots;

		_state = SCHED_READ_HEADER_1;
	}
}
