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
#define BITS_MASK_8           0xFF

#define TASKWAIT_TYPE_BLOCK        0x01
#define TASKWAIT_TYPE_FINISH       0x10
#define TASKWAIT_TASK_MANAGER_ID   0x13

#define REM_FINI_QUEUE_SIZE        1024
#define REM_FINI_QUEUE_IDX_BITS    10   //< log2(REM_FINI_QUEUE_SIZE)
#define REM_FINI_VALID_OFFSET      56   //< Offset in bits of valid field
#define REM_FINI_ENTRY_WORDS       3    //< header, taskId, parentId

typedef ap_axis<8,1,1,5> axiData8_t;
typedef ap_axis<64,1,1,5> axiData64_t;
typedef hls::stream<axiData8_t> axiStream8_t;
typedef hls::stream<axiData64_t> axiStream64_t;

typedef enum {
  STATE_RESET = 0,
  STATE_READ_HEADER,
  STATE_READ_BODY,
  STATE_UPDATE_ENTRY,
  STATE_NOTIFY_TW
} state_t;

void Spawn_In_wrapper(uint64_t SpawnInQueue[REM_FINI_QUEUE_SIZE], axiStream64_t &outStream) {
#pragma HLS INTERFACE axis port=outStream
#pragma HLS INTERFACE bram port=SpawnInQueue
#pragma HLS RESOURCE variable=SpawnInQueue core=RAM_1P_BRAM
#pragma HLS INTERFACE ap_ctrl_none port=return

	static state_t _state = STATE_RESET;
	#pragma HLS RESET variable=_state
	static ap_uint<REM_FINI_QUEUE_IDX_BITS> _rIdx = 0; //< Slot to read in SpawnInQueue
	static uint64_t _header; //< Temporary storage for head word
	static uint64_t _taskId; //< Temporary storage for taskId word
	static uint64_t _parentId; //< Temporary storage for parentId word

	if (_state == STATE_RESET) {
		//Under reset
		_rIdx = 0;

		_state = STATE_READ_HEADER;
	} else if (_state == STATE_READ_HEADER) {
		//Waiting for a valid entry
		_header = SpawnInQueue[_rIdx];
		if (((_header >> REM_FINI_VALID_OFFSET)&BITS_MASK_8) == QUEUE_VALID) {
			_state = STATE_READ_BODY;
		}
	} else if (_state == STATE_READ_BODY) {
		static ap_uint<REM_FINI_QUEUE_IDX_BITS> idx;

		//Read the taskId
		idx = _rIdx + 1;
		_taskId = SpawnInQueue[idx];
		SpawnInQueue[idx] = 0;

		//Read the parentId
		idx = _rIdx + 2;
		_parentId = SpawnInQueue[idx];
		SpawnInQueue[idx] = 0;

		_state = STATE_UPDATE_ENTRY;
	} else if (_state == STATE_UPDATE_ENTRY) {
		//Mark the entry as invalid and increase the read index

		SpawnInQueue[_rIdx] = 0;
		_rIdx = _rIdx + REM_FINI_ENTRY_WORDS;

		_state = STATE_NOTIFY_TW;
	} else if (_state == STATE_NOTIFY_TW) {
		//Sent the data to outStream
		// Header format:
		// | 8b    | 8b    | 8b    | 8b    | 32b               |
		// |       | accID |       | type  | components        |
		// NOTE: accID, type and components are ignored. Their values are fixed
		uint64_t tmp = 0 /*accId*/;
		tmp = (tmp << 16) | TASKWAIT_TYPE_FINISH /*type*/;
		tmp = (tmp << 32) | 1 /*components*/;

		axiData64_t data;
		data.keep = 0xFF;
		data.dest = TASKWAIT_TASK_MANAGER_ID;
		data.last = 0;
		data.data = tmp;
		outStream.write(data);

		data.last = 1;
		data.data = _parentId;
		outStream.write(data);

		_state = STATE_READ_HEADER;
	}
}
