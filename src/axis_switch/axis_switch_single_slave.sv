
module axis_switch_single_slave
#(
    parameter NMASTERS = 2,
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
    input  logic s_valid,
    output logic s_ready,
    input  logic [DATA_WIDTH-1:0] s_data,
    input  logic [DEST_WIDTH-1:0] s_dest,
    input  logic [ID_WIDTH-1:0] s_id,
    input  logic s_last,
    output logic [NMASTERS-1:0] m_valid,
    input  logic [NMASTERS-1:0] m_ready,
    output logic [NMASTERS*DATA_WIDTH-1:0] m_data,
    output logic [NMASTERS*DEST_WIDTH-1:0] m_dest,
    output logic [NMASTERS*ID_WIDTH-1:0] m_id,
    output logic [NMASTERS-1:0] m_last
);

    if (NMASTERS == 1) begin

        assign m_valid[0] = s_valid;
        assign s_ready = m_ready[0];
        assign m_data = s_data;
        if (HAS_DEST) begin
            assign m_dest = s_dest;
        end
        if (HAS_LAST) begin
            assign m_last = s_last;
        end
        if (HAS_ID) begin
            assign m_id = s_id;
        end

    end else begin

    typedef enum bit [0:0] {
        IDLE,
        TRANSACTION
    } State_t;

    State_t state;

    localparam SEL_MASTER_BITS = $clog2(NMASTERS);

    wire in_transaction;
    reg [SEL_MASTER_BITS-1:0] sel_master;

    assign in_transaction = state == TRANSACTION;

    always_comb begin
        int j;
        s_ready = 0;
        for (j = 0; j < NMASTERS; j = j+1) begin
            if (in_transaction && sel_master == j) begin
                s_ready = m_ready[j];
            end
        end
    end

    genvar m;
    for (m = 0; m < NMASTERS; m = m+1) begin : MASTERS_DATA_ASSIGN

        always_comb begin
            int j1, j2;
            m_data[m*DATA_WIDTH +: DATA_WIDTH] = s_data;
            if (HAS_DEST) begin
                m_dest[m*DEST_WIDTH +: DEST_WIDTH] = s_dest;
            end
            if (HAS_LAST) begin
                m_last[m] = s_last;
            end
            if (HAS_ID) begin
                m_id[m*ID_WIDTH +: ID_WIDTH] = s_id;
            end
            m_valid[m] = 0;
            if (in_transaction && sel_master == m) begin
                m_valid[m] = s_valid;
            end
        end

    end

    always_ff @(posedge aclk) begin

        case (state)

            IDLE: begin
                int i;

                for (i = 0; i < NMASTERS; i = i+1) begin
                    if (DEST_RANGE == 0) begin
                        if (s_dest == DEST_BASE + i*DEST_STRIDE) begin
                            sel_master <= i;
                        end
                    end else begin
                        if (s_dest >= DEST_BASE + i*DEST_STRIDE &&
                            s_dest <= DEST_BASE + i*DEST_STRIDE + DEST_RANGE) begin
                            sel_master <= i;
                        end
                    end
                end

                if (s_valid) begin
                    state <= TRANSACTION;
                end
            end

            TRANSACTION: begin
                if (!HAS_LAST) begin
                    if (m_ready) begin
                        state <= IDLE;
                    end
                end else begin
                    int i;
                    for (i = 0; i < NMASTERS; i = i+1) begin
                        if (s_last && s_valid && sel_master == i && m_ready[i]) begin
                            state <= IDLE;
                        end
                    end
                end
            end

        endcase

        if (!aresetn) begin
            state <= IDLE;
        end
    end

    end

endmodule
