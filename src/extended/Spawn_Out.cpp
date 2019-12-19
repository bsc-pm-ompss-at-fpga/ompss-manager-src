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

#define NEW_QUEUE_SLOTS   1024
#define NEW_QUEUE_VALID   0x80
#define NEW_QUEUE_INVALID 0x00
#define BITS_MASK_16      0xFFFF
#define BITS_MASK_8       0xFF
#define NUM_ARGS_OFFSET   8
#define NUM_DEPS_OFFSET   16
#define NUM_COPIES_OFFSET 24
#define VALID_OFFSET      56
#define NEW_QUEUE_TASK_HEAD_WORDS 4 //< cmdHeader,taskId,parentId,taskType
#define NEW_QUEUE_TASK_ARG_WORDS  1 //< argValue
#define NEW_QUEUE_TASK_DEP_WORDS  1 //< flags+address
#define NEW_QUEUE_TASK_COPY_WORDS 3 //< address,size+idx+flags,lenght+offset

typedef ap_axis<64,1,1,5> axiData_t;
typedef hls::stream<axiData_t> axiStream_t;

typedef enum {
	NEW_TM_RESET = 0,
	NEW_TM_READ_W1,
	NEW_TM_READ_HEAD,
	NEW_TM_WAIT,
	NEW_TM_READ_ARG,
	NEW_TM_READ_DEP,
	NEW_TM_READ_CPY,
	NEW_TM_WRITE_HEAD,
	NEW_TM_WRITE_VALID,
	NEW_TM_CLEAN
} new_tm_state_t;

