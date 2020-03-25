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

#define TASKWAIT_TYPE_BLOCK    0x01
#define TASKWAIT_TYPE_FINISH   0x10
#define BITS_MASK_8            0xFF
#define BITS_MASK_32           0xFFFFFFFF
#define ACC_ID_OFFSET          48
#define TYPE_OFFSET            32
#define COMPONENTS_OFFSET      0

//NOTE: We should not have more than 1 task per accelerator
#define CACHE_SIZE 16
//NOTE: The number of bits must be >= log2(CACHE_SIZE+1)
#define CACHE_IDX_BITS 5

// An element of the taskwaitMemory and remoteCmdOutQueue
typedef struct taskwaitEntry_t {
	uint8_t   valid;
	uint8_t   accId;
	uint8_t   reserved_0;
	uint8_t   type;
	int32_t   components;
	uint64_t  taskId;
} taskwaitEntry_t;

typedef enum {
	STATE_RESET = 0,
	STATE_READ_HEADER,
	STATE_GET_ENTRY,
	STATE_CALC_COMPONENTS_BLOCK,
	STATE_CALC_COMPONENTS_FINISH,
	STATE_WAKEUP_ACC,
	STATE_UPDATE_ENTRY,
} state_t;

void Taskwait_wrapper(axiStream64_t &inStream, axiStream8_t &outStream, taskwaitEntry_t twInfo[CACHE_SIZE]) {
#pragma HLS INTERFACE axis port=inStream
#pragma HLS INTERFACE axis port=outStream
#pragma HLS INTERFACE bram port=twInfo
#pragma HLS DATA_PACK variable=twInfo field_level
#pragma HLS RESOURCE variable=twInfo core=RAM_1P_BRAM
#pragma HLS INTERFACE ap_ctrl_none port=return

	static state_t _state = STATE_RESET;
	#pragma HLS RESET variable=_state
	static int32_t _components;
	static uint8_t _type, _accId;
	static taskwaitEntry_t _cachedInfo;
	static ap_uint<CACHE_IDX_BITS> _entryIdx;

	if (_state == STATE_RESET) {
		//Under reset
		for (ap_uint<CACHE_IDX_BITS> i = 0; i < CACHE_SIZE; i++) {
		#pragma HLS PIPELINE
			taskwaitEntry_t tmpInfo;
			tmpInfo.components = 0;
			tmpInfo.valid = QUEUE_INVALID;
			twInfo[i] = tmpInfo;
		}

		_state = STATE_READ_HEADER;
	} else if (_state == STATE_READ_HEADER) {
		//Read the header word. It has the following format:
		// | 8b    | 8b    | 8b    | 8b    | 32b               |
		// |       | accID |       | type  | components        |
		// | taskId (self or parent based on type)             |
		uint64_t header = inStream.read().data;
		_type = (header >> TYPE_OFFSET)&BITS_MASK_8;
		_components = (header >> COMPONENTS_OFFSET)&BITS_MASK_32;
		_accId = (header >> ACC_ID_OFFSET)&BITS_MASK_8;

		//Read the taskId word (self or parent based on type)
		_cachedInfo.taskId = inStream.read().data;

		_state = STATE_GET_ENTRY;
	} else if (_state == STATE_GET_ENTRY) {
		//Get an entry in the info memory for the taskId
		for (ap_uint<CACHE_IDX_BITS> i = 0; i < CACHE_SIZE; i++) {
			#pragma HLS PIPELINE
			taskwaitEntry_t entry = twInfo[i];
			if (entry.valid == QUEUE_VALID && entry.taskId == _cachedInfo.taskId) {
				_cachedInfo.accId = entry.accId;
				_cachedInfo.components = entry.components;
				_entryIdx = i;
				break;
			}
		}
		//FIXME: Do not asume that a valid entry has been found
		_cachedInfo.valid = QUEUE_VALID;

		_state = _type == TASKWAIT_TYPE_BLOCK ? STATE_CALC_COMPONENTS_BLOCK : STATE_CALC_COMPONENTS_FINISH;
	} else if (_state == STATE_CALC_COMPONENTS_BLOCK) {
		_cachedInfo.components = _cachedInfo.components - _components;
		_cachedInfo.accId = _accId;

		_state = _cachedInfo.components == 0 ? STATE_WAKEUP_ACC : STATE_UPDATE_ENTRY;
	} else if (_state == STATE_CALC_COMPONENTS_FINISH) {
		_cachedInfo.components = _cachedInfo.components + _components;

		_state = _cachedInfo.components == 0 ? STATE_WAKEUP_ACC : STATE_UPDATE_ENTRY;
	} else if (_state == STATE_WAKEUP_ACC) {
		//Send the wake up signal to the blocked accelerator and invalidate the info entry
		axiData8_t data;
		data.keep = 0xFF;
		data.dest = _cachedInfo.accId;
		data.last = 1;
		data.data = 1;
		outStream.write(data);
		_cachedInfo.valid = QUEUE_INVALID;

		_state = STATE_UPDATE_ENTRY;
	} else if (STATE_UPDATE_ENTRY) {
		//Update the twInfo memory
		twInfo[_entryIdx] = _cachedInfo;

		_state = STATE_READ_HEADER;
	} else {
		//Uncontrolled path
		_state = STATE_RESET;
	}
}
