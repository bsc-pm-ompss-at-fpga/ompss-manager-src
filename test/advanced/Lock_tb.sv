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


module Lock_tb;

    logic clk;
    logic rstn;
    // inStream
    logic [63:0] inStream_TDATA;
    logic inStream_TVALID;
    logic [3:0] inStream_TID;
    logic inStream_TREADY;
    // outStream
    logic [63:0] outStream_TDATA;
    logic outStream_TVALID;
    logic outStream_TREADY;
    logic [3:0] outStream_TDEST;
    logic outStream_TLAST;

    Lock dut(
        .*
    );

    initial begin
        $write("===== Starting test execution =====\n");
        rstn <= 0; //< Start reset
        #10;
        inStream_TVALID <= 0;
        outStream_TREADY <= 0;
        rstn <= 1; //< End reset
        #10;

        // Check initial values
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 after reset");
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reset");
        repeat (2) @(posedge clk);
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 after reset +2 cycles");
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reset +2 cycles");

        // Send lock message for lock_ID 0
        $write("Test: Send lock message for lock_ID 0\n");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 before sending message");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000004;
        inStream_TVALID <= 1;
        repeat (1) @(posedge clk);
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("outStream_TVALID != 1 after sending message");
        assert(outStream_TLAST == 1) else $error("outStream_TLAST != 1 after sending message");
        assert(outStream_TDEST == 0) else $error("outStream_TDEST != 0 after sending message");
        assert(outStream_TDATA == 1) else $error("outStream_TDATA != 1 after sending message");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reading ack message");

        // Send lock message for lock_ID 0
        $write("Test: Send lock message for lock_ID 0 (while locked)\n");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 before sending message");
        inStream_TID <= 1;
        inStream_TDATA <= 64'h0000000000000004;
        inStream_TVALID <= 1;
        repeat (1) @(posedge clk);
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("outStream_TVALID != 1 after sending message");
        assert(outStream_TLAST == 1) else $error("outStream_TLAST != 1 after sending message");
        assert(outStream_TDEST == 1) else $error("outStream_TDEST != 1 after sending message");
        assert(outStream_TDATA == 0) else $error("outStream_TDATA != 0 after sending message");
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reading ack message");

        // Send unlock message for lock_ID 0
        $write("Test: Send unlock message for lock_ID 0\n");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 before sending message");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000006;
        inStream_TVALID <= 1;
        repeat (1) @(posedge clk);
        inStream_TVALID <= 0;
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 after sending message");

        // Send lock message for lock_ID 0
        $write("Test: Send lock message for lock_ID 0 (long ack TREADY)\n");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 before sending message");
        inStream_TID <= 15;
        inStream_TDATA <= 64'h0000000000000004;
        inStream_TVALID <= 1;
        repeat (1) @(posedge clk);
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("outStream_TVALID != 1 after sending message");
        assert(outStream_TLAST == 1) else $error("outStream_TLAST != 1 after sending message");
        assert(outStream_TDEST == 15) else $error("outStream_TDEST != 15 after sending message");
        assert(outStream_TDATA == 1) else $error("outStream_TDATA != 1 after sending message");
        repeat (10) @(posedge clk);
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reading ack message");

        // Send lock message for lock_ID 0
        $write("Test: Send lock message for lock_ID 0 (while locked, long ack TREADY)\n");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 before sending message");
        inStream_TID <= 10;
        inStream_TDATA <= 64'h0000000000000004;
        inStream_TVALID <= 1;
        repeat (1) @(posedge clk);
        inStream_TVALID <= 0;
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 1) else $error("outStream_TVALID != 1 after sending message");
        assert(outStream_TLAST == 1) else $error("outStream_TLAST != 1 after sending message");
        assert(outStream_TDEST == 10) else $error("outStream_TDEST != 10 after sending message");
        assert(outStream_TDATA == 0) else $error("outStream_TDATA != 0 after sending message");
        repeat (10) @(posedge clk);
        outStream_TREADY <= 1;
        repeat (1) @(posedge clk);
        outStream_TREADY <= 0;
        repeat (1) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0 after reading ack message");

        // Send unlock message for lock_ID 0
        $write("Test: Send unlock message for lock_ID 0\n");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 before sending message");
        inStream_TID <= 0;
        inStream_TDATA <= 64'h0000000000000006;
        inStream_TVALID <= 1;
        repeat (1) @(posedge clk);
        inStream_TVALID <= 0;
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0");
        repeat (2) @(posedge clk);
        assert(outStream_TVALID == 0) else $error("outStream_TVALID != 0");
        assert(inStream_TREADY == 1) else $error("inStream_TREADY != 1 after sending message");

        $write("===== End of test execution =====\n");
    end

    always begin
        clk <= 1; #5;
        clk <= 0; #5;
    end

endmodule
