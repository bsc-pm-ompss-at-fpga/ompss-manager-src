`timescale 1ns / 1ps

module acc_inter #(
    parameter NUM_ACCS = 16,
    parameter NUM_CREATORS = 0
) (
    input clk,
    input rst,
    GenAxis.slave cmdin,
    GenAxis.master cmdout,
    GenAxis.slave taskwait_in,
    GenAxis.master taskwait_out,
    GenAxis.slave spawn_in,
    GenAxis.master spawn_out
);

    localparam ACC_BITS = $clog2(NUM_ACCS) == 0 ? 1 : $clog2(NUM_ACCS);
    localparam NUM_INTF = NUM_CREATORS > 0 ? NUM_CREATORS : 1;

    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) cmdin_inter[1]();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) cmdout_inter[1]();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) accInStream[NUM_ACCS]();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) accOutStream[NUM_ACCS]();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) taskwait_in_inter[1]();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) taskwait_out_inter[1]();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) taskwait_in_accel[NUM_INTF]();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) taskwait_out_accel[NUM_INTF]();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) spawn_in_inter[1]();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) spawn_out_inter[1]();
    GenAxis #(.DATA_WIDTH(64), .DEST_WIDTH(ACC_BITS)) spawn_in_accel[NUM_INTF]();
    GenAxis #(.DATA_WIDTH(64), .ID_WIDTH(ACC_BITS), .DEST_WIDTH(3)) spawn_out_accel[NUM_INTF]();
    
    // This is used to support concurrent new task id creation. This id is the index of the newTasks array.
    wire [NUM_ACCS-1:0] create_id;
    int id[NUM_ACCS];
    
    connect_gen_axis C1(.m(cmdin_inter[0]), .s(cmdin));
    connect_gen_axis C2(.m(cmdout), .s(cmdout_inter[0]));
    
    axis_switch_sv_int #(
        .NSLAVES(1),
        .NMASTERS(NUM_ACCS),
        .DATA_WIDTH(64),
        .HAS_ID(0),
        .HAS_DEST(1),
        .DEST_WIDTH(ACC_BITS),
        .HAS_LAST(1)
    ) acc_instream (
        .aclk(clk),
        .aresetn(!rst),
        .slaves(cmdin_inter),
        .masters(accInStream)
    );
    
    axis_switch_sv_int #(
        .NSLAVES(NUM_ACCS),
        .NMASTERS(1),
        .DATA_WIDTH(64),
        .HAS_ID(1),
        .ID_WIDTH(ACC_BITS),
        .HAS_DEST(1),
        .DEST_WIDTH(3),
        .HAS_LAST(1)
    ) acc_outstream (
        .aclk(clk),
        .aresetn(!rst),
        .slaves(accOutStream),
        .masters(cmdout_inter)
    );

    if (NUM_CREATORS > 0) begin : CREATORS_INTER
    
        connect_gen_axis C3(.m(taskwait_in_inter[0]), .s(taskwait_in));
        connect_gen_axis C4(.m(taskwait_out), .s(taskwait_out_inter[0]));
        connect_gen_axis C5(.m(spawn_in_inter[0]), .s(spawn_in));
        connect_gen_axis C6(.m(spawn_out), .s(spawn_out_inter[0]));
            
        concurrent_id_creator #(
            .NUM_ACCS(NUM_ACCS)
        ) CONCURRENT_ID_CREATOR_I (
            .clk(clk),
            .create_id(create_id),
            .id(id)
        );
    
        axis_switch_sv_int #(
            .NSLAVES(1),
            .NMASTERS(NUM_CREATORS),
            .DATA_WIDTH(64),
            .HAS_ID(0),
            .HAS_DEST(1),
            .DEST_WIDTH(ACC_BITS),
            .HAS_LAST(1)
        ) acc_taskwait_in (
            .aclk(clk),
            .aresetn(!rst),
            .slaves(taskwait_in_inter),
            .masters(taskwait_in_accel)
        );
    
        axis_switch_sv_int #(
            .NSLAVES(1),
            .NMASTERS(NUM_CREATORS),
            .DATA_WIDTH(64),
            .HAS_ID(0),
            .HAS_DEST(1),
            .DEST_WIDTH(ACC_BITS),
            .HAS_LAST(1)
        ) acc_spawn_in (
            .aclk(clk),
            .aresetn(!rst),
            .slaves(spawn_in_inter),
            .masters(spawn_in_accel)
        );
        
        axis_switch_sv_int #(
            .NSLAVES(NUM_CREATORS),
            .NMASTERS(1),
            .DATA_WIDTH(64),
            .HAS_ID(1),
            .ID_WIDTH(ACC_BITS),
            .HAS_DEST(1),
            .DEST_WIDTH(3),
            .HAS_LAST(1)
        ) acc_taskwait_out (
            .aclk(clk),
            .aresetn(!rst),
            .slaves(taskwait_out_accel),
            .masters(taskwait_out_inter)
        );
        
        axis_switch_sv_int #(
            .NSLAVES(NUM_CREATORS),
            .NMASTERS(1),
            .DATA_WIDTH(64),
            .HAS_ID(1),
            .ID_WIDTH(ACC_BITS),
            .HAS_DEST(1),
            .DEST_WIDTH(3),
            .HAS_LAST(1)
        ) acc_spawn_out (
            .aclk(clk),
            .aresetn(!rst),
            .slaves(spawn_out_accel),
            .masters(spawn_out_inter)
        );
    end
    
    genvar i;
    
    for (i = 0; i < NUM_CREATORS; i = i+1) begin : CREATOR_INST
        acc_creator_sim #(
            .ID(i),
            .NUM_CREATORS(NUM_CREATORS)
        ) ACC_SIM_I (
            .clk(clk),
            .rst(rst),
            .create_id(create_id[i]),
            .new_task_idx(id[i]),
            .inStream(accInStream[i]),
            .outStream(accOutStream[i]),
            .spawn_in(spawn_in_accel[i]),
            .spawn_out(spawn_out_accel[i]),
            .taskwait_in(taskwait_in_accel[i]),
            .taskwait_out(taskwait_out_accel[i])
        );
    end
    
    for (i = NUM_CREATORS; i < NUM_ACCS; i = i+1) begin : ACC_INST
        assign create_id[i] = 0;
        acc_sim #(
            .ID(i)
        ) ACC_SIM_I (
            .clk(clk),
            .rst(rst),
            .inStream(accInStream[i]),
            .outStream(accOutStream[i])
        );
    end

endmodule
