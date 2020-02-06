/*--------------------------------------------------------------------
  (C) Copyright 2017-2019 Barcelona Supercomputing Center
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

#define QUEUE_VALID           0x80
#define QUEUE_INVALID         0x00
#define MAX_ACCS              16
#define ACC_IDX_BITS          4    //< log2(MAX_ACCS)
#define BITS_MASK_48          0xFFFFFFFFFFFF
#define BITS_MASK_24          0xFFFFFF
#define BITS_MASK_16          0xFFFF
#define BITS_MASK_8           0xFF
#define BITS_MASK_2           0x3
#define CMD_EXEC_TASK_CODE    0x01 ///< Command code for execute task commands
#define CMD_SETUP_INS_CODE    0x02 ///< Command code for setup instrumentation info
#define CMD_FINI_EXEC_CODE    0x03 ///< Command code for finished execute task commands

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
#define CMD_OUT_TM_ID                  0x11
#define DEFAULT_ARG_FLAGS              0x31 //< enable wrapper copies,private
#define MAX_ACCS_TYPES                 MAX_ACCS

typedef ap_axiu<64,1,1,5> axiData64_t;
typedef hls::stream<axiData64_t> axiStream64_t;

typedef struct schedInfo_s {
	uint64_t type;    //< Type info
	uint8_t  firstId; //< Accelerator id of first accelerator with the type
	uint8_t  count;   //< Number of accelerators with this type. [firstId, firstId+count) are accels of the type
} schedInfo_t;

typedef enum {
	SCHED_TM_RESET = 0,
	SCHED_TM_READ_W1,
	SCHED_TM_READ_W2,
	SCHED_TM_READ_W3,
	SCHED_TM_ASSIGN,
	SCHED_TM_WAIT,
	SCHED_TM_READ_ARG,
	SCHED_TM_READ_DEP,
	SCHED_TM_READ_CPY,
	SCHED_TM_WRITE_HEAD,
	SCHED_TM_WRITE_VALID,
	SCHED_TM_CLEAN
} sched_tm_state_t;

void Scheduler_wrapper(uint64_t volatile intCmdInQueue[CMD_IN_QUEUE_SIZE], axiStream64_t &inStream, uint32_t bitInfo[256]) {
#pragma HLS INTERFACE axis port=inStream
#pragma HLS INTERFACE bram port=intCmdInQueue bundle=intCmdInQueue
#pragma HLS DATA_PACK variable=intCmdInQueue struct_level
#pragma HLS RESOURCE variable=intCmdInQueue core=RAM_1P_BRAM
#pragma HLS INTERFACE bram port=bitInfo
#pragma HLS INTERFACE ap_ctrl_none port=return

	static ap_uint<CMD_IN_QUEUE_IDX_BITS> _queueOffset; //< Offset where the current writing subqueue of intCmdInQueue starts
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> _wIdx[MAX_ACCS]; //< Slot where the current task creation starts
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> _rIdx[MAX_ACCS]; //< Slot where the last known read task starts
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS+1> _availSlots[MAX_ACCS]; //< Number of available slots in the new queue
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> _wArgIdx = 0; //< Slot where the current argument must be written
	static sched_tm_state_t _state = SCHED_TM_RESET; //< Current state
	#pragma HLS RESET variable=_state
	static ap_uint<8> _numArgs = 0; //< Number of arguments that current task has
	static ap_uint<8> _numDeps = 0; //< Number of dependences that current task has
	static ap_uint<8> _numCopies = 0; //< Number of copies that current task has
	static ap_uint<8> _accId; //< Accelerator ID where the current task will be executed

	static schedInfo_t _scheduleData[MAX_ACCS_TYPES];
	static uint8_t _numAccsTypes;
	static uint8_t  _lastAccId[MAX_ACCS_TYPES];
	static uint64_t _bufferHead[CMD_IN_EXECTASK_HEAD_WORDS];
	static uint8_t  _bufferArgFlags[MAX_ARGS];
	static uint64_t _lastTaskId; //< Last assigned task identifier to tasks created inside the FPGA

	if (_state == SCHED_TM_RESET) {
		//Under reset
		for (size_t i = 0; i < MAX_ACCS; i++) {
		#pragma HLS PIPELINE
			_wIdx[i] = 0;
			_rIdx[i] = 0;
			_availSlots[i] = CMD_IN_QUEUE_SIZE/MAX_ACCS;
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

		_state = SCHED_TM_READ_W1;
	} else if (_state == SCHED_TM_READ_W1) {
		//Waiting for the 1st word of new task header
		_bufferHead[0] = inStream.read().data;

		uint64_t tmpVal = (_bufferHead[0] >> CMD_IN_EXECTASK_NUMARGS_OFFSET)&BITS_MASK_8;
		_numArgs = tmpVal;
		_wArgIdx = 0;

		tmpVal = (_bufferHead[0] >> CMD_IN_EXECTASK_NUMDEPS_OFFSET)&BITS_MASK_8;
		_numDeps = tmpVal;

		tmpVal = (_bufferHead[0] >> CMD_IN_EXECTASK_NUMCPYS_OFFSET)&BITS_MASK_8;
		_numCopies = tmpVal;

		//TODO: Ensure that the task is an FPGA task. Otherwise, it has to be fwd to TM_NEW

		_state = SCHED_TM_READ_W2;
	} else if (_state == SCHED_TM_READ_W2) {
		//Waiting for the 2nd word of new task header
		_bufferHead[1] = inStream.read().data;

		_state = SCHED_TM_READ_W3;
	} else if (_state == SCHED_TM_READ_W3) {
		//Waiting for the 3rd word of new task header
		_bufferHead[2] = inStream.read().data;

		_state = SCHED_TM_ASSIGN;
	} else if (_state == SCHED_TM_ASSIGN) {
		//Decide where the task will be executed
		uint16_t dataIdx = 0; //< Using 0 as not_found value
		for (uint8_t i = 1; i < _numAccsTypes; i++) {
			if (_scheduleData[i].type == _bufferHead[2]) {
				dataIdx = i;
				break;
			}
		}
		_accId = _lastAccId[dataIdx] + _scheduleData[dataIdx].firstId;
		_queueOffset = _accId*(CMD_IN_QUEUE_SIZE/MAX_ACCS);
		_lastAccId[dataIdx] = (_lastAccId[dataIdx] + 1) % _scheduleData[dataIdx].count /*round robin between the accelerators*/;

		_state = SCHED_TM_WAIT;
	} else if (_state == SCHED_TM_WAIT) {
		//Waiting for enough available slots in intCmdInQueue
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> neededSlots =
			CMD_IN_EXECTASK_HEAD_WORDS +
			CMD_IN_EXECTASK_ARG_WORDS*_numArgs;
		if (neededSlots <= _availSlots[_accId]) {
			_state = SCHED_TM_READ_CPY;
		} else {
			ap_uint<CMD_IN_QUEUE_IDX_BITS> idx = _queueOffset + _rIdx[_accId];
			uint64_t head0 = intCmdInQueue[idx];
			if (((head0 >> CMD_IN_EXECTASK_VALID_OFFSET)&BITS_MASK_8) == QUEUE_INVALID) {
				uint64_t tmpArgs = (head0 >> CMD_IN_EXECTASK_NUMARGS_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumArgs = tmpArgs;
				ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> tmpNumSlots = CMD_IN_EXECTASK_HEAD_WORDS + CMD_IN_EXECTASK_ARG_WORDS*tmpNumArgs;
				_availSlots[_accId] += tmpNumSlots;
				_rIdx[_accId] += tmpNumSlots;
			}
		}
	} else if (_state == SCHED_TM_READ_ARG) {
		//Waiting for the arguments of new task
		if (_wArgIdx >= _numArgs) {
			_state = SCHED_TM_WRITE_HEAD;
		} else {
                        ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> subqueueIdx = _wIdx[_accId] + CMD_IN_EXECTASK_HEAD_WORDS + _wArgIdx*CMD_IN_EXECTASK_ARG_WORDS;
                        ap_uint<CMD_IN_QUEUE_IDX_BITS> idx = _queueOffset + subqueueIdx;

                        //Argument idx and flags
                        uint8_t flags = _bufferArgFlags[_wArgIdx];
                        uint64_t argInfo = _wArgIdx;
                        argInfo = (argInfo << CMD_IN_EXECTASK_ARG_ID_OFFSET);
                        argInfo |= flags ? flags : DEFAULT_ARG_FLAGS;
                        intCmdInQueue[idx] = argInfo;

                        //Argument value
                        subqueueIdx++;
                        idx = _queueOffset + subqueueIdx;
                        intCmdInQueue[idx] = inStream.read().data;

			//Cleanup for next task
			_bufferArgFlags[_wArgIdx] = 0;

			_wArgIdx += 1;
		}
	} else if (_state == SCHED_TM_READ_DEP) {
		//Waiting for the dependences of new task (ignored if any)
		for (ap_uint<8> idx = 0; idx < _numDeps; ++idx) {
			inStream.read(); //< flags+address
		}
		_state = SCHED_TM_READ_ARG;
	} else if (_state == SCHED_TM_READ_CPY) {
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
		_state = SCHED_TM_READ_ARG;
	} else if (_state == SCHED_TM_WRITE_HEAD) {
		//Write 2nd and 3th words of header
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> subqueueIdx = _wIdx[_accId];
		ap_uint<CMD_IN_QUEUE_IDX_BITS> idx;

		++subqueueIdx;
		idx = _queueOffset + subqueueIdx;
		//NOTE: Using odd ids, so they will fail if used outside the FPGA
		intCmdInQueue[idx] = ((++_lastTaskId) << 1) | 1; //< taskId

		++subqueueIdx;
		idx = _queueOffset + subqueueIdx;
		intCmdInQueue[idx] = _bufferHead[1]; //< parentTaskId

		_state = SCHED_TM_WRITE_VALID;
	} else if (_state == SCHED_TM_WRITE_VALID) {
		//Write 1st word of header. Format:
		// 63                                                             0
		//+----------------------------------------------------------------+
		//| Valid |       | DesID | CompF |                | #Args | Code  |
		//+----------------------------------------------------------------+
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> subqueueIdx = _wIdx[_accId];
		ap_uint<CMD_IN_QUEUE_IDX_BITS> idx = _queueOffset + subqueueIdx;

		uint64_t tmp = QUEUE_VALID;
		tmp = (tmp << 16) | CMD_OUT_TM_ID;
		tmp = (tmp << 8) | COMPUTE_ENABLED_FLAG;
		tmp = (tmp << 24) | _numArgs;
		tmp = (tmp << 8) | CMD_EXEC_TASK_CODE;
		intCmdInQueue[idx] = tmp;

		_state = SCHED_TM_CLEAN;
	} else if (_state == SCHED_TM_CLEAN) {
		//Clean-up
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> filledSlots =
			CMD_IN_EXECTASK_HEAD_WORDS +
			CMD_IN_EXECTASK_ARG_WORDS*_numArgs;
		_wIdx[_accId] += filledSlots;
		_availSlots[_accId] -= filledSlots;

		_state = SCHED_TM_READ_W1;
	}
}