void Spawn_Out_wrapper(uint64_t volatile SpawnOutQueue[NEW_QUEUE_SLOTS], axiStream_t &inStream) {
#pragma HLS INTERFACE axis port=inStream
#pragma HLS INTERFACE bram port=SpawnOutQueue bundle=SpawnOutQueue
#pragma HLS RESOURCE variable=SpawnOutQueue core=RAM_1P_BRAM
#pragma HLS INTERFACE ap_ctrl_none port=return

	static ap_uint<10> _wIdx = 0; //< Slot where the current task creation starts
	static ap_uint<10> _rIdx = 0; //< Slot where the last known read task starts
	static uint64_t _availSlots = NEW_QUEUE_SLOTS; //< Number of available slots in the new queue
	static new_tm_state_t _state = NEW_TM_RESET; //< Current state
	#pragma HLS RESET variable=_state
	static ap_uint<8> _numArgs = 0; //< Number of arguments that current task has
	static ap_uint<8> _wArgIdx = 0; //< Slot where the current argument must be written
	static ap_uint<8> _numDeps = 0; //< Number of dependencies that current task has
	static ap_uint<8> _wDepIdx = 0; //< Slot where the current dependency must be written
	static ap_uint<8> _numCopies = 0; //< Number of copies that current task has
	static ap_uint<8> _wCopyIdx = 0; //< Slot where the current copy must be written

	static uint64_t _buffer[NEW_QUEUE_TASK_HEAD_WORDS];

	if (_state == NEW_TM_RESET) {
		//Under reset
		_wIdx = 0;
		_rIdx = 0;
		_availSlots = NEW_QUEUE_SLOTS;

		_state = NEW_TM_READ_W1;
	} else if (_state == NEW_TM_READ_W1) {
		//Waiting for the 1st word of new task header
		_buffer[0] = inStream.read().data;
		uint64_t tmpArgs = (_buffer[0] >> NUM_ARGS_OFFSET)&BITS_MASK_8;
		_numArgs = tmpArgs;
		uint64_t tmpDeps = (_buffer[0] >> NUM_DEPS_OFFSET)&BITS_MASK_8;
		_numDeps = tmpDeps;
		uint64_t tmpCopies = (_buffer[0] >> NUM_COPIES_OFFSET)&BITS_MASK_8;
		_numCopies = tmpCopies;
		_wArgIdx = 0;
		_wDepIdx = 0;
		_wCopyIdx = 0;

		_state = NEW_TM_WAIT;
	} else if (_state == NEW_TM_READ_HEAD) {
		//Waiting for the remaining task header words
		//NOTE: The accelerator does not send the taskId as it does not known
		_buffer[1 /*taskId idx*/] = 0xFFFF44446666AAAA;
		for (size_t i = 2; i < NEW_QUEUE_TASK_HEAD_WORDS; i++) {
		#pragma HLS UNROLL
			_buffer[i] = inStream.read().data;
		};

		_state = NEW_TM_READ_CPY;
	} else if (_state == NEW_TM_WAIT) {
		//Waiting for enough available slots in SpawnOutQueue
		ap_uint<10> neededSlots =
			NEW_QUEUE_TASK_HEAD_WORDS +
			_numArgs*NEW_QUEUE_TASK_ARG_WORDS +
			_numDeps*NEW_QUEUE_TASK_DEP_WORDS +
			_numCopies*NEW_QUEUE_TASK_COPY_WORDS;
		if (neededSlots <= _availSlots) {
			_state = NEW_TM_READ_HEAD;
		} else {
			uint64_t head0 = SpawnOutQueue[_rIdx];
			if (((head0 >> VALID_OFFSET)&BITS_MASK_8) == NEW_QUEUE_INVALID) {
				uint64_t tmpArgs = (head0 >> NUM_ARGS_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumArgs = tmpArgs;
				uint64_t tmpDeps = (head0 >> NUM_DEPS_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumDeps = tmpDeps;
				uint64_t tmpCopies = (head0 >> NUM_COPIES_OFFSET)&BITS_MASK_8;
				ap_uint<8> tmpNumCopies = tmpCopies;
				ap_uint<10> tmpNumSlots =
					NEW_QUEUE_TASK_HEAD_WORDS +
					tmpNumArgs*NEW_QUEUE_TASK_ARG_WORDS +
					tmpNumDeps*NEW_QUEUE_TASK_DEP_WORDS +
					tmpNumCopies*NEW_QUEUE_TASK_COPY_WORDS;
				_availSlots += tmpNumSlots;
				_rIdx += tmpNumSlots;
			}
		}
	} else if (_state == NEW_TM_READ_ARG) {
		//Waiting for the arguments of new task
		if (_wArgIdx >= _numArgs) {
			_state = NEW_TM_WRITE_HEAD;
		} else {
			ap_uint<10> idx = _wIdx + NEW_QUEUE_TASK_HEAD_WORDS +
				_wArgIdx*NEW_QUEUE_TASK_ARG_WORDS +
				_numDeps*NEW_QUEUE_TASK_DEP_WORDS +
				_numCopies*NEW_QUEUE_TASK_COPY_WORDS;
			SpawnOutQueue[idx] = inStream.read().data;
			_wArgIdx += 1;
		}
	} else if (_state == NEW_TM_READ_DEP) {
		//Waiting for the dependencies of new task
		if (_wDepIdx >= _numDeps) {
			_state = NEW_TM_READ_ARG;
		} else {
			ap_uint<10> idx = _wIdx + NEW_QUEUE_TASK_HEAD_WORDS +
				_wDepIdx*NEW_QUEUE_TASK_DEP_WORDS +
				_numCopies*NEW_QUEUE_TASK_COPY_WORDS;
			SpawnOutQueue[idx] = inStream.read().data;
			_wDepIdx += 1;
		}
	} else if (_state == NEW_TM_READ_CPY) {
		//Waiting for the copies of new task
		if (_wCopyIdx >= _numCopies) {
			_state = NEW_TM_READ_DEP;
		} else {
			ap_uint<10> idx = _wIdx + NEW_QUEUE_TASK_HEAD_WORDS +
				_wCopyIdx*NEW_QUEUE_TASK_COPY_WORDS;
			SpawnOutQueue[idx] = inStream.read().data;
			idx += 1;
			SpawnOutQueue[idx] = inStream.read().data;
			idx += 1;
			SpawnOutQueue[idx] = inStream.read().data;
			_wCopyIdx += 1;
		}
	} else if (_state == NEW_TM_WRITE_HEAD) {
		//Write all words of header, but 1st one
		for (size_t i = 1; i < NEW_QUEUE_TASK_HEAD_WORDS; i++) {
		#pragma HLS UNROLL
			ap_uint<10> idx = _wIdx + i;
			SpawnOutQueue[idx] = _buffer[i];
		};

		_state = NEW_TM_WRITE_VALID;
	} else if (_state == NEW_TM_WRITE_VALID) {
		//Write 1st word of header
		uint64_t tmp = NEW_QUEUE_VALID;
		tmp = (tmp << VALID_OFFSET) | _buffer[0]; //< Ensure task entry is marked as ready
		SpawnOutQueue[_wIdx] = tmp;

		_state = NEW_TM_CLEAN;
	} else if (_state == NEW_TM_CLEAN) {
		//Clean-up
		ap_uint<10> filledSlots =
			NEW_QUEUE_TASK_HEAD_WORDS +
			_numArgs*NEW_QUEUE_TASK_ARG_WORDS +
			_numDeps*NEW_QUEUE_TASK_DEP_WORDS +
			_numCopies*NEW_QUEUE_TASK_COPY_WORDS;
		_wIdx += filledSlots;
		_availSlots -= filledSlots;

		_state = NEW_TM_READ_W1;
	}
}
