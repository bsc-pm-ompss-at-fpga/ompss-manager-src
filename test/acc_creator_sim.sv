
module acc_creator_sim #(
    parameter ID = 0,
    parameter NUM_CREATORS = 0
) (
    input clk,
    input rst,
    output create_id,
    input int new_task_idx,
    GenAxis.slave inStream,
    GenAxis.master outStream,
    GenAxis.slave spawn_in,
    GenAxis.master spawn_out,
    GenAxis.slave taskwait_in,
    GenAxis.master taskwait_out
);

    import OmpSsManager::*;
    import Glb::*;

    typedef enum {
        IDLE,
        READ_TID,
        READ_PTID,
        READ_ARGS,
        WAIT_TIME,
        CREATE_NTASK_IDX,
        CREATE_TASK,
        SEND_NTASK_HEADER,
        SEND_NTASK_PTID,
        SEND_NTASK_TTYPE,
        SEND_NTASK_DEP,
        SEND_NTASK_COP1,
        SEND_NTASK_COP2,
        SEND_NTASK_ARG,
        WAIT_ACK,
        DECIDE_NEXT_TASK,
        SEND_TASKWAIT_1,
        SEND_TASKWAIT_2,
        WAIT_TASKWAIT,
        SEND_COMMAND,
        SEND_TID,
        SEND_PTID,
        READ_HWINS_ADDR
    } State_t;

    State_t state;
    int count;
    reg [63:0] tid;
    reg [63:0] ptid;
    reg [31:0] taskNum;
    int idx;
    int limit;
    int createdTasks;
    int tasksToCreate;
    logic [63:0] outPort;
    int wait_time;
    int finalMode;
    NewTask newTask;

    assign inStream.ready = state == IDLE || state == READ_HWINS_ADDR || state == READ_TID || state == READ_PTID || state == READ_ARGS;
    assign outStream.valid = state == SEND_COMMAND || state == SEND_TID || state == SEND_PTID;
    assign outStream.last = state == SEND_PTID;
    assign outStream.dest = HWR_CMDOUT_ID;
    assign outStream.data = outPort;
    assign outStream.id = ID;

    assign spawn_in.ready = state == WAIT_ACK;
    assign spawn_out.id = ID;
    assign taskwait_out.valid = state == SEND_TASKWAIT_1 || state == SEND_TASKWAIT_2;
    assign taskwait_out.data = 0;
    assign taskwait_out.id = ID;
    assign taskwait_out.dest = HWR_TASKWAIT_ID;
    assign taskwait_out.last = state == SEND_TASKWAIT_2;
    assign taskwait_in.ready = state == WAIT_TASKWAIT;

    assign create_id = state == CREATE_NTASK_IDX;

    always_comb begin
        outPort = 64'hXXXXXXXXXXXXXXXX;

        spawn_out.valid = 0;
        spawn_out.data = 64'hXXXXXXXXXXXXXXXX;
        spawn_out.dest = HWR_NEWTASK_ID;
        spawn_out.last = 0;

        taskwait_out.data = 64'hXXXXXXXXXXXXXXXX;

        case (state)

            SEND_COMMAND: begin
                outPort[7:0] = 8'h03;
            end

            SEND_TID: begin
                outPort = tid;
            end

            SEND_PTID: begin
                outPort = ptid;
            end

            SEND_NTASK_HEADER: begin
                spawn_out.valid = 1;
                spawn_out.data[0] = 0;
                spawn_out.data[NUM_ARGS_OFFSET +: 8] = newTasks[new_task_idx].nArgs;
                spawn_out.data[NUM_DEPS_OFFSET +: 8] = newTasks[new_task_idx].nDeps;
                spawn_out.data[NUM_COPS_OFFSET +: 8] = newTasks[new_task_idx].nCops;
                spawn_out.data[TASK_SEQ_ID_H:TASK_SEQ_ID_L] = taskNum;
            end

            SEND_NTASK_PTID: begin
                spawn_out.valid = 1;
                spawn_out.data = tid;
            end

            SEND_NTASK_TTYPE: begin
                spawn_out.valid = 1;
                spawn_out.data[CMD_NEWTASK_TASKTYPE_H:CMD_NEWTASK_TASKTYPE_L] = newTasks[new_task_idx].taskType;
                spawn_out.data[CMD_NEWTASK_ARCHBITS_FPGA_B] = !newTasks[new_task_idx].smp;
                spawn_out.data[CMD_NEWTASK_ARCHBITS_SMP_B] = newTasks[new_task_idx].smp;
                spawn_out.data[CMD_NEWTASK_INSNUM_H:CMD_NEWTASK_INSNUM_L] = SCHED_INSNUM_ANY;
                if (newTasks[new_task_idx].nArgs == 0 && newTasks[new_task_idx].nDeps == 0 && newTasks[new_task_idx].nCops == 0) begin
                    spawn_out.last = 1;
                end
            end

            SEND_NTASK_DEP: begin
                spawn_out.valid = 1;
                spawn_out.data = newTasks[new_task_idx].deps[idx];
                if (idx == limit-1 && newTasks[new_task_idx].nArgs == 0 && newTasks[new_task_idx].nCops == 0) begin
                    spawn_out.last = 1;
                end
            end

            SEND_NTASK_COP1: begin
                spawn_out.valid = 1;
                spawn_out.data = newTasks[new_task_idx].copyAddr[idx];
            end

            SEND_NTASK_COP2: begin
                spawn_out.valid = 1;
                spawn_out.data[7:0] = newTasks[new_task_idx].copyFlag[idx];
                spawn_out.data[15:8] = newTasks[new_task_idx].copyArgIdx[idx];
                spawn_out.data[63:32] = newTasks[new_task_idx].copySize[idx];
                if (idx == limit-1 && newTasks[new_task_idx].nArgs == 0) begin
                    spawn_out.last = 1;
                end
            end

            SEND_NTASK_ARG: begin
                spawn_out.valid = 1;
                spawn_out.data = newTasks[new_task_idx].args[idx];
                if (idx == limit-1) begin
                    spawn_out.last = 1;
                end
            end

            SEND_TASKWAIT_1: begin
                taskwait_out.data[31:0] = taskNum;
                taskwait_out.data[39:32] = 8'h01;
            end

            SEND_TASKWAIT_2: begin
                taskwait_out.data = tid;
            end

            default: begin
            end
        endcase
    end

    always_ff @(posedge clk) begin

        case (state)

            IDLE: begin
                count <= 0;
                if (inStream.valid) begin
                    createdTasks = 0;
                    tasksToCreate = NUM_CREATORS == 1 ? maxNewTasks : $urandom_range(1, 100);
                    wait_time <= $urandom_range(10);
                    if (inStream.data[CMD_TYPE_H:CMD_TYPE_L] == SETUP_HW_INST_CODE) begin
                        state <= READ_HWINS_ADDR;
                    end else begin
                        state <= READ_TID;
                    end
                end
            end

            READ_HWINS_ADDR: begin
                if (inStream.valid) begin
                    state <= IDLE;
                end
            end

            READ_TID: begin
                int i;
                for (i = 0; i < 64; i = i+1) begin
                    // The runtime may put X in the task id, which is correct because maybe not all bits are needed, but
                    // all comparisons with X values always return false, so in order to ensure the taskwait module finds the
                    // id, we have to replace them with a defined value.
                    if (inStream.data[i] === 1'bX) begin
                        tid[i] <= $urandom_range(1);
                    end else begin
                        tid[i] <= inStream.data[i];
                    end
                end
                if (inStream.valid) begin
                    state <= READ_PTID;
                end
            end

            READ_PTID: begin
                ptid <= inStream.data;
                if (inStream.valid & inStream.last) begin
                    state <= WAIT_TIME;
                end else if (inStream.valid) begin
                    state <= READ_ARGS;
                end
            end

            READ_ARGS: begin
                if (inStream.valid && inStream.last) begin
                    state <= WAIT_TIME;
                end
            end

            WAIT_TIME: begin
                count <= count+1;
                if (count == wait_time) begin
                    state <= CREATE_NTASK_IDX;
                end
            end

            CREATE_NTASK_IDX: begin
                state <= CREATE_TASK;
            end

            CREATE_TASK: begin
                int accTypeIdx, i, j, dir;
                if (new_task_idx >= maxNewTasks) begin
                   state <= SEND_TASKWAIT_1;
                end else begin
                    do begin
                        accTypeIdx = {$random(random_seed)}%accTypes.size();
                    end while (!creationGraph[ID*accTypes.size() + accTypeIdx]);

                    finalMode = 0;

                    newTasks[new_task_idx].nArgs = accTypes[accTypeIdx].nArgs;
                    newTasks[new_task_idx].nDeps = accTypes[accTypeIdx].nDeps;
                    newTasks[new_task_idx].nCops = accTypes[accTypeIdx].nCops;
                    newTasks[new_task_idx].taskType = accTypes[accTypeIdx].taskType;
                    newTasks[new_task_idx].pTid = tid;
                    newTasks[new_task_idx].acc_id = ID;
                    newTasks[new_task_idx].smp = $urandom_range(100) <= 5;

                    // First argument is always the index of the newTasks array since there is no other place to save this information,
                    // which is needed to check correctness in the cmdin_out interface
                    newTasks[new_task_idx].args[0] = new_task_idx;
                    for (i = 1; i < newTasks[new_task_idx].nArgs; i = i+1) begin
                        j = $urandom_range(argPool.size()-1);
                        newTasks[new_task_idx].args[i] = argPool[j];
                    end
                    for (i = 0; i < newTasks[new_task_idx].nDeps; i = i+1) begin
                        j = $urandom_range(argPool.size()-1);
                        newTasks[new_task_idx].deps[i][31:0] = argPool[j][31:0];
                        // To avoid deadlocks, only task siblings can depend on each other.
                        newTasks[new_task_idx].deps[i][55:32] = tid[23:0];
                        newTasks[new_task_idx].deps[i][63:56] = accTypes[accTypeIdx].depDirs[i];
                    end
                    for (i = 0; i < newTasks[new_task_idx].nCops; i = i+1) begin
                        j = $urandom_range(argPool.size()-1);
                        newTasks[new_task_idx].copyAddr[i] = argPool[j];
                        newTasks[new_task_idx].copySize[i] = $urandom;
                        newTasks[new_task_idx].copyFlag[i] = accTypes[accTypeIdx].copDirs[i];
                        newTasks[new_task_idx].copyArgIdx[i] = accTypes[accTypeIdx].copArgIdx[i];
                    end
                    newTasks[new_task_idx].state = NTASK_CREATED;
                    state <= SEND_NTASK_HEADER;
                    newTask = newTasks[new_task_idx];
                end
            end

            SEND_NTASK_HEADER: begin
                if (spawn_out.ready) begin
                    state <= SEND_NTASK_PTID;
                end
            end

            SEND_NTASK_PTID: begin
                if (spawn_out.ready) begin
                    state <= SEND_NTASK_TTYPE;
                end
            end

            SEND_NTASK_TTYPE: begin
                if (spawn_out.ready) begin
                    idx <= 0;
                    if (newTasks[new_task_idx].nDeps > 0) begin
                        limit = newTasks[new_task_idx].nDeps;
                        state <= SEND_NTASK_DEP;
                    end else if (newTasks[new_task_idx].nCops > 0) begin
                        limit = newTasks[new_task_idx].nCops;
                        state <= SEND_NTASK_COP1;
                    end else if (newTasks[new_task_idx].nArgs > 0) begin
                        limit = newTasks[new_task_idx].nArgs;
                        state <= SEND_NTASK_ARG;
                    end else begin
                        state <= WAIT_ACK;
                    end
                end
            end

            SEND_NTASK_DEP: begin
                if (spawn_out.ready) begin
                    idx <= idx+1;
                    if (idx == limit-1) begin
                        idx <= 0;
                        if (newTasks[new_task_idx].nCops > 0) begin
                            limit = newTasks[new_task_idx].nCops;
                            state <= SEND_NTASK_COP1;
                        end else if (newTasks[new_task_idx].nArgs > 0) begin
                            limit = newTasks[new_task_idx].nArgs;
                            state <= SEND_NTASK_ARG;
                        end else begin
                            state <= WAIT_ACK;
                        end
                    end
                end
            end

            SEND_NTASK_COP1: begin
                if (spawn_out.ready) begin
                    state <= SEND_NTASK_COP2;
                end
            end

            SEND_NTASK_COP2: begin
                if (spawn_out.ready) begin
                    idx <= idx+1;
                    if (idx == limit-1) begin
                        idx <= 0;
                        if (newTasks[new_task_idx].nArgs > 0) begin
                            limit = newTasks[new_task_idx].nArgs;
                            state <= SEND_NTASK_ARG;
                        end else begin
                            state <= WAIT_ACK;
                        end
                    end else begin
                        state <= SEND_NTASK_COP1;
                    end
                end
            end

            SEND_NTASK_ARG: begin
                if (spawn_out.ready) begin
                    idx <= idx+1;
                    if (idx == limit-1) begin
                        state <= WAIT_ACK;
                    end
                end
            end

            WAIT_ACK: begin
                if (spawn_in.valid) begin
                    if (spawn_in.data[7:0] == ACK_OK_CODE) begin //Accept
                        taskNum = taskNum+1;
                        createdTasks = createdTasks+1;
                        if (createdTasks < tasksToCreate && !finalMode) begin
                            state <= CREATE_NTASK_IDX;
                        end else begin
                            state <= SEND_TASKWAIT_1;
                        end
                    end else if (spawn_in.data[7:0] == ACK_REJECT_CODE) begin
                        state <= SEND_NTASK_HEADER;
                    end else if (spawn_in.data[7:0] == ACK_FINAL_CODE) begin
                        newTasks[new_task_idx].nDeps = 0;
                        finalMode = 1;
                        state <= SEND_NTASK_HEADER;
                    end else begin
                        $error("Invalid ACK code"); $fatal;
                    end
                end
            end

            SEND_TASKWAIT_1: begin
                if (taskwait_out.ready) begin
                    state <= SEND_TASKWAIT_2;
                end
            end

            SEND_TASKWAIT_2: begin
                if (taskwait_out.ready) begin
                    state <= WAIT_TASKWAIT;
                end
            end

            WAIT_TASKWAIT: begin
                if (taskwait_in.valid) begin
                    taskNum = 0;
                    if (new_task_idx < maxNewTasks && createdTasks < tasksToCreate) begin
                        state <= CREATE_NTASK_IDX;
                    end else begin
                        state <= SEND_COMMAND;
                    end
                end
            end

            SEND_COMMAND: begin
                if (outStream.ready) begin
                    state <= SEND_TID;
                end
            end

            SEND_TID: begin
                if (outStream.ready) begin
                    state <= SEND_PTID;
                end
            end

            SEND_PTID: begin
                if (outStream.ready) begin
                    state <= IDLE;
                end
            end

        endcase

        if (rst) begin
            state <= IDLE;
            taskNum = 0;
        end
    end

endmodule
