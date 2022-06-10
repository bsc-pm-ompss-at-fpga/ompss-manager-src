`timescale 1ns / 1ps

module concurrent_id_creator #(
    parameter NUM_ACCS = 16
) (
    input clk,
    input [NUM_ACCS-1:0] create_id,
    output int id[0:NUM_ACCS-1]
);

    int idx;

    initial begin
        idx = 0;
    end

    always @(posedge clk) begin
        int i;
        for (i = 0; i < NUM_ACCS; i = i+1) begin
            if (create_id[i]) begin
                id[i] <= idx;
                idx = idx+1;
            end
        end
    end

endmodule
