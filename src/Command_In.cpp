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
#define MAX_ACCS              32
#define ACC_IDX_BITS          5    //< log2(MAX_ACCS)
#define BITS_MASK_16          0xFFFF
#define BITS_MASK_8           0xFF
#define CMD_EXEC_TASK_CODE    0x01 ///< Command code for execute task commands
#define CMD_SETUP_INS_CODE    0x02 ///< Command code for setup instrumentation info
#define CMD_FINI_EXEC_CODE    0x03 ///< Command code for finished execute task commands

#define CMD_IN_QUEUE_SIZE              2048
#define CMD_IN_QUEUE_IDX_BITS          11   //< log2(CMD_IN_QUEUE_SIZE)
#define CMD_IN_SUBQUEUE_IDX_BITS       6    //< log2(CMD_IN_QUEUE_SIZE/MAX_ACCS)
#define CMD_IN_VALID_OFFSET            56   //< Offset in bits of valid field
#define CMD_IN_EXECTASK_NUMARGS_OFFSET 8
#define CMD_IN_EXECTASK_ARG_WORDS      2    //< argId+flags,value

#define ACC_AVAIL_FROM_NONE   0x0
#define ACC_AVAIL_FROM_CMDIN  0x1
#define ACC_AVAIL_FROM_INT    0x2

typedef ap_axiu<64,1,8,5> axiData64_t;
typedef hls::stream<axiData64_t> axiStream64_t;
typedef uint64_t accAvailability_t;

void sendCommand(uint64_t volatile *subqueue, ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> offset,
        const uint8_t length, axiStream64_t &outStream, const uint8_t accId)
{
	axiData64_t data;
	data.keep = 0xFF;
	data.dest = accId;
	data.last = 0;

	data.data = subqueue[offset++]; //< cmd header
	outStream.write(data);

	sendCommandToAccelerator:
	for (uint8_t i = 0; i < length; i++) {
	#pragma HLS PIPELINE
		data.last = ((i + 1) == length);
		data.data = subqueue[offset];
		outStream.write(data);
		// Clean the queue word
		subqueue[offset++] = 0;
	}
}

void compareAndSendTask(uint64_t volatile *subqueue, ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> offset,
		ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> next_offset, const uint8_t length, axiStream64_t &outStream, const uint8_t accId)
{
	uint64_t currentTask[256], nextTask[256];
	ap_uint<64> arg[2], next_arg[2];
	axiData64_t data;
	uint8_t i = 0;
	data.keep = 0xFF;
	data.dest = accId;
	data.last = 0;

	data.data = subqueue[offset++]; //< cmd header
	outStream.write(data);

	next_offset++;

	readTaskFromQueue:
	for (uint8_t i = 0; i < length; i++) {
	#pragma HLS PIPELINE
		currentTask[i] = subqueue[ap_uint<CMD_IN_SUBQUEUE_IDX_BITS>(offset + i)];
	}

	sendTaskHeaderToAccelerator:
	for (; i < 2; i++) {
	#pragma HLS PIPELINE
		data.data = currentTask[i];
		outStream.write(data);
	}

	compareAndSendTaskToAccelerator:
	for (; i < length; i += 2) {
	#pragma HLS PIPELINE

		arg[0] = currentTask[i];
		arg[1] = currentTask[i + 1];

		next_arg[1] = subqueue[ap_uint<CMD_IN_SUBQUEUE_IDX_BITS>(next_offset + i + 1)];

		if (arg[1] == next_arg[1]) {
			next_arg[0] = subqueue[ap_uint<CMD_IN_SUBQUEUE_IDX_BITS>(next_offset + i)];
			ap_uint<1> copyFlag_bit = next_arg[0].range(4,4) & !arg[0].range(7,7) & !arg[0].range(4,4);
			next_arg[0].range(7,7) = !copyFlag_bit & next_arg[0].range(4,4);
			next_arg[0].range(4,4) = copyFlag_bit;
			//arg[0].range(5,5) = arg[0].range(5,5) & !next_arg[0].range(5,5);

			subqueue[ap_uint<CMD_IN_SUBQUEUE_IDX_BITS>(next_offset + i)] = next_arg[0];
		}

		data.data = arg[0];
		outStream.write(data);

		data.data = arg[1];
		data.last = ((i + 2) == length);
		outStream.write(data);
	}

	invalidateTaskOnQueue:
	for (uint8_t i = 0; i < length; i++) {
	#pragma HLS PIPELINE
		subqueue[offset++] = 0;
	}

}

uint8_t getCmdLength(const uint8_t cmdCode, const uint64_t header) {
	uint8_t length = 0;
	if (cmdCode == CMD_EXEC_TASK_CODE) {
		// Execute task
		const uint8_t numArgs = (header >> CMD_IN_EXECTASK_NUMARGS_OFFSET)&BITS_MASK_8;
		length = 2 /*parent_id + task_id*/ + CMD_IN_EXECTASK_ARG_WORDS*numArgs;
	} else if (cmdCode == CMD_SETUP_INS_CODE) {
		// Setup instrumentation
		length = 1 /*buffer_address*/;
	} else if (cmdCode == CMD_FINI_EXEC_CODE) {
		// Finished execute task
		// NOTE: The command size in the command out queue is considered here.
		//       The command size in the command out stream is +1 words as it includes the parent task id
		length = 1 /*task_id*/;
	}
	return length;
}

