/*------------------------------------------------------------------------*/
/*    (C) Copyright 2017-2019 Barcelona Supercomputing Center             */
/*                            Centro Nacional de Supercomputacion         */
/*                                                                        */
/*    This file is part of OmpSs@FPGA toolchain.                          */
/*                                                                        */
/*    This code is free software; you can redistribute it and/or modify   */
/*    it under the terms of the GNU General Public License as published   */
/*    by the Free Software Foundation; either version 3 of the License,   */
/*    or (at your option) any later version.                              */
/*                                                                        */
/*    OmpSs@FPGA toolchain is distributed in the hope that it will be     */
/*    useful, but WITHOUT ANY WARRANTY; without even the implied          */
/*    warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    */
/*    See the GNU General Public License for more details.                */
/*                                                                        */
/*    You should have received a copy of the GNU General Public License   */
/*    along with this code. If not, see <www.gnu.org/licenses/>.          */
/*------------------------------------------------------------------------*/

#include <ap_axi_sdata.h>
#include <hls_stream.h>
#include <stdint.h>
#include <string.h>

typedef ap_axis<8,1,1,5> axiData8_t;
typedef ap_axis<64,1,1,5> axiData64_t;
typedef hls::stream<axiData8_t> axiStream8_t;
typedef hls::stream<axiData64_t> axiStream64_t;

// An element of the taskwaitMemory and remoteCmdOutQueue
typedef struct taskwaitEntry_t {
	ap_uint<8>  valid;
	ap_uint<8>  accId;
	ap_uint<8>  reserved_0;
	ap_uint<8>  type;
	ap_int<32>  components;
	ap_uint<64> taskId;
} taskwaitEntry_t;

#define TASKWAIT_ENTRY_VALID   0x80
#define TASKWAIT_ENTRY_INVALID 0x00
#define TASKWAIT_TYPE_BLOCK    0x01
#define TASKWAIT_TYPE_FINISH   0x10

#define TASKWAIT_TASK_MANAGER_ID   0x13

//NOTE: The QUEUE_SLOTS value must match with the width of _rIdx
#define QUEUE_SLOTS       1024

void Remote_Finished_Task_Manager_wrapper(taskwaitEntry_t inQueue[QUEUE_SLOTS], axiStream64_t &outStream) {
#pragma HLS INTERFACE axis port=outStream
#pragma HLS INTERFACE bram port=inQueue
#pragma HLS DATA_PACK variable=inQueue field_level
#pragma HLS RESOURCE variable=inQueue core=RAM_1P_BRAM
#pragma HLS INTERFACE ap_ctrl_none port=return

	static ap_uint<10> _rIdx = 0;     //< Slot to read in inQueue
	static uint8_t _state = 0;        //< Current state
	#pragma HLS RESET variable=_state
	static taskwaitEntry_t _buffer;   //< Temporary storage for read data

	if (_state == 0) {
		//Under reset
		_rIdx = 0;

		_state = 1;
	} else if (_state == 1) {
		//Waiting for a valid entry
		_buffer = inQueue[_rIdx];
		if (_buffer.valid == TASKWAIT_ENTRY_VALID) {
			_state = 2;
		}
	} else if (_state == 2) {
		//Mark the entry as invalid and increase the read index
		inQueue[_rIdx].valid = TASKWAIT_ENTRY_INVALID;
		_rIdx++;
		_state = 3;
	} else if (_state == 3) {
		//Sent the data to outStream
		// Format of the information:
		// | 8b    | 8b    | 8b    | 8b    | 32b               |
		// |       | accID |       | type  | components        |
		// | taskId (parent based on type)                     |
                // accID and type are ignored and the values are fixed
		uint64_t tmp = 0 /*_buffer.accId*/;
		tmp = (tmp << 16) | TASKWAIT_TYPE_FINISH /*_buffer.type*/;
		tmp = (tmp << 32) | _buffer.components;

		axiData64_t data;
		data.keep = 0xFF;
		data.dest = TASKWAIT_TASK_MANAGER_ID;
		data.last = 0;
		data.data = tmp;
		outStream.write(data);

		data.last = 1;
		data.data = _buffer.taskId;
		outStream.write(data);

		_state = 1;
	}
}

#undef QUEUE_
#undef QUEUE_VALID
#undef QUEUE_SLOTS
