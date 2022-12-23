
module cmdout_sim#(
    parameter NUM_ACCS = 16
) (
    input clk,
    input rst,
    MemoryPort32.master cmdoutPort,
    output int finished_cmds
);

    import Glb::*;

    localparam ACC_BITS = $clog2(NUM_ACCS) == 0 ? 1 : $clog2(NUM_ACCS);

    typedef enum {
        ISSUE_READ,
        READ_VALID,
        READ_TID
    } State;

    State state;
    int acc_id;
    reg [5:0] slot_idx[NUM_ACCS];

    assign cmdoutPort.en = 1;
    assign cmdoutPort.wr = state == READ_TID ? 8'h80 : 8'h00;
    assign cmdoutPort.din = 64'd0;

    initial begin
        int i;
        acc_id = 0;
        for (i = 0; i < NUM_ACCS; i = i+1) begin
            slot_idx[i] = 0;
        end
        finished_cmds = 0;
    end

    always_comb begin
        cmdoutPort.addr = 0;
        cmdoutPort.addr[8:3] = slot_idx[acc_id];
        cmdoutPort.addr[9 + ACC_BITS-1 : 9] = acc_id;
        if (state == READ_VALID && cmdoutPort.dout[63:56] == 8'h80) begin
            cmdoutPort.addr[8:3] = slot_idx[acc_id]+1;
        end
    end

    always @(posedge clk) begin

        case (state)

            ISSUE_READ: begin
                state <= READ_VALID;
            end

            READ_VALID: begin
                if (cmdoutPort.dout[63:56] == 8'h80) begin
                    state <= READ_TID;
                end else begin
                    acc_id = (acc_id+1)%NUM_ACCS;
                    state <= ISSUE_READ;
                end
            end

            READ_TID: begin
                int idx;
                state <= ISSUE_READ;
                slot_idx[acc_id] = slot_idx[acc_id] + 2;
                idx = cmdoutPort.dout[55:32];
                assert(commands[idx].tid === cmdoutPort.dout) else begin
                    $error("Task id %016X is corrupted", cmdoutPort.dout);
                    $fatal;
                end
                assert(!commands[idx].finished) else begin
                    $error("Task id %0X found in the cmd out queue at least twice", cmdoutPort.dout);
                    $fatal;
                end
                commands[idx].finished = 1;
                finished_cmds = finished_cmds+1;
            end

        endcase

        if (rst) begin
            state <= ISSUE_READ;
        end
    end

endmodule