void Command_In_wrapper(uint64_t cmdInQueue[CMD_IN_QUEUE_SIZE], uint64_t intCmdInQueue[CMD_IN_QUEUE_SIZE],
	accAvailability_t accAvailability[MAX_ACCS], axiStream64_t &outStream)
{
	#pragma HLS INTERFACE bram port=intCmdInQueue
	#pragma HLS RESOURCE variable=intCmdInQueue core=RAM_1P_BRAM
	#pragma HLS INTERFACE axis port=outStream
	#pragma HLS INTERFACE bram port=cmdInQueue
	#pragma HLS INTERFACE bram port=accAvailability
	#pragma HLS RESOURCE variable=accAvailability core=RAM_1P_BRAM
	#pragma HLS INTERFACE ap_ctrl_none port=return

	ap_uint<CMD_IN_QUEUE_IDX_BITS> queue_offset;
	ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> subqueue_offset, next_subqueue_offset;
	uint64_t word, next_word, invalidateMask;
	uint8_t cmdLength;
	ap_uint<8> cmdCode, next_cmdCode;
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> cmdInQueue_index[MAX_ACCS] = {0};
	#pragma HLS RESET variable=cmdInQueue_index
	static ap_uint<CMD_IN_SUBQUEUE_IDX_BITS> intCmdInQueue_index[MAX_ACCS] = {0};
	#pragma HLS RESET variable=intCmdInQueue_index
	static ap_uint<ACC_IDX_BITS> accId = 0;
	#pragma HLS RESET variable=accId
	static ap_uint<1> doCleanup = 1;
	#pragma HLS RESET variable=doCleanup

	if (doCleanup) {
		doCleanup = 0;

		accAvailability[0] = ACC_AVAIL_FROM_NONE;
		for (accId = 1; accId != 0; accId++) {
		#pragma HLS PIPELINE
			accAvailability[accId] = ACC_AVAIL_FROM_NONE;
		}
	}

	// Check if accelerator is available to receive a command
	if (accAvailability[accId] == ACC_AVAIL_FROM_NONE) {
		queue_offset = accId*(CMD_IN_QUEUE_SIZE/MAX_ACCS);

		// Check cmdInQueue
		subqueue_offset = cmdInQueue_index[accId];
		word = cmdInQueue[queue_offset + subqueue_offset];
		if (((word >> CMD_IN_VALID_OFFSET)&BITS_MASK_8) == QUEUE_VALID) {
			cmdCode = word&BITS_MASK_8;

			// Mark accelerator as busy if the command requires it
			if (cmdCode.get_bit(0) == 1) {
				accAvailability[accId] = ACC_AVAIL_FROM_CMDIN;
			}

			// Send command to accelerator
			cmdLength = getCmdLength(cmdCode, word);

			// Execute Task command
			if (cmdCode == CMD_EXEC_TASK_CODE) {
				next_subqueue_offset = subqueue_offset + 1 /*command header*/ + cmdLength;
				next_word = cmdInQueue[queue_offset + next_subqueue_offset];
				if (((next_word >> CMD_IN_VALID_OFFSET)&BITS_MASK_8) == QUEUE_VALID) {
					next_cmdCode = next_word&BITS_MASK_8;
					if (next_cmdCode == CMD_EXEC_TASK_CODE) {
						compareAndSendTask(&cmdInQueue[queue_offset], subqueue_offset, next_subqueue_offset, cmdLength, outStream, accId);
					} else {
						sendCommand(&cmdInQueue[queue_offset], subqueue_offset, cmdLength, outStream, accId);
					}
				} else {
					sendCommand(&cmdInQueue[queue_offset], subqueue_offset, cmdLength, outStream, accId);
				}
			} else {
				sendCommand(&cmdInQueue[queue_offset], subqueue_offset, cmdLength, outStream, accId);
			}

			//NOTE: The head word cannot be set to 0, we must just clean the valid bits.
			invalidateMask = BITS_MASK_8;
			invalidateMask = ~(invalidateMask << CMD_IN_VALID_OFFSET);
			word &= invalidateMask;
			cmdInQueue[queue_offset + subqueue_offset] = word;

			// Set next header idx
			cmdInQueue_index[accId] = subqueue_offset + 1 /*command header*/ + cmdLength;
		} else {
			// Check intCmdInQueue
			subqueue_offset = intCmdInQueue_index[accId];
			word = intCmdInQueue[queue_offset + subqueue_offset];
			if (((word >> CMD_IN_VALID_OFFSET)&BITS_MASK_8) == QUEUE_VALID) {
				cmdCode = word&BITS_MASK_8;

				// Mark accelerator as busy if the command requires it
				if (cmdCode.get_bit(0) == 1) {
					accAvailability[accId] = ACC_AVAIL_FROM_INT;
				}

				// Send command to accelerator
				cmdLength = getCmdLength(cmdCode, word);
				sendCommand(&intCmdInQueue[queue_offset], subqueue_offset, cmdLength, outStream, accId);

				//NOTE: The head word cannot be set to 0, we must just clean the valid bits.
				invalidateMask = BITS_MASK_8;
				invalidateMask = ~(invalidateMask << CMD_IN_VALID_OFFSET);
				word &= invalidateMask;
				intCmdInQueue[queue_offset + subqueue_offset] = word;

				// Set next header idx
				intCmdInQueue_index[accId] = subqueue_offset + 1 /*command header*/ + cmdLength;
			}
		}

	}
	accId++;
}
