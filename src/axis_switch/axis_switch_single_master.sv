`timescale 1ns / 1ps

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
        end
        if (HAS_LAST) begin
            assign m_last = s_last;
        end
        if (HAS_ID) begin
            assign m_id = s_id;
        end
        
    end else begin

    enum {
        IDLE,
        TRANSACTION
    } state;
    
    localparam SEL_SLAVE_BITS = $clog2(NSLAVES+1);
    localparam NONE_SEL_VAL = {SEL_SLAVE_BITS{1'b1}};
    
    reg[SEL_SLAVE_BITS-1:0] sel_slave;
    
    genvar i;
    
    for (i = 0; i < NSLAVES; i = i+1) begin : SLAVES_READY_SIGNAL
        always_comb begin
            if (sel_slave == i) begin
                s_ready[i] = m_ready;
            end else begin
                s_ready[i] = 0;
            end
        end
    end
    
    always_comb begin
        int j1, j2;
        m_data = s_data[DATA_WIDTH-1 : 0];
        if (HAS_DEST) begin
            m_dest = s_dest[DEST_WIDTH-1 : 0];
        end
        if (HAS_LAST) begin
            m_last = s_last[0];
        end
        if (HAS_ID) begin
            m_id = s_id[ID_WIDTH-1:0];
        end
        m_valid = 0;
        for (j1 = 0; j1 < NSLAVES; j1 = j1+1) begin
            if (sel_slave == j1) begin
                m_valid = s_valid[j1];
            end
        end
        for (j2 = 1; j2 < NSLAVES; j2 = j2+1) begin
            if (sel_slave == j2) begin
                m_data = s_data[j2*DATA_WIDTH +: DATA_WIDTH];
                if (HAS_DEST) begin
                    m_dest = s_dest[j2*DEST_WIDTH +: DEST_WIDTH];
                end
                if (HAS_LAST) begin
                    m_last = s_last[j2];
                end
                if (HAS_ID) begin
                    m_id = s_id[j2*ID_WIDTH +: ID_WIDTH];
                end
            end
        end
    end
        
    always_ff @(posedge aclk) begin
    
        case (state)
        
            IDLE: begin
                int j;
                for (j = 0; j < NSLAVES; j = j+1) begin
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
                    int j;
                    for (j = 0; j < NSLAVES; j = j+1) begin
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
