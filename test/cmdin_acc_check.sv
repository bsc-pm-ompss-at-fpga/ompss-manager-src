
module cmdin_acc_check #(
    parameter NUM_ACCS = 16,
    parameter MAX_ACC_CREATORS= 0
) (
    input clk,
    input rst,
    GenAxis.observer cmdin
);

    import OmpSsManager::*;
    import Glb::*;

    typedef enum {
        HEADER,
        TID,
        PTID,
        PERIOD_NREPETITIONS,
        ARGFLAG,
        ARG
    } State_t;

    State_t state;
    int idx;
    reg [7:0] code;
    int nArgs, compf, num_slots;
    int argIdx;
    int lastCmdIdx[NUM_ACCS];
    reg lastOutCopyFlag[NUM_ACCS][15];
    reg [7:0] curFlag;
    reg [63:0] tid;
    reg [63:0] ptid;
    int isAccTask;
    NewTask newTask;

    initial begin
        int i, j;
        for (i = 0; i < NUM_ACCS; i = i+1) begin
            lastCmdIdx[i] = -1;
        end
    end

    always @(posedge clk) begin

        case (state)

            HEADER: begin
                if (cmdin.valid && cmdin.ready) begin
                    assert(cmdin.data[CMD_TYPE_H:CMD_TYPE_L] == EXEC_TASK_CODE ||
                           cmdin.data[CMD_TYPE_H:CMD_TYPE_L] == EXEC_PERI_TASK_CODE ||
                           cmdin.data[CMD_TYPE_H:CMD_TYPE_L] == SETUP_HW_INST_CODE) else begin
                        $error("Invalid command type in cmdin acc interconnection"); $fatal;
                    end
                    assert(cmdin.data[CMD_TYPE_H:CMD_TYPE_L] == SETUP_HW_INST_CODE || cmdin.data[DESTID_H:DESTID_L] == HWR_CMDOUT_ID_BYTE) else begin
                        $error("Invalid dest id in cmdin acc interconnection"); $fatal;
                    end
                    argIdx = 0;
                    nArgs = cmdin.data[NUM_ARGS_OFFSET +: 8];
                    compf = cmdin.data[COMPF_H:COMPF_L];
                    code = cmdin.data[CMD_TYPE_H:CMD_TYPE_L];
                    num_slots = cmdin.data[31:8];
                    state = TID;
                end
            end

            TID: begin
                if (cmdin.valid && cmdin.ready) begin
                    tid = cmdin.data;
                    isAccTask = cmdin.data[63:56] != 0;
                    if (!isAccTask) begin
                        idx = cmdin.data[55:32];
                        assert(commands[idx].tid == cmdin.data) else begin
                            $error("Task id/instrumentation address %016X is corrupted in cmdin acc interconnection", cmdin.data); $fatal;
                        end
                        if (code == SETUP_HW_INST_CODE) begin
                            assert(commands[idx].period == num_slots) else begin
                                $error("Incorrect number of slots"); $fatal;
                            end
                            assert(cmdin.last) else begin
                                $error("Last signal not asserted in time"); $fatal;
                            end
                            state = HEADER;
                        end else begin
                            assert(commands[idx].nArgs == nArgs) else begin
                                $error("Incorrect number of arguments"); $fatal;
                            end
                            assert(commands[idx].comp == compf) else begin
                                $error("Incorrect comp flag"); $fatal;
                            end
                            assert(commands[idx].acc_id == cmdin.dest) else begin
                                $error("Task sent to the incorrect accelerator, expected %0d but tdest is %0d", commands[idx].acc_id, cmdin.dest); $fatal;
                            end
                            state = PTID;
                        end
                    end else begin
                        assert(code == EXEC_TASK_CODE) else begin
                            $error("Command can only be EXEC_TASK_CODE when created by an accelerator"); $fatal;
                        end
                        state = PTID;
                    end
                end
            end

            PTID: begin
                if (cmdin.valid && cmdin.ready) begin
                    ptid = cmdin.data;
                    if (code == EXEC_PERI_TASK_CODE) begin
                        state = PERIOD_NREPETITIONS;
                    end else if (nArgs > 0) begin
                        state = ARGFLAG;
                    end else begin
                        assert(!isAccTask) else begin
                            $error("Tasks created by accelerators must have at lease one argument"); $fatal;
                        end
                        assert(cmdin.last) else begin
                            $error("Last signal not asserted in time"); $fatal;
                        end
                        state = HEADER;
                    end
                end
            end

            PERIOD_NREPETITIONS: begin
                if (cmdin.valid && cmdin.ready) begin
                    assert(cmdin.data[63:32] == commands[idx].period) else begin
                        $error("Incorrect period"); $fatal;
                    end
                    assert(cmdin.data[31:0] == commands[idx].repetitions) else begin
                        $error("Incorrect num repetitions"); $fatal;
                    end
                    if (nArgs > 0) begin
                        state = ARGFLAG;
                    end else begin
                        assert(cmdin.last) else begin
                            $error("Last signal not asserted in time"); $fatal;
                        end
                        state = HEADER;
                    end
                end
            end

            ARGFLAG: begin
                if (cmdin.valid && cmdin.ready) begin
                    curFlag = cmdin.data[ARG_FLAG_H:ARG_FLAG_L];
                    assert(cmdin.data[63:32] == argIdx) else begin
                        $error("Invalid argument index"); $fatal;
                    end
                    state = ARG;
                end
            end

            ARG: begin
                reg [7:0] cmdFlag;
                reg [7:0] lastFlag;
                reg [63:0] cmdArg;
                reg [63:0] lastArg;
                reg argHasCopy;
                int accTypeIdx;
                if (cmdin.valid && cmdin.ready) begin
                    accTypeIdx = accId2accType[cmdin.dest];
                    argHasCopy = accTypes[accTypeIdx].argCopIdx[argIdx] != 8'hFF;
                    if (isAccTask) begin
                        if (argIdx == 0) begin
                            idx = cmdin.data;
                            assert(idx >= 0 && idx < newTasks.size()) else begin
                                $error("Invalid newTasks idx %d", idx); $fatal;
                            end
                            newTask = newTasks[idx];
                            assert(newTasks[idx].nArgs == nArgs) else begin
                                $error("Incorrect number of arguments"); $fatal;
                            end
                            assert(compf == 1) else begin
                                $error("Incorrect comp flag"); $fatal;
                            end
                            assert(newTasks[idx].taskType == accTypes[accTypeIdx].taskType) else begin
                                $error("accTypeIdx %d accID %d", accTypeIdx, cmdin.dest);
                                $error("Task sent to an accelerator with incompatible task type, task type originally was %x but destination acc has type %x", newTasks[idx].taskType, accTypes[accTypeIdx].taskType); $fatal;
                            end
                            assert (ptid[$clog2(MAX_ACC_CREATORS)-1:0] == newTasks[idx].acc_id) else begin
                                $error("Invalid ptid acc id"); $fatal;
                            end
                            assert(!newTasks[idx].smp) else begin
                                $error("Found SMP task in spawnout queue"); $fatal;
                            end
                            assert(newTasks[idx].state == NTASK_CREATED) else begin
                                $error("Invalid task state"); $fatal;
                            end
                            newTasks[idx].state = NTASK_READY;
                        end
                        cmdFlag[5] = accTypes[accTypeIdx].copDirs[accTypes[accTypeIdx].argCopIdx[argIdx]][1];
                        cmdFlag[4] = accTypes[accTypeIdx].copDirs[accTypes[accTypeIdx].argCopIdx[argIdx]][0];
                        cmdArg = newTasks[idx].args[argIdx];
                        // The copy could be optimized
                        if (lastCmdIdx[cmdin.dest] != -1) begin
                            lastFlag[5] = cmdFlag[5];
                            lastFlag[4] = cmdFlag[4];
                            lastArg = newTasks[lastCmdIdx[cmdin.dest]].args[argIdx];
                        end else begin
                            lastFlag = 0;
                        end
                    end else begin
                        cmdFlag = commands[idx].argFlags[argIdx];
                        cmdArg = commands[idx].args[argIdx];
                        // The copy could be optimized
                        if (lastCmdIdx[cmdin.dest] != -1) begin
                            lastFlag = commands[lastCmdIdx[cmdin.dest]].argFlags[argIdx];
                            lastArg = commands[lastCmdIdx[cmdin.dest]].args[argIdx];
                        end else begin
                            lastFlag = 0;
                        end
                    end

                    assert(cmdin.data == cmdArg) else begin
                        $error("Invalid argument value"); $fatal;
                    end

                    if (argHasCopy) begin
                        //Copy out optimizations are applied with future commands, so if it is disabled it may be because of
                        //the original command or because it has been optimized
                        //NOTE: This implementation doesn't detect errors in the out copy flags of the last command in the simulation
                        assert(curFlag[5] == cmdFlag[5] || cmdFlag[5]) else begin
                            $error("Invalid output argument flags: curFlag %0d cmdFlag %0d", curFlag[5], cmdFlag[5]); $fatal;
                        end

                        if (lastCmdIdx[cmdin.dest] != -1 && cmdin.data == lastArg) begin
                            assert(curFlag[4] == cmdFlag[4] || (!curFlag[4] && cmdFlag[4] && lastFlag[4])) else begin
                                $error("Invalid in copy optimization, curFlag %d cmdFlag %d lastFlag %d", curFlag[4], cmdFlag[4], lastFlag[4]); $fatal;
                            end
                            // If last command had copy enabled, that one can't be optimized
                            assert(lastOutCopyFlag[cmdin.dest][argIdx] || !lastFlag[5] || cmdFlag[5]) else begin
                                $error("Current command does not copy out, but last command did optimize the copy."); $fatal;
                            end
                        end else begin
                            assert(curFlag[4] == cmdFlag[4]) else begin
                                $error("Invalid input argument flags: curFlag %0d cmdFlag %0d", curFlag[4], cmdFlag[4]); $fatal;
                            end
                            // If last command had copy enabled, that one can't be optimized
                            assert(lastOutCopyFlag[cmdin.dest][argIdx] || !lastFlag[5]) else begin
                                $error("Current argument differs with last one, but a copy out of last argument is required"); $fatal;
                            end
                        end
                        lastOutCopyFlag[cmdin.dest][argIdx] = curFlag[5];
                    end
                    argIdx = argIdx + 1;
                    if (argIdx == nArgs) begin
                        assert(cmdin.last) else begin
                            $error("Last signal should be asserted"); $fatal;
                        end
                        lastCmdIdx[cmdin.dest] = idx;
                        state = HEADER;
                    end else begin
                        state = ARGFLAG;
                    end
                end
            end

        endcase

        if (rst) begin
            state = HEADER;
        end

    end

endmodule
