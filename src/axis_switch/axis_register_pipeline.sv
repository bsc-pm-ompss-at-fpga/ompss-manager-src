
module axis_register_pipeline
#(
    parameter DEPTH = 1,
    parameter HAS_DEST = 0,
    parameter HAS_ID = 0,
    parameter HAS_LAST = 0,
    parameter DATA_WIDTH = 64,
    parameter DEST_WIDTH = 1,
    parameter ID_WIDTH = 1
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
    output logic m_valid,
    input  logic m_ready,
    output logic [DATA_WIDTH-1:0] m_data,
    output logic [DEST_WIDTH-1:0] m_dest,
    output logic [ID_WIDTH-1:0] m_id,
    output logic m_last
);

    if (DEPTH == 0) begin

        assign m_valid = s_valid;
        assign s_ready = m_ready;
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

    reg [DATA_WIDTH-1:0] data_buf[DEPTH];
    reg [DEPTH-1:0] buf_full;

    assign m_data = data_buf[DEPTH-1];

    always_comb begin
        m_valid = 0;
        s_ready = 0;
        if (!buf_full[0]) begin
            s_ready = 1;
        end
        if (buf_full[DEPTH-1]) begin
            m_valid = 1;
        end
    end

    always_ff @(posedge aclk) begin
        int i;

        if (!buf_full[0]) begin
            data_buf[0] <= s_data;
        end

        if (s_valid && !buf_full[0]) begin
            buf_full[0] <= 1;
        end

        for (i = 0; i < DEPTH-1; i = i+1) begin
            if (!buf_full[i+1]) begin
                data_buf[i+1] <= data_buf[i];
            end
            if (buf_full[i] && !buf_full[i+1]) begin
                buf_full[i] <= 0;
                buf_full[i+1] <= 1;
            end
        end

        if (buf_full[DEPTH-1] && m_ready) begin
            buf_full[DEPTH-1] <= 0;
        end

        if (!aresetn) begin
            for (i = 0; i < DEPTH; i = i+1) begin
                buf_full[i] <= 0;
            end
        end
    end

    if (HAS_DEST) begin
        reg [DEST_WIDTH-1:0] dest_buf[DEPTH];
        assign m_dest = dest_buf[DEPTH-1];

        always_ff @(posedge aclk) begin
            int i;

            if (!buf_full[0]) begin
                dest_buf[0] <= s_dest;
            end
            for (i = 0; i < DEPTH-1; i = i+1) begin
                if (!buf_full[i+1]) begin
                    dest_buf[i+1] <= dest_buf[i];
                end
            end
        end
    end else begin
        assign m_dest = '0;
    end
    if (HAS_LAST) begin
        reg [DEPTH-1:0] last_buf;

        assign m_last = last_buf[DEPTH-1];

        always_ff @(posedge aclk) begin
            int i;

            if (!buf_full[0]) begin
                last_buf[0] <= s_last;
            end
            for (i = 0; i < DEPTH-1; i = i+1) begin
                if (!buf_full[i+1]) begin
                    last_buf[i+1] <= last_buf[i];
                end
            end
        end
    end else begin
        assign m_last = '0;
    end
    if (HAS_ID) begin
        reg [ID_WIDTH-1:0] id_buf[DEPTH];

        assign m_id = id_buf[DEPTH-1];

        always_ff @(posedge aclk) begin
            int i;

            if (!buf_full[0]) begin
                id_buf[0] <= s_id;
            end
            for (i = 0; i < DEPTH-1; i = i+1) begin
                if (!buf_full[i+1]) begin
                    id_buf[i+1] <= id_buf[i];
                end
            end
        end
    end else begin
        assign m_id = '0;
    end

    end

endmodule