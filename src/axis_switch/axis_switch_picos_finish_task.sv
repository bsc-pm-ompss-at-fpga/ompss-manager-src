
module axis_switch_picos_finish_task #(
    parameter ENABLE_SPAWN_QUEUES = 0,
    localparam DATA_WIDTH = 32
) (
    input clk,
    input rstn,
    input  S00_AXIS_tvalid,
    output S00_AXIS_tready,
    input  [DATA_WIDTH-1:0] S00_AXIS_tdata,
    input  S01_AXIS_tvalid,
    output S01_AXIS_tready,
    input  [DATA_WIDTH-1:0] S01_AXIS_tdata,
    output M00_AXIS_tvalid,
    input  M00_AXIS_tready,
    output [DATA_WIDTH-1:0] M00_AXIS_tdata
);

    localparam NSLAVES = ENABLE_SPAWN_QUEUES ? 2 : 1;
    localparam NMASTERS = 1;

    wire [NSLAVES-1:0] s_valid;
    wire [NSLAVES-1:0] s_ready;
    wire [NSLAVES*DATA_WIDTH-1:0] s_data;
    wire [NMASTERS-1:0] m_valid;
    wire [NMASTERS-1:0] m_ready;
    wire [NMASTERS*DATA_WIDTH-1:0] m_data;

    assign s_valid[0] = S00_AXIS_tvalid;
    assign S00_AXIS_tready = s_ready[0];
    assign s_data[DATA_WIDTH*0 +: DATA_WIDTH] = S00_AXIS_tdata;

    if (ENABLE_SPAWN_QUEUES) begin
        assign s_valid[1] = S01_AXIS_tvalid;
        assign S01_AXIS_tready = s_ready[1];
        assign s_data[DATA_WIDTH*1 +: DATA_WIDTH] = S01_AXIS_tdata;
    end else begin
        assign S01_AXIS_tready = 1'b0;
    end

    assign M00_AXIS_tvalid = m_valid[0];
    assign m_ready[0] = M00_AXIS_tready;
    assign M00_AXIS_tdata = m_data[DATA_WIDTH*0 +: DATA_WIDTH];

    axis_switch #(
        .NSLAVES(NSLAVES),
        .NMASTERS(NMASTERS),
        .REG_PIPELINE_DEPTH(0),
        .SINGLE_ST(0),
        .DATA_WIDTH(DATA_WIDTH),
        .HAS_ID(0),
        .HAS_LAST(0),
        .HAS_DEST(0)
    )
    switch (
        .aclk(clk),
        .aresetn(rstn),
        .s_valid(s_valid),
        .s_ready(s_ready),
        .s_data(s_data),
        .s_dest('0),
        .s_id('0),
        .s_last('0),
        .m_valid(m_valid),
        .m_ready(m_ready),
        .m_data(m_data),
        .m_dest(),
        .m_id(),
        .m_last()
    );

endmodule
