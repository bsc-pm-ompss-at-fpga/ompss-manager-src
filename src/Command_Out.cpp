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

#define BITS_MASK_8           0xFF

#define CMD_OUT_QUEUE_SIZE             1024
#define CMD_OUT_QUEUE_IDX_BITS         10   //< log2(CMD_OUT_QUEUE_SIZE)
#define CMD_OUT_SUBQUEUE_IDX_BITS      6    //< log2(CMD_OUT_QUEUE_SIZE/MAX_ACCS)
#define CMD_OUT_VALID_OFFSET           56   //< Offset in bits of valid field

#define ACC_AVAIL_FROM_NONE   0x0
#define ACC_AVAIL_FROM_CMDIN  0x1
#define ACC_AVAIL_FROM_INT    0x2

typedef uint64_t accAvailability_t;

typedef enum {
	CMD_OUT_TM_RESET = 0,
	CMD_OUT_TM_READ_HEAD,
	CMD_OUT_TM_WAIT,
	CMD_OUT_TM_READ_FINI_EXEC,
	CMD_OUT_TM_READ_FINI_EXEC_INT,
	CMD_OUT_TM_WRITE_HEAD,
	CMD_OUT_TM_CLEAN
} cmd_out_tm_state_t;

void notifyTaskCompletion(axiStream64_t &tw_stream, ap_uint<64> parent_id) {
	axiData64_t data;
	data.data = 0x8000001000000001; //< See TW Task Manager source. Set bits are: VALID, FINISH TYPE, 1 TASK COUNT
	data.keep = 0xFF;
	data.last = 0;
	data.dest = HWR_TASKWAIT_ID;
	tw_stream.write(data);
	data.data = parent_id;
	data.last = 1;
	tw_stream.write(data);
}

uint8_t getCmdLength(const uint8_t cmdCode, const uint64_t header) {
	uint8_t length = 0;
	if (cmdCode == CMD_EXEC_TASK_CODE) {
		// Execute task
		// NOTE: Not supported here
	} else if (cmdCode == CMD_SETUP_INS_CODE) {
		// Setup instrumentation
		length = 1 /*buffer_address*/;
	} else if (cmdCode == CMD_FINI_EXEC_CODE) {
		// Finished execute task
		// NOTE: The command size in the command out queue is considered here.
		//       The command size in the command out stream is +1 words as it includes the parent task id
		length = 1 /*task_id*/;
	} else if (cmdCode == CMD_PERI_TASK_CODE) {
		// Execute periodic task
		// NOTE: Not supported here
	}
	return length;
}

