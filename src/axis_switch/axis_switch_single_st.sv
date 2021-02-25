`timescale 1ns / 1ps

module axis_switch_single_st
#(
    parameter NSLAVES = 2,
    parameter NMASTERS = 1,
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

    if (NMASTERS == 1) begin
    
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
            .s_valid(s_valid),
            .s_ready(s_ready),
            .s_data(s_data),
            .s_dest(s_dest),
            .s_id(s_id),
            .s_last(s_last),
            .m_valid(m_valid[0]),
            .m_ready(m_ready[0]),
            .m_data(m_data),
            .m_dest(m_dest),
            .m_id(m_id),
            .m_last(m_last[0])
        );
    
    end else if (NSLAVES == 1) begin
    
        axis_switch_single_slave #(
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
            .s_valid(s_valid[0]),
            .s_ready(s_ready[0]),
            .s_data(s_data),
            .s_dest(s_dest),
            .s_id(s_id),
            .s_last(s_last[0]),
            .m_valid(m_valid),
            .m_ready(m_ready),
            .m_data(m_data),
            .m_dest(m_dest),
            .m_id(m_id),
            .m_last(m_last)
        );
    
    end else begin
    
    enum {
        IDLE,
        TRANSACTION
    } state;
    
    localparam SEL_SLAVE_BITS = $clog2(NSLAVES);
    localparam SEL_MASTER_BITS = $clog2(NMASTERS);
    
    wire in_transaction;
    reg [DATA_WIDTH-1:0] common_m_data;
    reg common_m_last;
    reg [DEST_WIDTH-1:0] common_m_dest;
    reg [ID_WIDTH-1:0] common_m_id;
    reg [SEL_SLAVE_BITS-1:0] sel_slave;
    reg [SEL_MASTER_BITS-1:0] sel_master;
    
    assign in_transaction = state == TRANSACTION;
    
    genvar s;
    for (s = 0; s < NSLAVES; s = s+1) begin : SLAVES_READY_SIGNAL
        always_comb begin
            int j;
            s_ready[s] = 0;
            for (j = 0; j < NMASTERS; j = j+1) begin
                if (in_transaction && sel_slave == s && sel_master == j) begin
                    s_ready[s] = m_ready[j];
                end
            end
        end
    end
    
    genvar m;
    for (m = 0; m < NMASTERS; m = m+1) begin : MASTERS_DATA_SWITCH
        assign m_data[m*DATA_WIDTH +: DATA_WIDTH] = common_m_data;
        assign m_last[m] = common_m_last;
        assign m_id[m*ID_WIDTH +: ID_WIDTH] = common_m_id;
        
        always_comb begin
            int j1;
            m_valid[m] = 0;
            for (j1 = 0; j1 < NSLAVES; j1 = j1+1) begin
                if (in_transaction && sel_master == m && sel_slave == j1) begin
                    m_valid[m] = s_valid[j1];
                end
            end
        end
    end
    
    always_comb begin
        int j2;
        common_m_data = s_data[DATA_WIDTH-1 : 0];
        if (HAS_DEST) begin
            common_m_dest = s_dest[DEST_WIDTH-1 : 0];
        end
        if (HAS_LAST) begin
            common_m_last = s_last[0];
        end
        if (HAS_ID) begin
            common_m_id = s_id[ID_WIDTH-1:0];
        end

        for (j2 = 1; j2 < NSLAVES; j2 = j2+1) begin
            if (sel_slave == j2) begin
                common_m_data = s_data[j2*DATA_WIDTH +: DATA_WIDTH];
                if (HAS_DEST) begin
                    common_m_dest = s_dest[j2*DEST_WIDTH +: DEST_WIDTH];
                end
                if (HAS_LAST) begin
                    m_last[m] = s_last[j2];
                end
                if (HAS_ID) begin
                    m_id[m*ID_WIDTH +: ID_WIDTH] = s_id[j2*ID_WIDTH +: ID_WIDTH];
                end
            end
        end
    end
        
    always_ff @(posedge aclk) begin
    
        case (state)
        
            IDLE: begin
                int i, j;

                for (j = 0; j < NSLAVES; j = j+1) begin
                
                    for (i = 0; i < NMASTERS; i = i+1) begin
                        if (DEST_RANGE == 0) begin
                            if (s_dest[j] == DEST_BASE + i*DEST_STRIDE) begin
                                sel_master <= i;
                            end
                        end else begin
                            if (s_dest[j] >= DEST_BASE + i*DEST_STRIDE &&
                                s_dest[j] <= DEST_BASE + i*DEST_STRIDE + DEST_RANGE) begin
                                sel_master <= i;
                            end
                        end
                    end
                
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
                    end
                end else begin
                    int i, j;
                    for (j = 0; j < NSLAVES; j = j+1) begin
                        for (i = 0; i < NMASTERS; i = i+1) begin
                            if (sel_slave == j && s_last[j] && s_valid[j] && sel_master == i && m_ready[i]) begin
                                state <= IDLE;
                            end
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
