`timescale 1ns / 1ps

module spawn_sim #(
    parameter SPAWNIN_SIZE = 1024,
    parameter SPAWNOUT_SIZE = 1024
) (
    input clk,
    input rst,
    MemoryPort32.master spawnin,
    MemoryPort32.master spawnout
);

    import OmpSsManager::*;
    import Glb::*;

    localparam SPAWNIN_BITS = $clog2(SPAWNIN_SIZE);
    localparam SPAWNOUT_BITS = $clog2(SPAWNOUT_SIZE);

    localparam VALID = 8'h80;

    typedef enum {
        IDLE,
        ISSUE_READ_TID,
        READ_TID,
        READ_PTID,
        READ_TASKTYPE,
        READ_COP1,
        READ_COP2,
        READ_DEP,
        READ_ARG,
        CLEAR_HEADER,
        WAIT_S,
        CHECK_SPAWNOUT,
        WRITE_TID,
        WRITE_PTID,
        WRITE_HEADER
    } State_t;

    State_t state;

    int num_slots;
    int count;
    int wait_time;
    int idx;
    int limit;
    int task_array_idx;
    reg reading;
    reg [7:0] nArgs;
    reg [7:0] nDeps;
    reg [7:0] nCops;
    reg [31:0] task_type;
    reg [63:0] copies[15];
    reg [63:0] deps[15];
    reg [7:0] copFlags[15];
    reg [7:0] copArgIdx[15];
    reg [31:0] copSize[15];
    reg [63:0] tid;
    reg [63:0] ptid;
    reg [SPAWNIN_BITS-1:0] spawnin_idx;
    reg [SPAWNOUT_BITS-1:0] spawnout_idx;
    reg [SPAWNOUT_BITS-1:0] header_spawnout_idx;
    NewTask newTask;

    assign spawnin.addr[2:0] = 0;
    assign spawnin.addr[3+SPAWNIN_BITS-1:3] = spawnin_idx;
    assign spawnin.addr[31:3+SPAWNIN_BITS] = 0;
    assign spawnin.en = 1;
    assign spawnin.wr = state == WRITE_TID || state == WRITE_PTID || state == WRITE_HEADER ? 8'hFF: 8'h00;

    assign spawnout.addr[2:0] = 0;
    assign spawnout.addr[3+SPAWNOUT_BITS-1:3] = spawnout_idx;
    assign spawnout.addr[31:3+SPAWNOUT_BITS] = 0;
    assign spawnout.en = 1;
    assign spawnout.wr = state == CLEAR_HEADER | reading ? 8'h80 : 8'h00;
    assign spawnout.din = 64'd0;

    always_comb begin
        spawnin.din = tid;
        case (state)

            WRITE_PTID: begin
                spawnin.din = ptid;
            end
            WRITE_HEADER: begin
                spawnin.din = 64'h8000000000000001;
            end
            default: begin
            end
        endcase
    end

    always_ff @(posedge clk) begin

        case (state)
            IDLE: begin
                if (spawnout.dout[ENTRY_VALID_BYTE_OFFSET +: 8] == VALID) begin
                    assert(spawnout.dout[NUM_DEPS_OFFSET +: 8] == 0 || !pom) else begin
                        $error("Found spawn out task with dependencies with POM"); $fatal;
                    end
                    assert(spawnout.dout[NUM_ARGS_OFFSET +: 8] > 0)  else begin
                        $error("Spawn out tasks must have at least one argument"); $fatal;
                    end
                    nCops = spawnout.dout[NUM_COPS_OFFSET  +: 8];
                    nDeps = spawnout.dout[NUM_DEPS_OFFSET +: 8];
                    nArgs = spawnout.dout[NUM_ARGS_OFFSET +: 8];
                    count = 0;
                    wait_time = $urandom_range(100);
                    reading <= 1;
                    state <= ISSUE_READ_TID;
                    num_slots = 4 + spawnout.dout[NUM_ARGS_OFFSET +: 8] + spawnout.dout[NUM_DEPS_OFFSET +: 8] + spawnout.dout[NUM_COPS_OFFSET +: 8]*IOInterface::COPY_WORDS;
                    header_spawnout_idx = spawnout_idx;
                    spawnout_idx = spawnout_idx + 1;
                end
            end

            ISSUE_READ_TID: begin
                spawnout_idx = spawnout_idx+1;
                state <= READ_TID;
            end

            READ_TID: begin
                spawnout_idx = spawnout_idx+1;
                tid = spawnout.dout;
                state <= READ_PTID;
            end

            READ_PTID: begin
                spawnout_idx = spawnout_idx+1;
                ptid = spawnout.dout;
                state <= READ_TASKTYPE;
            end

            READ_TASKTYPE: begin
                spawnout_idx = spawnout_idx+1;
                task_type = spawnout.dout[31:0];
                idx = 0;
                if (nDeps > 0) begin
                    limit = nDeps;
                    state <= READ_DEP;
                end else if (nCops > 0) begin
                    limit = nCops;
                    state <= READ_COP1;
                end else begin
                    limit = nArgs;
                    if (nArgs == 1) begin
                        reading <= 0;
                    end
                    state <= READ_ARG;
                end
            end

            READ_DEP: begin
                spawnout_idx = spawnout_idx+1;
                deps[idx] = spawnout.dout;
                if (idx == limit-1) begin
                    idx = 0;
                    if (nCops > 0) begin
                        limit = nCops;
                        state <= READ_COP1;
                    end else begin
                        limit = nArgs;
                        if (nArgs == 1) begin
                            reading <= 0;
                        end
                        state <= READ_ARG;
                    end
                end else begin
                    idx = idx + 1;
                end
            end

            READ_COP1: begin
                spawnout_idx = spawnout_idx+1;
                copies[idx] = spawnout.dout;
                state <= READ_COP2;
            end

            READ_COP2: begin
                spawnout_idx = spawnout_idx+1;
                copFlags[idx] = spawnout.dout[7:0];
                copArgIdx[idx] = spawnout.dout[15:8];
                copSize[idx] = spawnout.dout[63:32];
                if (idx == limit-1) begin
                    idx = 0;
                    limit = nArgs;
                    if (nArgs == 1) begin
                        reading <= 0;
                    end
                    state <= READ_ARG;
                end else begin
                    idx = idx+1;
                    state <= READ_COP1;
                end
            end

            READ_ARG: begin
                if (idx == 0) begin
                    int i;
                    task_array_idx = spawnout.dout;
                    assert(task_array_idx >= 0 && task_array_idx < newTasks.size()) else begin
                        $error("Invalid newTasks idx %d", task_array_idx); $fatal;
                    end
                    newTask = newTasks[task_array_idx];
                    assert(newTasks[task_array_idx].taskType == task_type) else begin
                        $error("Incorrect task type"); $fatal;
                    end
                    assert(newTasks[task_array_idx].nArgs == nArgs) else begin
                        $error("Incorrect number of arguments"); $fatal;
                    end
                    assert(newTasks[task_array_idx].nCops == nCops) else begin
                        $error("Incorrect number of copies"); $fatal;
                    end
                    assert(newTasks[task_array_idx].state == NTASK_CREATED) else begin
                        $error("Invalid task state"); $fatal;
                    end
                    assert(newTasks[task_array_idx].pTid == ptid) else begin
                        $error("Invalid ptid"); $fatal;
                    end
                    assert(newTasks[task_array_idx].smp || !pom) else begin
                        $error("Found not SMP task in spawnout queue with POM"); $fatal;
                    end
                    newTasks[task_array_idx].state = NTASK_READY;
                    for (i = 0; i < nCops; i = i+1) begin
                        assert(newTasks[task_array_idx].copyAddr[i] == copies[i] &&
                               newTasks[task_array_idx].copySize[i] == copSize[i] &&
                               newTasks[task_array_idx].copyFlag[i] == copFlags[i] &&
                               newTasks[task_array_idx].copyArgIdx[i] == copArgIdx[i]) else begin
                            $error("Invalid copy data"); $fatal;
                        end
                    end
                    for (i = 0; i < nDeps; i = i+1) begin
                        assert (newTasks[task_array_idx].deps[i] == deps[i]) else begin
                            $error("Invalid dependence data"); $fatal;
                        end
                    end
                end
                assert(newTasks[task_array_idx].args[idx] == spawnout.dout) else begin
                     $error("Invalid argument value"); $fatal;
                end
                if (idx == limit-2) begin
                    reading <= 0;
                end
                if (idx == limit-1) begin
                    spawnout_idx = header_spawnout_idx;
                    state <= CLEAR_HEADER;
                end else begin
                    idx = idx+1;
                    spawnout_idx = spawnout_idx+1;
                end
            end

            CLEAR_HEADER: begin
                spawnout_idx = spawnout_idx+num_slots;
                state <= WAIT_S;
            end

            WAIT_S: begin
                count = count+1;
                if (count >= wait_time) begin
                    state <= CHECK_SPAWNOUT;
                end
            end

            CHECK_SPAWNOUT: begin
                if (spawnin.dout[ENTRY_VALID_BYTE_OFFSET +: 8] != VALID) begin
                    spawnin_idx = spawnin_idx+1;
                    state <= WRITE_TID;
                end
            end

            WRITE_TID: begin
                spawnin_idx = spawnin_idx+1;
                state <= WRITE_PTID;
            end

            WRITE_PTID: begin
                spawnin_idx = spawnin_idx-2;
                state <= WRITE_HEADER;
            end

            WRITE_HEADER: begin
                spawnin_idx = spawnin_idx+3;
                state <= IDLE;
            end

        endcase

        if (rst) begin
            reading = 0;
            state <= IDLE;
            spawnin_idx <= 0;
            spawnout_idx <= 0;
        end
    end

endmodule
