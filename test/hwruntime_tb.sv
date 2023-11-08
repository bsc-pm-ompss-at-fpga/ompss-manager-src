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

module connect_gen_axis (
    GenAxis.master m,
    GenAxis.slave s
);

    assign m.valid = s.valid;
    assign s.ready = m.ready;
    assign m.data = s.data;
    assign m.id = s.id;
    assign m.dest = s.dest;
    assign m.last = s.last;

endmodule

`ifndef CREATOR_GRAPH_PATH_D
`define CREATOR_GRAPH_PATH_D ""
`endif
`ifndef TASKTYPE_FILE_PATH_D
`define TASKTYPE_FILE_PATH_D ""
`endif

module hwruntime_tb #(
    parameter NUM_ACCS = 0,
    parameter NUM_CMDS = 0,
    parameter MAX_NEW_TASKS = 0,
    parameter NUM_CREATORS = 0,
    parameter NUM_ACC_TYPES = 0,
    parameter [NUM_ACC_TYPES*8-1:0] SCHED_COUNT = 0,
    parameter [NUM_ACC_TYPES*8-1:0] SCHED_ACCID = 0,
    parameter [NUM_ACC_TYPES*32-1:0] SCHED_TTYPE = 0
) ();

    import Glb::*;

    localparam CREATOR_GRAPH_PATH = `CREATOR_GRAPH_PATH_D;
    localparam TASKTYPE_FILE_PATH = `TASKTYPE_FILE_PATH_D;
    localparam ACC_BITS = $clog2(NUM_ACCS) == 0 ? 1 : $clog2(NUM_ACCS);
    localparam CMDIN_SUBQUEUE_LEN = 64;
    localparam CMDOUT_SUBQUEUE_LEN = 64;

    reg clk;
    reg rst;
    int totalTasks;
    int finished_cmds;
    int cycleCount;

    MemoryPort32 #(.WIDTH(64)) cmdinPortA();
    MemoryPort32 #(.WIDTH(64)) cmdoutPortA();
    MemoryPort32 #(.WIDTH(64)) spawninPortA();
    MemoryPort32 #(.WIDTH(64)) spawnoutPortA();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) cmdin();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) cmdout();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) spawn_out();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(2)) spawn_in();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) taskwait_out();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) taskwait_in();
    int tasktype, numinstances;

    initial begin
        int i, j, k, num_period_accs, dir, copArgIdx;
        reg accPeriodic[NUM_ACCS];
        int perioAccs[NUM_ACCS];
        int reachableCreators[NUM_CREATORS == 0 ? 1 : NUM_CREATORS];
        int aux, fd, accTypeIdx;
        clk = 0;
        rst = 1;
        cycleCount = 0;
        random_seed = 0;
        if ($value$plusargs("sim_seed=%d", random_seed)) begin
            $display("Found seed %0d", random_seed);
        end

        if (NUM_CREATORS > 0) begin
            newTasks = new[MAX_NEW_TASKS+NUM_CREATORS+2];
            newTaskIdx = 0;
            maxNewTasks = MAX_NEW_TASKS;
        end

        // This graph represents the levels of nesting of the application, all accelerators at the top level are managed by the
        // simulator, the others receive tasks created by its parents
        if (NUM_CREATORS > 0) begin
            creationGraph = new[NUM_CREATORS*NUM_ACC_TYPES];
        end
        fd = $fopen(CREATOR_GRAPH_PATH, "r");
        if (!fd) begin
            $error("Could not open file %s", CREATOR_GRAPH_PATH); $fatal;
        end
        for (i = 0; i < NUM_CREATORS; i = i+1) begin
            for (j = 0; j < NUM_ACC_TYPES; j = j+1) begin
                aux = $fscanf(fd, "%d", creationGraph[i*NUM_ACC_TYPES + j]);
            end
        end
        $fclose(fd);

        accTypes = new[NUM_ACC_TYPES];
        accId2accType = new[NUM_ACCS];
        fd = $fopen(TASKTYPE_FILE_PATH, "r");
        if (!fd) begin
            $error("Could not open file %s", TASKTYPE_FILE_PATH); $fatal;
        end
        accTypeIdx = 0;
        for (i = 0; i < NUM_ACC_TYPES; i = i+1) begin
            aux = $fscanf(fd, "%d %d", accTypes[i].taskType, accTypes[i].numInstances);
            accTypes[i].nArgs = $urandom_range(NUM_CREATORS == 0 ? 0 : 1, 15); //We need one argument to store the index of a new task
            accTypes[i].nDeps = $urandom_range(8);
            accTypes[i].nCops = accTypes[i].nArgs > 0 ? $urandom_range(accTypes[i].nArgs) : 0; //A copy is associated to an argument
            for (j = accTypeIdx; j < accTypeIdx+accTypes[i].numInstances; j = j+1) begin
                accId2accType[j] = i;
            end
            accTypeIdx = accTypeIdx + accTypes[i].numInstances;
            for (j = 0; j < accTypes[i].nDeps; j = j+1) begin
                dir = $urandom_range(2);
                if (dir == 0) begin
                    accTypes[i].depDirs[j] = 8'h04;
                end else if (dir == 1) begin
                    accTypes[i].depDirs[j] = 8'h08;
                end else begin
                    accTypes[i].depDirs[j] = 8'h0C;
                end
            end
            for (j = 0; j < 15; j = j+1) begin
                accTypes[i].argCopIdx[j] = 8'hFF;
            end
            for (j = 0; j < accTypes[i].nCops; j = j+1) begin
                dir = $urandom_range(3);
                do begin
                    //$urandom is not uniform in the tested Vivado versions
                    //$random should be uniform following the SystemVerilog standard
                    copArgIdx = {$random(random_seed)}%accTypes[i].nArgs;
                    aux = 0;
                    for (k = 0; k < j; k = k+1) begin
                        if (accTypes[i].copArgIdx[k] == copArgIdx) begin
                            aux = 1;
                            break;
                        end
                    end
                end while(aux);
                accTypes[i].copArgIdx[j] = copArgIdx;
                accTypes[i].argCopIdx[copArgIdx] = j;
                if (dir == 0) begin
                    accTypes[i].copDirs[j] = 8'h00;
                end else if (dir == 1) begin
                    accTypes[i].copDirs[j] = 8'h01;
                end else if (dir == 2) begin
                    accTypes[i].copDirs[j] = 8'h02;
                end else begin
                    accTypes[i].copDirs[j] = 8'h03;
                end
            end
        end
        $fclose(fd);

        for (i = 0; i < NUM_ACCS; i = i+1) begin
            accPeriodic[i] = 0;
        end
        //FIXME: For the moment I don't want to test periodic tasks with fpga creation because they can only be created from the SMP (I think?)
        if (NUM_CREATORS == 0) begin
            num_period_accs = $urandom_range(NUM_ACCS/5);
            num_period_accs = num_period_accs == 0 ? 1 : num_period_accs; // min 1 periodic accelerator
            for (i = 0; i < num_period_accs; i = i+1) begin
                do begin
                    j = {$random(random_seed)}%NUM_ACCS;
                end while(accPeriodic[j]);
                accPeriodic[j] = 1;
            end
        end
        argPool = new[32];
        for (i = 0; i < argPool.size(); i = i+1) begin
            //FIXME: all args should be different
            argPool[i] = {$urandom, $urandom};
        end
        for (i = 0; i < NUM_CREATORS; i = i+1) begin
            reachableCreators[i] = 0;
        end
        for (i = 0; i < NUM_CREATORS; i = i+1) begin
            for (j = 0; j < NUM_CREATORS; j = j+1) begin
                if (creationGraph[i*NUM_ACC_TYPES + j]) begin
                    reachableCreators[j] = 1;
                end
            end
        end
        totalTasks = 0;
        commands = new[NUM_CMDS];
        for (i = 0; i < NUM_CMDS; i = i+1) begin
            if (NUM_CREATORS == 0) begin
                commands[i].acc_id = $urandom_range(NUM_ACCS-1);
            end else begin
                do begin
                    // Only create commands for creators that can't be initiated by any other creator
                    commands[i].acc_id = {$random(random_seed)}%NUM_CREATORS;
                end while (reachableCreators[commands[i].acc_id]);
            end
            commands[i].tid[31:0] = $urandom;
            commands[i].tid[63:56] = 8'd0;
            commands[i].tid[55:32] = i;
            j = $urandom_range(100);
            if (j < 5 && i < NUM_CMDS-1) begin //Last command must block to be able to detect simulation finalization in time
                commands[i].code = OmpSsManager::SETUP_HW_INST_CODE;
                commands[i].period[23:0] = $urandom; //Number of slots
                commands[i].period[31:24] = 0;
            end else begin
                totalTasks = totalTasks+1;
                if (accPeriodic[commands[i].acc_id]) begin
                    commands[i].code = OmpSsManager::EXEC_PERI_TASK_CODE;
                    commands[i].period = $urandom;
                    commands[i].repetitions = $urandom;
                end else begin
                    commands[i].code = OmpSsManager::EXEC_TASK_CODE;
                end
                commands[i].nArgs = accTypes[accId2accType[commands[i].acc_id]].nArgs;
                commands[i].comp = $urandom_range(1);
                commands[i].finished = 0;
                for (j = 0; j < commands[i].nArgs; j = j+1) begin
                    commands[i].args[j] = argPool[$urandom_range(argPool.size()-1)];
                    commands[i].argFlags[j][7:4] = 4'h0 | $urandom_range(3);
                    commands[i].argFlags[j][3:0] = 4'h0 | $urandom_range(3);
                end
            end
        end
        #200
        rst = 0;
    end

    always begin
        #1
        clk = !clk;
    end

    always @(posedge clk) begin
        cycleCount = cycleCount+1;
        if (cycleCount == 1e6) begin
            $error("Reached cycle limit"); $fatal;
        end
    end

    always @(finished_cmds) begin
        if (finished_cmds == totalTasks) begin
            $finish;
        end
    end

    wire rstn;
    wire taskwait_in_tvalid;
    wire taskwait_in_tready;
    wire [ACC_BITS-1:0] taskwait_in_tid;
    wire [63:0] taskwait_in_tdata;
    wire taskwait_in_tlast;
    wire taskwait_out_tvalid;
    wire taskwait_out_tready;
    wire [ACC_BITS-1:0] taskwait_out_tdest;
    wire [63:0] taskwait_out_tdata;
    wire taskwait_out_tlast;
    wire spawn_in_tvalid;
    wire spawn_in_tready;
    wire [ACC_BITS-1:0] spawn_in_tid;
    wire [63:0] spawn_in_tdata;
    wire spawn_in_tlast;
    wire spawn_out_tvalid;
    wire spawn_out_tready;
    wire [ACC_BITS-1:0] spawn_out_tdest;
    wire [63:0] spawn_out_tdata;
    wire spawn_out_tlast;
    wire lock_in_tvalid;
    wire lock_in_tready;
    wire [ACC_BITS-1:0] lock_in_tid;
    wire [63:0] lock_in_tdata;
    wire lock_out_tvalid;
    wire lock_out_tready;
    wire [ACC_BITS-1:0] lock_out_tdest;
    wire [63:0] lock_out_tdata;
    wire lock_out_tlast;
    wire cmdout_in_tvalid;
    wire cmdout_in_tready;
    wire [ACC_BITS-1:0] cmdout_in_tid;
    wire [63:0] cmdout_in_tdata;
    wire cmdin_out_tvalid;
    wire cmdin_out_tready;
    wire [ACC_BITS-1:0] cmdin_out_tdest;
    wire [63:0] cmdin_out_tdata;
    wire cmdin_out_tlast;
    wire spawnin_queue_clk;
    wire spawnin_queue_rst;
    wire spawnin_queue_en;
    wire [7:0] spawnin_queue_we;
    wire [31:0] spawnin_queue_addr;
    wire [63:0] spawnin_queue_din;
    wire [63:0] spawnin_queue_dout;
    wire spawnout_queue_clk;
    wire spawnout_queue_rst;
    wire spawnout_queue_en;
    wire [7:0] spawnout_queue_we;
    wire [31:0] spawnout_queue_addr;
    wire [63:0] spawnout_queue_din;
    wire [63:0] spawnout_queue_dout;
    wire cmdin_queue_clk;
    wire cmdin_queue_rst;
    wire cmdin_queue_en;
    wire [7:0] cmdin_queue_we;
    wire [31:0] cmdin_queue_addr;
    wire [63:0] cmdin_queue_din;
    wire [63:0] cmdin_queue_dout;
    wire cmdout_queue_clk;
    wire cmdout_queue_rst;
    wire cmdout_queue_en;
    wire [7:0] cmdout_queue_we;
    wire [31:0] cmdout_queue_addr;
    wire [63:0] cmdout_queue_din;
    wire [63:0] cmdout_queue_dout;
    wire axilite_arvalid;
    wire axilite_arready;
    wire [13:0] axilite_araddr;
    wire [2:0] axilite_arprot;
    wire axilite_rvalid;
    wire axilite_rready;
    wire [31:0] axilite_rdata;
    wire [1:0] axilite_rresp;
    wire axilite_awvalid;
    wire axilite_awready;
    wire [13:0] axilite_awaddr;
    wire [2:0] axilite_awprot;
    wire axilite_wvalid;
    wire axilite_wready;
    wire [31:0] axilite_wdata;
    wire [3:0] axilite_wstrb;
    wire axilite_bvalid;
    wire axilite_bready;
    wire [1:0] axilite_bresp;

    assign axilite_arvalid = 1'b0;
    assign axilite_araddr = 14'd0;
    assign axilite_arprot = 3'd0;
    assign axilite_rready = 1'b0;
    assign axilite_awvalid = 1'b0;
    assign axilite_awaddr = 14'd0;
    assign axilite_awprot = 3'd0;
    assign axilite_wvalid = 1'b0;
    assign axilite_wdata = 32'd0;
    assign axilite_wstrb = 4'd0;
    assign axilite_bready = 1'b0;

    assign rstn = !rst;
    assign lock_in_tvalid = 0;
    assign lock_out_tready = 1;
    assign cmdin.valid = cmdin_out_tvalid;
    assign cmdin_out_tready = cmdin.ready;
    assign cmdin.data = cmdin_out_tdata;
    assign cmdin.dest = cmdin_out_tdest;
    assign cmdin.last = cmdin_out_tlast;
    assign cmdout_in_tvalid = cmdout.valid;
    assign cmdout.ready = cmdout_in_tready;
    assign cmdout_in_tdata = cmdout.data;
    assign cmdout_in_tid = cmdout.id;
    assign taskwait_in_tvalid = taskwait_in.valid;
    assign taskwait_in.ready = taskwait_in_tready;
    assign taskwait_in_tid = taskwait_in.id;
    assign taskwait_in_tdata = taskwait_in.data;
    assign taskwait_in_tlast = taskwait_in.last;
    assign taskwait_out.valid = taskwait_out_tvalid;
    assign taskwait_out_tready = taskwait_out.ready;
    assign taskwait_out.dest = taskwait_out_tdest;
    assign taskwait_out.data = taskwait_out_tdata;
    assign taskwait_out.last = taskwait_out_tlast;
    assign spawn_in_tvalid = spawn_in.valid;
    assign spawn_in.ready = spawn_in_tready;
    assign spawn_in_tid = spawn_in.id;
    assign spawn_in_tdata = spawn_in.data;
    assign spawn_in_tlast = spawn_in.last;
    assign spawn_out.valid = spawn_out_tvalid;
    assign spawn_out_tready = spawn_out.ready;
    assign spawn_out.dest = spawn_out_tdest;
    assign spawn_out.data = spawn_out_tdata;
    assign spawn_out.last = spawn_out_tlast;

    PicosOmpSsManager_wrapper #(
        .MAX_ACCS(NUM_ACCS == 1 ? 2:NUM_ACCS),
        .MAX_ACC_CREATORS(NUM_CREATORS <= 1 ? 2:NUM_CREATORS),
        .MAX_ACC_TYPES(NUM_ACC_TYPES == 1 ? 2:NUM_ACC_TYPES),
        .CMDIN_SUBQUEUE_LEN(CMDIN_SUBQUEUE_LEN),
        .CMDOUT_SUBQUEUE_LEN(CMDOUT_SUBQUEUE_LEN),
        .ENABLE_SPAWN_QUEUES(NUM_CREATORS != 0),
        .ENABLE_TASK_CREATION(NUM_CREATORS != 0),
        .ENABLE_DEPS(NUM_CREATORS != 0),
        .SCHED_COUNT(SCHED_COUNT),
        .SCHED_ACCID(SCHED_ACCID),
        .SCHED_TTYPE(SCHED_TTYPE)
    ) POM_I (
        .*
    );

    cmdin_sim #(
        .NUM_ACCS(NUM_ACCS),
        .NUM_CMDS(NUM_CMDS)
    ) cmdin_sim_I (
        .clk(clk),
        .cmdinPort(cmdinPortA)
    );

    cmdout_sim #(
        .NUM_ACCS(NUM_ACCS)
    ) cmdout_sim_I (
        .clk(clk),
        .rst(rst),
        .cmdoutPort(cmdoutPortA),
        .finished_cmds(finished_cmds)
    );

    spawn_sim #(
        .MAX_ACC_CREATORS(NUM_CREATORS <= 1 ? 2 : NUM_CREATORS)
    ) SPAWN_SIM_I (
        .clk(clk),
        .rst(rst),
        .spawnin(spawninPortA),
        .spawnout(spawnoutPortA)
    );

    cmdin_acc_check #(
        .NUM_ACCS(NUM_ACCS),
        .MAX_ACC_CREATORS(NUM_CREATORS <= 1 ? 2:NUM_CREATORS)
    ) cmdin_acc_check_I (
        .clk(clk),
        .rst(rst),
        .cmdin(cmdin)
    );

    acc_inter #(
        .NUM_ACCS(NUM_ACCS == 1 ? 2:NUM_ACCS),
        .NUM_CREATORS(NUM_CREATORS)
    ) ACC_INTER_I (
        .clk(clk),
        .rst(rst),
        .cmdin(cmdin),
        .cmdout(cmdout),
        .spawn_in(spawn_out),
        .spawn_out(spawn_in),
        .taskwait_in(taskwait_out),
        .taskwait_out(taskwait_in)
    );

    dual_port_32_bit_mem_wrapper #(
        .WIDTH(64),
        .SIZE((NUM_ACCS == 1 ? 2 : NUM_ACCS)*CMDIN_SUBQUEUE_LEN),
        .EN_RST_A(0),
        .EN_RST_B(1)
    ) cmdin_queue (
        .rst(rst),
        .clkA(clk),
        .dinA(cmdinPortA.din),
        .addrA(cmdinPortA.addr),
        .doutA(cmdinPortA.dout),
        .enA(cmdinPortA.en),
        .weA(cmdinPortA.wr),
        .clkB(cmdin_queue_clk),
        .rstB(cmdin_queue_rst),
        .dinB(cmdin_queue_din),
        .addrB(cmdin_queue_addr),
        .doutB(cmdin_queue_dout),
        .enB(cmdin_queue_en),
        .weB(cmdin_queue_we)
    );

    dual_port_32_bit_mem_wrapper #(
        .WIDTH(64),
        .SIZE((NUM_ACCS == 1 ? 2 : NUM_ACCS)*CMDOUT_SUBQUEUE_LEN),
        .EN_RST_A(0),
        .EN_RST_B(1)
    ) cmdout_queue (
        .rst(rst),
        .clkA(clk),
        .dinA(cmdoutPortA.din),
        .addrA(cmdoutPortA.addr),
        .doutA(cmdoutPortA.dout),
        .enA(cmdoutPortA.en),
        .weA(cmdoutPortA.wr),
        .clkB(cmdout_queue_clk),
        .rstB(cmdout_queue_rst),
        .dinB(cmdout_queue_din),
        .addrB(cmdout_queue_addr),
        .doutB(cmdout_queue_dout),
        .enB(cmdout_queue_en),
        .weB(cmdout_queue_we)
    );

    dual_port_32_bit_mem_wrapper #(
        .WIDTH(64),
        .SIZE(1024),
        .EN_RST_A(0),
        .EN_RST_B(1)
    ) spawnin_queue (
        .rst(rst),
        .clkA(clk),
        .dinA(spawninPortA.din),
        .addrA(spawninPortA.addr),
        .doutA(spawninPortA.dout),
        .enA(spawninPortA.en),
        .weA(spawninPortA.wr),
        .clkB(spawnin_queue_clk),
        .rstB(spawnin_queue_rst),
        .dinB(spawnin_queue_din),
        .addrB(spawnin_queue_addr),
        .doutB(spawnin_queue_dout),
        .enB(spawnin_queue_en),
        .weB(spawnin_queue_we)
    );

    dual_port_32_bit_mem_wrapper #(
        .WIDTH(64),
        .SIZE(1024),
        .EN_RST_A(0),
        .EN_RST_B(1)
    ) spawnout_queue (
        .rst(rst),
        .clkA(clk),
        .dinA(spawnoutPortA.din),
        .addrA(spawnoutPortA.addr),
        .doutA(spawnoutPortA.dout),
        .enA(spawnoutPortA.en),
        .weA(spawnoutPortA.wr),
        .clkB(spawnout_queue_clk),
        .rstB(spawnout_queue_rst),
        .dinB(spawnout_queue_din),
        .addrB(spawnout_queue_addr),
        .doutB(spawnout_queue_dout),
        .enB(spawnout_queue_en),
        .weB(spawnout_queue_we)
    );

endmodule
