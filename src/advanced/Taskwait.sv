/*--------------------------------------------------------------------
  Copyright (C) Barcelona Supercomputing Center
                Centro Nacional de Supercomputacion (BSC-CNS)

  All Rights Reserved.
  This file is part of OmpSs@FPGA toolchain.

  Unauthorized copying and/or distribution of this file,
  via any medium is strictly prohibited.
  The intellectual and technical concepts contained herein are
  propietary to BSC-CNS and may be covered by Patents.
--------------------------------------------------------------------*/


module Taskwait #(
    parameter ACC_BITS = 4,
    parameter MAX_ACC_CREATORS = 16,
    localparam TW_MEM_BITS = $clog2(MAX_ACC_CREATORS),
    localparam TW_MEM_WIDTH = 32
) (
    input clk,
    input rstn,
    //inStream
    input  [63:0] inStream_TDATA,
    input  inStream_TVALID,
    input  [ACC_BITS-1:0] inStream_TID,
    output logic inStream_TREADY,
    //outStream
    output [63:0] outStream_TDATA,
    output outStream_TVALID,
    input  outStream_TREADY,
    output [ACC_BITS-1:0] outStream_TDEST,
    //Taskwait memory
    output [TW_MEM_BITS-1:0] twInfo_addr,
    output logic twInfo_en,
    output twInfo_we,
    output logic [TW_MEM_WIDTH-1:0] twInfo_din,
    input  [TW_MEM_WIDTH-1:0] twInfo_dout
);

    import OmpSsManager::*;

    typedef enum bit [2:0] {
        READ_HEADER,
        READ_PTID,
        ISSUE_TW_MEM_READ,
        TW_MEM_READ,
        RESULT_COMPONENTS,
        CHECK_RESULTS,
        WAKEUP_ACC
    } State_t;

    State_t state;

    reg [31:0] components;
    reg [31:0] tw_info_components;
    reg [31:0] result_components;
    reg [ACC_BITS-1:0] acc_id;
    reg _type;

    assign outStream_TDATA = 64'd1;
    assign outStream_TVALID = state == WAKEUP_ACC;
    assign outStream_TDEST = acc_id;

    assign twInfo_addr = acc_id[TW_MEM_BITS-1:0];
    assign twInfo_we = state == CHECK_RESULTS;
    assign twInfo_en = state == ISSUE_TW_MEM_READ || state == CHECK_RESULTS;
    assign twInfo_din = result_components;

    assign inStream_TREADY = state == READ_HEADER || state == READ_PTID;

    always_ff @(posedge clk) begin

        tw_info_components <= twInfo_dout;
        if (_type) begin
            result_components <= tw_info_components - components;
        end else begin
            result_components <= tw_info_components + 32'd1;
        end

        case (state)

            READ_HEADER: begin
                components <= inStream_TDATA[INSTREAM_COMPONENTS_H:INSTREAM_COMPONENTS_L];
                _type <= inStream_TDATA[TYPE_B];
                if (inStream_TVALID) begin
                    state <= READ_PTID;
                end
            end

            READ_PTID: begin
                if (_type) begin
                    acc_id <= inStream_TID;
                end else begin
                    if (ACC_BITS == TW_MEM_BITS)
                        acc_id <= inStream_TDATA[TW_MEM_BITS-1:0];
                    else
                        acc_id <= {{ACC_BITS-TW_MEM_BITS{1'b0}}, inStream_TDATA[TW_MEM_BITS-1:0]};
                end
                if (inStream_TVALID) begin
                    state <= ISSUE_TW_MEM_READ;
                end
            end

            ISSUE_TW_MEM_READ: begin
                state <= TW_MEM_READ;
            end

            TW_MEM_READ: begin
                state <= RESULT_COMPONENTS;
            end

            RESULT_COMPONENTS: begin
                state <= CHECK_RESULTS;
            end

            CHECK_RESULTS: begin
                if (result_components == 32'd0) begin
                    state <= WAKEUP_ACC;
                end else begin
                    state <= READ_HEADER;
                end
            end

            WAKEUP_ACC: begin
                if (outStream_TREADY) begin
                    state <= READ_HEADER;;
                end
            end

        endcase

        if (!rstn) begin
            state <= READ_HEADER;
        end
    end

endmodule
