`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/17/2020 10:27:50 AM
// Design Name: 
// Module Name: pom_gw
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module pom_gw #(
    parameter TW_INFO_SIZE = 16
)
(
    input clk,
    input aresetn,
    input picos_full,
    
    input ext_inStream_tvalid,
    output reg ext_inStream_tready,
    input [63:0] ext_inStream_tdata,
    input ext_inStream_tlast,
    input [4:0] ext_inStream_tid,
    input [4:0] ext_inStream_tdest,
    
    output sched_inStream_tvalid,
    input sched_inStream_tready,
    output [63:0] sched_inStream_tdata,
    output sched_inStream_tlast,
    output [4:0] sched_inStream_tid,
    
    output deps_new_task_tvalid,
    input deps_new_task_tready,
    output [63:0] deps_new_task_tdata,
    
    output ack_tvalid,
    input ack_tready,
    output reg[7:0] ack_tdata,
    output [4:0] ack_tdest,
    
    output [31:0] tw_info_addr,
    output reg tw_info_en,
    output reg [15:0] tw_info_we,
    output reg [127:0] tw_info_din,
    output tw_info_clk,
    input [127:0] tw_info_dout
);

    localparam TASK_NUM_L = 32;
    localparam VALID_ENTRY_B = 7;
    localparam ACC_ID_L = 48;
    localparam ACC_ID_H = 55;
    
    localparam VALID_ENTRY_L = 0;
    localparam VALID_ENTRY_H = 7;
    localparam TW_INFO_ACC_ID_L = 8;
    localparam COMPONENTS_L = 32;
    localparam COMPONENTS_H = 63;
    localparam TASKID_L = 64;
    localparam TASKID_H = 127;
    
    localparam ACK_OK_CODE = 8'h01;
    localparam ACK_REJECT_CODE = 8'h00;
    localparam ACK_FINAL_CODE = 8'h02;

    localparam IDLE = 0;
    localparam SEARCH_ENTRY = 1;
    localparam SEARCH_FREE_ENTRY = 2;
    localparam CREATE_ENTRY = 3;
    localparam READ_PTID = 4;
    localparam READ_REST = 5;
    localparam BUF_FULL = 6;
    localparam BUF_EMPTY = 7;
    localparam ACK = 8;
    localparam WAIT_PICOS = 9;
    
    localparam HWR_DEPS_ID = 5'h12;
    localparam HWR_SCHED_ID = 5'h13;
    
    reg [3:0] state;
    
    reg[$clog2(TW_INFO_SIZE*16)-1:0] tw_info_true_addr;
    reg[$clog2(TW_INFO_SIZE*16)-1:0] tw_info_addr_delay;
    reg[4:0] acc_id;
    reg[63:0] buf_tdata;
    reg buf_tlast;
    reg[63:0] tid;
    reg first_task;
    reg accept;
    reg final_mode;
    reg deps_selected;
    wire selected_slave_tready;
    reg selected_slave_tvalid;
    reg empty_entry_found;
    reg [$clog2(TW_INFO_SIZE*16)-1:0] empty_entry;
    
    assign tw_info_clk = clk;
    assign tw_info_addr = {{32-$clog2(TW_INFO_SIZE*16){1'b0}}, tw_info_true_addr};
    
    assign ack_tvalid = state == ACK;
    assign ack_tdest = acc_id;
    
    assign selected_slave_tready = deps_selected ? deps_new_task_tready : sched_inStream_tready;
    
    assign sched_inStream_tvalid = selected_slave_tvalid && !deps_selected;
    assign sched_inStream_tdata = buf_tdata;
    assign sched_inStream_tlast = buf_tlast;
    assign sched_inStream_tid = acc_id;
    assign deps_new_task_tvalid = selected_slave_tvalid && deps_selected;
    assign deps_new_task_tdata = buf_tdata;
    
    always @(*) begin
    
        tw_info_en = 0;
        tw_info_we = 0;
        
        tw_info_din = 0;
        tw_info_din[VALID_ENTRY_H:VALID_ENTRY_L] = 8'h80;
        tw_info_din[TW_INFO_ACC_ID_L+4:TW_INFO_ACC_ID_L] = acc_id;
        tw_info_din[COMPONENTS_H:COMPONENTS_L] = 0;
        tw_info_din[TASKID_H:TASKID_L] = tid;
        
        ack_tdata = ACK_REJECT_CODE;
        if (accept) begin
            ack_tdata = ACK_OK_CODE;
        end else if (final_mode) begin
            ack_tdata = ACK_FINAL_CODE;
        end
        
        ext_inStream_tready = 0;
        selected_slave_tvalid = 0;
        case (state)
        
            IDLE: begin
                ext_inStream_tready = 1;
            end
            
            READ_PTID: begin
                tw_info_en = 1;
            end
            
            SEARCH_FREE_ENTRY: begin
                tw_info_en = 1;
            end
            
            SEARCH_ENTRY: begin
                tw_info_en = 1;
            end
            
            CREATE_ENTRY: begin
                tw_info_en = 1;
                tw_info_we = 16'hFFFF;
            end
            
            READ_REST: begin
                ext_inStream_tready = 1;
            end
            
            BUF_FULL: begin
                selected_slave_tvalid = 1;
                if (selected_slave_tready && !buf_tlast) begin
                    ext_inStream_tready = 1;
                end else begin
                    ext_inStream_tready = 0;
                end
            end
            
            BUF_EMPTY: begin
                ext_inStream_tready = 1;
            end
            
        endcase
    end
    
    always @(posedge clk) begin
    
        tw_info_addr_delay <= tw_info_true_addr;

        case (state)
        
            IDLE: begin
                tw_info_true_addr <= 0;
                empty_entry_found <= 0;
                acc_id <= ext_inStream_tid;
                deps_selected <= ext_inStream_tdest == HWR_DEPS_ID;
                buf_tdata <= ext_inStream_tdata;
                buf_tlast <= 0;
                if (ext_inStream_tdata[TASK_NUM_L+31:TASK_NUM_L] == 0) begin
                    first_task <= 1;
                end else begin
                    first_task <= 0;
                end
                if (ext_inStream_tvalid) begin
                    if (ext_inStream_tdata[TASK_NUM_L+31:TASK_NUM_L] == 0) begin
                        state <= READ_PTID;
                    end else if (ext_inStream_tdest == HWR_DEPS_ID && !picos_full && deps_new_task_tready) begin
                        state <= BUF_FULL;
                    end else if (ext_inStream_tdest == HWR_DEPS_ID && !deps_new_task_tready) begin
                        state <= WAIT_PICOS;
                    end else if (ext_inStream_tdest == HWR_DEPS_ID && picos_full) begin
                        state <= READ_PTID;
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end
            
            READ_PTID: begin
                tid <= ext_inStream_tdata;
                if (ext_inStream_tvalid) begin
                    tw_info_true_addr <= 16;
                    if (first_task) begin
                        state <= SEARCH_FREE_ENTRY;
                    end else begin
                        state <= SEARCH_ENTRY;
                    end
                end
            end
            
            SEARCH_FREE_ENTRY: begin
                final_mode <= 0;
                if (!tw_info_dout[VALID_ENTRY_B] && !empty_entry_found) begin
                    empty_entry <= tw_info_addr_delay;
                    empty_entry_found <= 1;
                end
                if (tw_info_addr_delay == TW_INFO_SIZE*16 - 16) begin
                    if (!tw_info_dout[VALID_ENTRY_B] && !empty_entry_found) begin
                        tw_info_true_addr <= TW_INFO_SIZE*16 - 16;
                        state <= CREATE_ENTRY;
                    end else if (empty_entry_found) begin
                        tw_info_true_addr <= empty_entry;
                        state <= CREATE_ENTRY;
                    end else begin
                        state <= READ_REST;
                    end
                end else begin
                    tw_info_true_addr <= tw_info_true_addr + 16;
                end
                if (tw_info_dout[VALID_ENTRY_B] && tw_info_dout[TASKID_H:TASKID_L] == tid) begin
                    if (deps_selected) begin
                        state <= WAIT_PICOS;
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end
            
            WAIT_PICOS: begin
                final_mode <= 1;
                if (deps_new_task_tready) begin
                    if (picos_full) begin
                        if (first_task) begin
                            state <= READ_REST;
                        end else begin
                            state <= READ_PTID;
                        end
                    end else begin
                        state <= BUF_FULL;
                    end
                end
            end
            
            CREATE_ENTRY: begin
                if (deps_selected) begin
                   state <= WAIT_PICOS;
                end else begin
                    state <= BUF_FULL;
                end
            end
            
            SEARCH_ENTRY: begin
                final_mode <= tw_info_dout[COMPONENTS_H:COMPONENTS_L] == buf_tdata[TASK_NUM_L+31:TASK_NUM_L];
                if (tw_info_din[VALID_ENTRY_B] && tw_info_dout[TASKID_H:TASKID_L] == tid) begin
                    state <= READ_REST;
                end
                tw_info_true_addr <= tw_info_true_addr + 16;
            end
            
            READ_REST: begin
                accept <= 0;
                if (ext_inStream_tvalid && ext_inStream_tlast) begin
                    state <= ACK;
                end
            end
            
            BUF_FULL: begin
                accept <= 1;
                if (!ext_inStream_tvalid && selected_slave_tready && !buf_tlast) begin
                    state <= BUF_EMPTY;
                end else if (selected_slave_tready && buf_tlast) begin
                    if (deps_selected) begin
                        state <= ACK;
                    end else begin
                        state <= IDLE;
                    end
                end
                if (ext_inStream_tvalid && selected_slave_tready) begin
                    buf_tdata <= ext_inStream_tdata;
                    buf_tlast <= ext_inStream_tlast;
                end
            end
            
            BUF_EMPTY: begin
                buf_tdata <= ext_inStream_tdata;
                buf_tlast <= ext_inStream_tlast;
                if (ext_inStream_tvalid) begin
                    state <= BUF_FULL;
                end
            end
            
            ACK: begin
                if (ack_tready) begin
                    state <= IDLE;
                end
            end
            
        endcase
    
        if (!aresetn) begin
            state <= IDLE;
        end
    end

endmodule

