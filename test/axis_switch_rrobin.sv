`timescale 1ns / 1ps

module axis_switch_rrobin#(
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
    
        
    wire [NMASTERS*NSLAVES-1:0] s_fil_ready;
    
    genvar i;
    for (i = 0; i < NMASTERS; i = i+1) begin : MASTER_LOOP
    
        logic [NSLAVES-1:0] s_fil_valid; //fil --> filtered
        
        genvar j;
        for (j = 0; j < NSLAVES; j = j+1) begin : SLAVE_LOOP
            wire [DEST_WIDTH-1:0] dest_val;
            assign dest_val = s_dest[j*DEST_WIDTH +: DEST_WIDTH];
            if (NMASTERS == 1) begin
                assign s_fil_valid[j] = s_valid[j];
            end else if (DEST_RANGE == 0) begin
                assign s_fil_valid[j] = s_valid[j] &&
                        dest_val == DEST_BASE + i*DEST_STRIDE;
            end else begin
                assign s_fil_valid[j] = s_valid[j] &&
                        dest_val >= DEST_BASE + i*DEST_STRIDE &&
                        dest_val <= DEST_BASE + i*DEST_STRIDE + DEST_RANGE;
            end
        end
    
        axis_switch_single_master_rrobin #(
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
            .s_data(s_data),
            .s_dest(s_dest),
            .s_id(s_id),
            .s_last(s_last),
            .m_valid(m_valid[i]),
            .m_ready(m_ready[i]),
            .m_data(m_data[i*DATA_WIDTH +: DATA_WIDTH]),
            .m_dest(m_dest[i*DEST_WIDTH +: DEST_WIDTH]),
            .m_id(m_id[i*ID_WIDTH +: ID_WIDTH]),
            .m_last(m_last[i])
        );
        
    end
        
    for (i = 0; i < NSLAVES; i = i+1) begin : READY_GEN
    
        if (NSLAVES == 1) begin
        
            if (NMASTERS == 1) begin
                assign s_ready[0] = s_fil_ready[0];
            end else begin
            
            int k;
            always_comb begin
                s_ready[i] = 0;
                for (k = 0; k < NMASTERS; k = k+1) begin
                    if (DEST_RANGE == 0) begin
                        if (s_dest == k*DEST_STRIDE + DEST_BASE) begin
                            s_ready[i] = s_fil_ready[k*NSLAVES + i];
                        end
                    end else begin
                        if (s_dest >= k*DEST_STRIDE + DEST_BASE &&
                            s_dest <= k*DEST_STRIDE + DEST_BASE + DEST_RANGE) begin
                            s_ready[i] = s_fil_ready[k*NSLAVES + i];
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
            
            assign s_ready[i] = |s_fil_ready_serial;
             
        end
    
    end
    
endmodule