void Command_Out_wrapper(uint64_t cmdOutQueue[CMD_OUT_QUEUE_SIZE], accAvailability_t accAvailability[MAX_ACCS],
	axiStream64_t &inStream, axiStream64_t &outStream)
{
	#pragma HLS INTERFACE axis port=outStream
	#pragma HLS INTERFACE axis port=inStream
	#pragma HLS INTERFACE bram port=cmdOutQueue
	#pragma HLS INTERFACE bram port=accAvailability
	#pragma HLS RESOURCE variable=accAvailability core=RAM_1P_BRAM
	#pragma HLS INTERFACE ap_ctrl_none port=return

	static ap_uint<CMD_OUT_QUEUE_IDX_BITS> _queueOffset; //< Offset where the current writing subqueue of finshedQueue starts
	static ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> _wIdx[MAX_ACCS]; //< Slot where the current out command starts
	static ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> _rIdx[MAX_ACCS]; //< Slot where the last known read out command starts
	static ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS+1> _availSlots[MAX_ACCS]; //< Number of available slots in the new queue
	static cmd_out_tm_state_t _state = CMD_OUT_TM_RESET; //< Current state
	#pragma HLS RESET variable=_state
	static ap_uint<8> _accId; //< Accelerator ID that is sending the out command
	static ap_uint<8> _cmdCode; //< Out command code
	static uint64_t _cmdHeader; //< Out command header
	static uint8_t _cmdLength; //< Number of words that payload of out command has

	if (_state == CMD_OUT_TM_RESET) {
		//Under reset
		for (size_t i = 0; i < MAX_ACCS; i++) {
		#pragma HLS PIPELINE
			_wIdx[i] = 0;
			_rIdx[i] = 0;
			_availSlots[i] = CMD_OUT_QUEUE_SIZE/MAX_ACCS;
		};
		for (size_t i = 0; i < CMD_OUT_QUEUE_SIZE; i++) {
		#pragma HLS PIPELINE
			cmdOutQueue[i] = 0;
		};

		while (!inStream.empty()) {
			inStream.read();
		}

		_state = CMD_OUT_TM_READ_HEAD;
	} else if (_state == CMD_OUT_TM_READ_HEAD) {
		axiData64_t inPkg;

		// Wait for an out command
		inPkg = inStream.read();
		_cmdHeader = inPkg.data;
		_cmdCode = _cmdHeader&BITS_MASK_8;
		_cmdLength = getCmdLength(_cmdCode, _cmdHeader);
		_accId = inPkg.id;
		_queueOffset = _accId*(CMD_OUT_QUEUE_SIZE/MAX_ACCS);

		accAvailability_t availInfo = accAvailability[_accId];
		_state = availInfo == ACC_AVAIL_FROM_CMDIN ? CMD_OUT_TM_WAIT : CMD_OUT_TM_READ_FINI_EXEC_INT;
	} else if (_state == CMD_OUT_TM_WAIT) {
		//Waiting for enough available slots in cmdOutQueue
		ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> neededSlots = 1 /*header*/ + _cmdLength;
		if (neededSlots <= _availSlots[_accId]) {
			_state = CMD_OUT_TM_READ_FINI_EXEC;
		} else {
			ap_uint<CMD_OUT_QUEUE_IDX_BITS> idx = _queueOffset + _rIdx[_accId];
			const uint64_t head0 = cmdOutQueue[idx];
			if (((head0 >> CMD_OUT_VALID_OFFSET)&BITS_MASK_8) == QUEUE_INVALID) {
				ap_uint<8> cmdCode0 = head0&BITS_MASK_8;
				ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> numSlots0 = 1 /*header*/ + getCmdLength(cmdCode0, head0);
				_availSlots[_accId] += numSlots0;
				_rIdx[_accId] += numSlots0;
			}
		}
	} else if (_state == CMD_OUT_TM_READ_FINI_EXEC) {
		//Read the out command payload: task id
		uint64_t taskId = inStream.read().data;
		ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> subqueueIdx = _wIdx[_accId] + 1 /*header*/;
		ap_uint<CMD_OUT_QUEUE_IDX_BITS> idx = _queueOffset + subqueueIdx;
		cmdOutQueue[idx] = taskId;

		//Read the out command payload: parent task id
		inStream.read();
		//NOTE: If any, the finalization notification to the TW will be sent by the host

		// Mark accelerator as available
		accAvailability[_accId] = ACC_AVAIL_FROM_NONE;

		_state = CMD_OUT_TM_WRITE_HEAD;
	} else if (_state == CMD_OUT_TM_READ_FINI_EXEC_INT) {
		//Read the out command payload: task id
		inStream.read();

		//Read the out command payload: parent task id
		uint64_t parentId = inStream.read().data;
		if (parentId) {
			notifyTaskCompletion(outStream, parentId);
		}

		// Mark accelerator as available
		accAvailability[_accId] = ACC_AVAIL_FROM_NONE;

		_state = CMD_OUT_TM_READ_HEAD;
	} else if (_state == CMD_OUT_TM_WRITE_HEAD) {
		//Write the command header
		ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> subqueueIdx = _wIdx[_accId];
		ap_uint<CMD_OUT_QUEUE_IDX_BITS> idx = _queueOffset + subqueueIdx;

		uint64_t tmp = QUEUE_VALID;
		tmp = (tmp << CMD_OUT_VALID_OFFSET) | _cmdHeader;
		cmdOutQueue[idx] = tmp;

		//Update queue status
		ap_uint<CMD_OUT_SUBQUEUE_IDX_BITS> filledSlots = 1 /*header*/ + _cmdLength;
		_wIdx[_accId] += filledSlots;
		_availSlots[_accId] -= filledSlots;

		_state = CMD_OUT_TM_READ_HEAD;
	}
}
