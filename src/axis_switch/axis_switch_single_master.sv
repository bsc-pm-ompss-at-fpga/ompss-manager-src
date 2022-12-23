
module axis_switch_single_master
#(
    parameter NSLAVES = 2,
    parameter DATA_WIDTH = 64,
    parameter DEST_WIDTH = 1,
    parameter ID_WIDTH = 1,
    parameter HAS_ID = 0,
    parameter HAS_LAST = 0,
    parameter HAS_DEST = 0
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
    output logic m_valid,
    input  logic m_ready,
    output logic [DATA_WIDTH-1:0] m_data,
    output logic [DEST_WIDTH-1:0] m_dest,
    output logic [ID_WIDTH-1:0] m_id,
    output logic m_last
);

    if (NSLAVES == 1) begin

        assign m_valid = s_valid[0];
        assign s_ready[0] = m_ready;
        assign m_data = s_data;
        if (HAS_DEST) begin
            assign m_dest = s_dest;
        end else begin
            assign m_dest = '0;
        end
        if (HAS_LAST) begin
            assign m_last = s_last;
        end else begin
            assign m_last = '0;
        end
        if (HAS_ID) begin
            assign m_id = s_id;
        end else begin
            assign m_id = '0;
        end

    end else begin

    typedef enum bit [0:0] {
        IDLE,
        TRANSACTION
    } State_t;

    State_t state;

    localparam SEL_SLAVE_BITS = $clog2(NSLAVES+1);
    localparam NONE_SEL_VAL = {SEL_SLAVE_BITS{1'b1}};

    reg [SEL_SLAVE_BITS-1:0] sel_slave;

    for (genvar i = 0; i < NSLAVES; ++i) begin : SLAVES_READY_SIGNAL
        always_comb begin
            if (sel_slave == i) begin
                s_ready[i] = m_ready;
            end else begin
                s_ready[i] = 0;
            end
        end
    end

    always_comb begin
        m_data = s_data[DATA_WIDTH-1 : 0];
        if (HAS_DEST) begin
            m_dest = s_dest[DEST_WIDTH-1 : 0];
        end else begin
            m_dest = '0;
        end
        if (HAS_LAST) begin
            m_last = s_last[0];
        end else begin
            m_last = '0;
        end
        if (HAS_ID) begin
            m_id = s_id[ID_WIDTH-1:0];
        end else begin
            m_id = '0;
        end
        m_valid = 0;
        for (int j = 0; j < NSLAVES; ++j) begin
            if (sel_slave == j) begin
                m_valid = s_valid[j];
            end
        end
        for (int j = 1; j < NSLAVES; ++j) begin
            if (sel_slave == j) begin
                m_data = s_data[j*DATA_WIDTH +: DATA_WIDTH];
                if (HAS_DEST) begin
                    m_dest = s_dest[j*DEST_WIDTH +: DEST_WIDTH];
                end
                if (HAS_LAST) begin
                    m_last = s_last[j];
                end
                if (HAS_ID) begin
                    m_id = s_id[j*ID_WIDTH +: ID_WIDTH];
                end
            end
        end
    end

    always_ff @(posedge aclk) begin

        case (state)

            IDLE: begin
                for (int j = 0; j < NSLAVES; ++j) begin
                    if (s_valid[j]) begin
                        sel_slave <= j;
                        state <= TRANSACTION;
                        break;
                    end
                end
            end

            TRANSACTION: begin
                if (!HAS_LAST) begin
                    if (m_ready) begin
                        state <= IDLE;
                        sel_slave <= NONE_SEL_VAL;
                    end
                end else begin
                    for (int j = 0; j < NSLAVES; ++j) begin
                        if (sel_slave == j && s_last[j] && s_valid[j] && m_ready) begin
                            state <= IDLE;
                            sel_slave <= NONE_SEL_VAL;
                        end
                    end
                end
            end

        endcase

        if (!aresetn) begin
            state <= IDLE;
            sel_slave <= NONE_SEL_VAL;
        end
    end

    end

endmodule
