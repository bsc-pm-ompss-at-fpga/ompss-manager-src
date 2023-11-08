/*-------------------------------------------------------------------------*/
/*  Copyright (C) 2020-2023 Barcelona Supercomputing Center                */
/*                  Centro Nacional de Supercomputacion (BSC-CNS)          */
/*                                                                         */
/*  This file is part of OmpSs@FPGA toolchain.                             */
/*                                                                         */
/*  This program is free software: you can redistribute it and/or modify   */
/*  it under the terms of the GNU General Public License as published      */
/*  by the Free Software Foundation, either version 3 of the License,      */
/*  or (at your option) any later version.                                 */
/*                                                                         */
/*  This program is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                   */
/*  See the GNU General Public License for more details.                   */
/*                                                                         */
/*  You should have received a copy of the GNU General Public License      */
/*  along with this program. If not, see <https://www.gnu.org/licenses/>.  */
/*-------------------------------------------------------------------------*/

interface GenAxis #(
    parameter DATA_WIDTH = 32,
    parameter ID_WIDTH = 8,
    parameter DEST_WIDTH = 8
);

    logic valid;
    logic ready;
    logic [DATA_WIDTH-1:0] data;
    logic [ID_WIDTH-1:0] id;
    logic [DEST_WIDTH-1:0] dest;
    logic last;

    modport slave(input valid, output ready, input data, input id, input dest, input last);
    modport master(output valid, input ready, output data, output id, output dest, output last);
    modport observer(input valid, input ready, input data, input id, input dest, input last);

endinterface

interface MemoryPort32 #(parameter WIDTH = 32);
    logic en;
    logic [WIDTH/8 - 1: 0] wr;
    logic [31:0] addr;
    logic [WIDTH-1:0] din;
    logic [WIDTH-1:0] dout;

    modport master (output en, output wr, output addr, output din, input dout);
endinterface

package Glb;

    typedef struct {
        bit [7:0] code;
        bit [63:0] tid;
        bit [7:0] comp;
        bit [7:0] nArgs;
        bit [7:0] argFlags[15];
        bit [63:0] args[15];
        bit finished;
        int acc_id;
        int period;
        int repetitions;
    } Command;
    Command commands[];

    bit [63:0] argPool[];

    int creationGraph[];

    typedef struct {
        bit [31:0] taskType;
        bit [7:0] nArgs;
        bit [7:0] nDeps;
        bit [7:0] nCops;
        bit [7:0] depDirs[15];
        bit [7:0] copDirs[15];
        bit [7:0] copArgIdx[15];
        bit [7:0] argCopIdx[15];
        int numInstances;
    } AccType;

    AccType accTypes[];
    int accId2accType[];

    typedef struct {
        int acc_id;
        bit [7:0] nArgs;
        bit [7:0] nDeps;
        bit [7:0] nCops;
        bit [63:0] pTid;
        bit [7:0] insNum;
        bit [31:0] taskType;
        bit [63:0] deps[15];
        bit [63:0] args[15];
        bit [63:0] copyAddr[15];
        bit [31:0] copySize[15];
        bit [7:0] copyFlag[15];
        bit [7:0] copyArgIdx[15];
        bit smp;
        enum {
            NTASK_CREATED,
            NTASK_READY
        } state;
    } NewTask;

    NewTask newTasks[];
    int maxNewTasks;
    int newTaskIdx;

    longint random_seed;

    int pom;

endpackage
