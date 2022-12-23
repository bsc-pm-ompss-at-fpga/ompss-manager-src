/*--------------------------------------------------------------------
  Copyright (C) Barcelona Supercomputing Center
                Centro Nacional de Supercomputacion (BSC-CNS)

  All Rights Reserved.
  This file is part of OmpSs@FPGA toolchain.

  Unauthorized copying and/or distribution of this file,
  via any medium is strictly prohibited.
  The intellectual and technical concepts contained herein are
  propietary to BSC-CNS and may be covered by Patents.
--------------------------------------------------------------------*/


module Scheduler_spawnout_tb;
    localparam SPAWNOUT_QUEUE_LEN = 1024;
    localparam ARCHBITS_BITS = 2;
    localparam TASKTYPE_BITS = 32;

    logic clk;
    logic rstn;
    //Spawn out queue
    logic [31:0] spawnout_queue_addr;
    logic spawnout_queue_en;
    logic [7:0] spawnout_queue_we;
    logic [63:0] spawnout_queue_din;
    logic [63:0] spawnout_queue_dout;
    //inStream
    logic inStream_TVALID;
    logic inStream_spawnout_TREADY;
    //Other signals
    logic [63:0] taskID;
    logic [63:0] pTaskID;
    logic [TASKTYPE_BITS-1:0] task_type;
    logic [ARCHBITS_BITS-1:0] task_arch;
    logic [3:0] num_args;
    logic [3:0] num_cops;
    logic [3:0] num_deps;
    logic [63:0] inStream_data_buf;
    logic inStream_last_buf;
    logic spawnout_state_start;
    logic [1:0] spawnout_ret; //0 wait, 1 ok, 2 reject

    Scheduler_spawnout #(
        .QUEUE_LEN(SPAWNOUT_QUEUE_LEN),
        .ARCHBITS_BITS(ARCHBITS_BITS),
        .TASKTYPE_BITS(TASKTYPE_BITS)
    ) dut (
        .*
    );

    initial begin
        $write("===== Starting test execution =====\n");
        rstn <= 0; //< Start reset
        #10;
        spawnout_queue_dout <= 64'hDDEEAADDBBEEFF;
        inStream_TVALID <= 0;
        spawnout_state_start <= 0;
        rstn <= 1; //< End reset
        repeat (1) @(posedge clk);

        // Check initial values
        assert(spawnout_queue_en == 0) else $error("spawnout_queue_en != 0 after reset");
        //assert(spawnout_queue_we == 0) else $error("spawnout_queue_we != 0 after reset");
        assert(spawnout_ret == 0) else $error("spawnout_ret != 0 after reset");
        repeat (2) @(posedge clk);
        assert(spawnout_queue_en == 0) else $error("spawnout_queue_en != 0 after reset");
        //assert(spawnout_queue_we == 0) else $error("spawnout_queue_we != 0 after reset");
        assert(spawnout_ret == 0) else $error("spawnout_ret != 0 after reset");

        $write("Test 1: Send task 0 args, 0 deps, 0 copies\n");
        //SPAWNOUT_IDLE
        taskID <= 64'h1234567887654321;
        pTaskID <= 64'h8765432112345678;
        task_type <= 32'h11223344;
        task_arch <= 2'h3;
        num_args <= 0;
        num_cops <= 0;
        num_deps <= 0;
        spawnout_state_start <= 1;
        repeat (1) @(posedge clk);
        //SPAWNOUT_IDLE
        repeat (1) @(posedge clk);
        //SPAWNOUT_CHECK
        spawnout_state_start <= 0;
        repeat (1) @(posedge clk);
        //SPAWNOUT_WRITE_TASKID
        assert(spawnout_queue_en == 1) else $error("Test 1.3: spawnout_queue_en");
        assert(spawnout_queue_we == 8'hFF) else $error("Test 1.3: spawnout_queue_we");
        assert(spawnout_queue_addr == 32'h00000008) else $error("Test 1.3: spawnout_queue_addr");
        assert(spawnout_queue_din == 64'h1234567887654321) else $error("Test 1.3: spawnout_queue_din");
        repeat (1) @(posedge clk);
        //SPAWNOUT_WRITE_PTASKID
        assert(spawnout_queue_en == 1) else $error("Test 1.4: spawnout_queue_en");
        assert(spawnout_queue_we == 8'hFF) else $error("Test 1.4: spawnout_queue_we");
        assert(spawnout_queue_addr == 32'h00000010) else $error("Test 1.4: spawnout_queue_addr");
        assert(spawnout_queue_din == 64'h8765432112345678) else $error("Test 1.4: spawnout_queue_din");
        repeat (1) @(posedge clk);
        //SPAWNOUT_WRITE_TASKTYPE
        assert(spawnout_queue_en == 1) else $error("Test 1.5: spawnout_queue_en");
        assert(spawnout_queue_we == 8'hFF) else $error("Test 1.5: spawnout_queue_we");
        assert(spawnout_queue_addr == 32'h00000018) else $error("Test 1.5: spawnout_queue_addr");
        assert(spawnout_queue_din == 64'h0000000311223344) else $error("Test 1.5: spawnout_queue_din");
        repeat (1) @(posedge clk);
        //SPAWNOUT_WRITE_TASKTYPE
        assert(spawnout_queue_en == 1) else $error("Test 1.6: spawnout_queue_en");
        assert(spawnout_queue_we == 8'hFF) else $error("Test 1.6: spawnout_queue_we");
        assert(spawnout_queue_addr == 32'h00000000) else $error("Test 1.6: spawnout_queue_addr");
        assert(spawnout_queue_din[63:63] == 1'h1) else $error("Test 1.6: spawnout_queue_din.valid");
        assert(spawnout_queue_din[31:24] == 8'h00) else $error("Test 1.6: spawnout_queue_din.#Copies");
        assert(spawnout_queue_din[23:16] == 8'h00) else $error("Test 1.6: spawnout_queue_din.#Deps");
        assert(spawnout_queue_din[15:8] == 8'h00) else $error("Test 1.6: spawnout_queue_din.#Args");
        repeat (1) @(posedge clk);
        //SPAWNOUT_IDLE
        assert(spawnout_ret == 1) else $error("Test 1.6: spawnout_ret");

        $write("===== End of test execution =====\n");
    end

    always begin
        clk <= 1; #5;
        clk <= 0; #5;
    end

endmodule
