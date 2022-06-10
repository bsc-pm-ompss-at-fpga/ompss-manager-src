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
        reg [7:0] code;
        reg [63:0] tid;
        reg [7:0] comp;
        reg [7:0] nArgs;
        reg [7:0] argFlags[15];
        reg [63:0] args[15];
        reg finished;
        int acc_id;
        int period;
        int repetitions;
    } Command;
    Command commands[];

    reg[63:0] argPool[];

    int creationGraph[];

    typedef struct {
        reg [31:0] taskType;
        reg [7:0] nArgs;
        reg [7:0] nDeps;
        reg [7:0] nCops;
        reg [7:0] depDirs[15];
        reg [7:0] copDirs[15];
        reg [7:0] copArgIdx[15];
        reg [7:0] argCopIdx[15];
        int numInstances;
    } AccType;

    AccType accTypes[];
    int accId2accType[];

    typedef struct {
        reg [7:0] nArgs;
        reg [7:0] nDeps;
        reg [7:0] nCops;
        reg [63:0] pTid;
        reg [7:0] insNum;
        reg [31:0] taskType;
        reg [63:0] deps[15];
        reg [63:0] args[15];
        reg [63:0] copyAddr[15];
        reg [31:0] copySize[15];
        reg [7:0] copyFlag[15];
        reg [7:0] copyArgIdx[15];
        reg [31:0] copyAccessLenght[15];
        reg [31:0] copyOffset[15];
        reg smp;
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
