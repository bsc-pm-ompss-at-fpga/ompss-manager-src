
module axis_switch
#(
    parameter NSLAVES = 2,
    parameter NMASTERS = 1,
    parameter REG_PIPELINE_DEPTH = 1,
    parameter SINGLE_ST = 0,
    parameter DATA_WIDTH = 64,
    parameter HAS_DEST = 0,
    parameter HAS_ID = 0,
    parameter HAS_LAST = 0,
    parameter ID_WIDTH = 1,
    parameter DEST_WIDTH = 1,
    parameter DEST_BASE = 0,
    parameter DEST_STRIDE = 1,
    parameter DEST_RANGE = 0
)
(
    input aclk,
    input aresetn,
    input  logic [NSLAVES-1:0] s_valid,
    output logic [NSLAVES-1:0] s_ready,
    input  logic [NSLAVES*DATA_WIDTH-1:0] s_data,
    input  logic [NSLAVES*DEST_WIDTH-1:0] s_dest,
    input  logic [NSLAVES*ID_WIDTH-1:0] s_id,
    input  logic [NSLAVES-1:0] s_last,
    output logic [NMASTERS-1:0] m_valid,
    input  logic [NMASTERS-1:0] m_ready,
    output logic [NMASTERS*DATA_WIDTH-1:0] m_data,
    output logic [NMASTERS*DEST_WIDTH-1:0] m_dest,
    output logic [NMASTERS*ID_WIDTH-1:0] m_id,
    output logic [NMASTERS-1:0] m_last
);

    logic [NSLAVES-1:0] s_reg_valid;
    logic [NSLAVES-1:0] s_reg_ready;
    logic [NSLAVES*DATA_WIDTH-1:0] s_reg_data;
    logic [NSLAVES*DEST_WIDTH-1:0] s_reg_dest;
    logic [NSLAVES*ID_WIDTH-1:0] s_reg_id;
    logic [NSLAVES-1:0] s_reg_last;

    logic [NMASTERS-1:0] m_reg_valid;
    logic [NMASTERS-1:0] m_reg_ready;
    logic [NMASTERS*DATA_WIDTH-1:0] m_reg_data;
    logic [NMASTERS*DEST_WIDTH-1:0] m_reg_dest;
    logic [NMASTERS*ID_WIDTH-1:0] m_reg_id;
    logic [NMASTERS-1:0] m_reg_last;

    genvar i;
    generate
    for (i = 0; i < NSLAVES; i = i+1) begin : SLAVE_REGISTERS
        axis_register_pipeline #(
            .DEPTH(REG_PIPELINE_DEPTH),
            .DATA_WIDTH(DATA_WIDTH),
            .DEST_WIDTH(DEST_WIDTH),
            .ID_WIDTH(ID_WIDTH),
            .HAS_ID(HAS_ID),
            .HAS_DEST(HAS_DEST),
            .HAS_LAST(HAS_LAST)
        )
        REGISTER_PIPELINE_SLAVES (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_valid(s_valid[i]),
            .s_ready(s_ready[i]),
            .s_data(s_data[i*DATA_WIDTH +: DATA_WIDTH]),
            .s_dest(s_dest[i*DEST_WIDTH +: DEST_WIDTH]),
            .s_id(s_id[i*ID_WIDTH +: ID_WIDTH]),
            .s_last(s_last[i]),
            .m_valid(s_reg_valid[i]),
            .m_ready(s_reg_ready[i]),
            .m_data(s_reg_data[i*DATA_WIDTH +: DATA_WIDTH]),
            .m_dest(s_reg_dest[i*DEST_WIDTH +: DEST_WIDTH]),
            .m_id(s_reg_id[i*ID_WIDTH +: ID_WIDTH]),
            .m_last(s_reg_last[i])
        );
    end
    endgenerate

    generate
    for (i = 0; i < NMASTERS; i = i+1) begin : MASTER_REGISTERS
        axis_register_pipeline #(
            .DEPTH(REG_PIPELINE_DEPTH),
            .DATA_WIDTH(DATA_WIDTH),
            .DEST_WIDTH(DEST_WIDTH),
            .ID_WIDTH(ID_WIDTH),
            .HAS_ID(HAS_ID),
            .HAS_DEST(HAS_DEST),
            .HAS_LAST(HAS_LAST)
        )
        REGISTER_PIPELINE_MASTERS (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_valid(m_reg_valid[i]),
            .s_ready(m_reg_ready[i]),
            .s_data(m_reg_data[i*DATA_WIDTH +: DATA_WIDTH]),
            .s_dest(m_reg_dest[i*DEST_WIDTH +: DEST_WIDTH]),
            .s_id(m_reg_id[i*ID_WIDTH +: ID_WIDTH]),
            .s_last(m_reg_last[i]),
            .m_valid(m_valid[i]),
            .m_ready(m_ready[i]),
            .m_data(m_data[i*DATA_WIDTH +: DATA_WIDTH]),
            .m_dest(m_dest[i*DEST_WIDTH +: DEST_WIDTH]),
            .m_id(m_id[i*ID_WIDTH +: ID_WIDTH]),
            .m_last(m_last[i])
        );
    end
    endgenerate

    if (SINGLE_ST) begin

        axis_switch_single_st #(
            .NSLAVES(NSLAVES),
            .NMASTERS(NMASTERS),
            .HAS_ID(HAS_ID),
            .HAS_LAST(HAS_LAST),
            .HAS_DEST(HAS_DEST),
            .DATA_WIDTH(DATA_WIDTH),
            .DEST_WIDTH(DEST_WIDTH),
            .ID_WIDTH(ID_WIDTH),
            .DEST_BASE(DEST_BASE),
            .DEST_STRIDE(DEST_STRIDE),
            .DEST_RANGE(DEST_RANGE)
        )
        master_switch (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_valid(s_reg_valid),
            .s_ready(s_reg_ready),
            .s_data(s_reg_data),
            .s_dest(s_reg_dest),
            .s_id(s_reg_id),
            .s_last(s_reg_last),
            .m_valid(m_reg_valid),
            .m_ready(m_reg_ready),
            .m_data(m_reg_data),
            .m_dest(m_reg_dest),
            .m_id(m_reg_id),
            .m_last(m_reg_last)
        );

    end
    else begin

    wire [NMASTERS*NSLAVES-1:0] s_fil_ready;

    for (i = 0; i < NMASTERS; i = i+1) begin : MASTER_LOOP

        logic [NSLAVES-1:0] s_fil_valid; //fil --> filtered

        genvar j;
        for (j = 0; j < NSLAVES; j = j+1) begin : SLAVE_LOOP
            wire [DEST_WIDTH-1:0] dest_val;
            assign dest_val = s_reg_dest[j*DEST_WIDTH +: DEST_WIDTH];
            if (NMASTERS == 1) begin
                assign s_fil_valid[j] = s_reg_valid[j];
            end else if (DEST_RANGE == 0) begin
                assign s_fil_valid[j] = s_reg_valid[j] &&
                        dest_val == DEST_BASE + i*DEST_STRIDE;
            end else begin
                assign s_fil_valid[j] = s_reg_valid[j] &&
                        dest_val >= DEST_BASE + i*DEST_STRIDE &&
                        dest_val <= DEST_BASE + i*DEST_STRIDE + DEST_RANGE;
            end
        end

        axis_switch_single_master #(
            .NSLAVES(NSLAVES),
            .HAS_ID(HAS_ID),
            .HAS_LAST(HAS_LAST),
            .HAS_DEST(HAS_DEST),
            .DATA_WIDTH(DATA_WIDTH),
            .DEST_WIDTH(DEST_WIDTH),
            .ID_WIDTH(ID_WIDTH)
        )
        master_switch (
            .aclk(aclk),
            .aresetn(aresetn),
            .s_valid(s_fil_valid),
            .s_ready(s_fil_ready[i*NSLAVES +: NSLAVES]),
            .s_data(s_reg_data),
            .s_dest(s_reg_dest),
            .s_id(s_reg_id),
            .s_last(s_reg_last),
            .m_valid(m_reg_valid[i]),
            .m_ready(m_reg_ready[i]),
            .m_data(m_reg_data[i*DATA_WIDTH +: DATA_WIDTH]),
            .m_dest(m_reg_dest[i*DEST_WIDTH +: DEST_WIDTH]),
            .m_id(m_reg_id[i*ID_WIDTH +: ID_WIDTH]),
            .m_last(m_reg_last[i])
        );

    end

    for (i = 0; i < NSLAVES; i = i+1) begin : READY_GEN

        if (NSLAVES == 1) begin

            if (NMASTERS == 1) begin
                assign s_reg_ready[0] = s_fil_ready[0];
            end else begin

            int k;
            always_comb begin
                s_reg_ready[i] = 0;
                for (k = 0; k < NMASTERS; k = k+1) begin
                    if (DEST_RANGE == 0) begin
                        if (s_reg_dest == k*DEST_STRIDE + DEST_BASE) begin
                            s_reg_ready[i] = s_fil_ready[k*NSLAVES + i];
                        end
                    end else begin
                        if (s_reg_dest >= k*DEST_STRIDE + DEST_BASE &&
                            s_reg_dest <= k*DEST_STRIDE + DEST_BASE + DEST_RANGE) begin
                            s_reg_ready[i] = s_fil_ready[k*NSLAVES + i];
                        end
                    end
                end
            end

            end

        end else begin

            wire [NMASTERS-1:0] s_fil_ready_serial;

            genvar j;
            for (j = 0; j < NMASTERS; j = j+1) begin
                assign s_fil_ready_serial[j] = s_fil_ready[j*NSLAVES + i];
            end

            assign s_reg_ready[i] = |s_fil_ready_serial;

        end

    end
    end

endmodule