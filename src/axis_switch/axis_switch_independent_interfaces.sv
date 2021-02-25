`timescale 1ns / 1ps

module axis_switch_independent_interfaces #(
    parameter NSLAVES = 2,
    parameter NMASTERS = 1,
    parameter REG_PIPELINE_DEPTH = 1,
    parameter SINGLE_ST = 0,
    parameter DATA_WIDTH = 64,
    parameter HAS_ID = 0,
    parameter HAS_LAST = 0,
    parameter HAS_DEST = 0,
    parameter ID_WIDTH = 1,
    parameter DEST_WIDTH = 1,
    parameter DEST_BASE = 0,
    parameter DEST_STRIDE = 1,
    parameter DEST_RANGE = 0
)
(
    input aclk,
    input aresetn,
    input  S00_AXIS_tvalid,
    output S00_AXIS_tready,
    input  [DATA_WIDTH-1:0] S00_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S00_AXIS_tdest,
    input  [ID_WIDTH-1:0] S00_AXIS_tid,
    input  S00_AXIS_tlast,
    input  S01_AXIS_tvalid,
    output S01_AXIS_tready,
    input  [DATA_WIDTH-1:0] S01_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S01_AXIS_tdest,
    input  [ID_WIDTH-1:0] S01_AXIS_tid,
    input  S01_AXIS_tlast,
    input  S02_AXIS_tvalid,
    output S02_AXIS_tready,
    input  [DATA_WIDTH-1:0] S02_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S02_AXIS_tdest,
    input  [ID_WIDTH-1:0] S02_AXIS_tid,
    input  S02_AXIS_tlast,
    input  S03_AXIS_tvalid,
    output S03_AXIS_tready,
    input  [DATA_WIDTH-1:0] S03_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S03_AXIS_tdest,
    input  [ID_WIDTH-1:0] S03_AXIS_tid,
    input  S03_AXIS_tlast,
    input  S04_AXIS_tvalid,
    output S04_AXIS_tready,
    input  [DATA_WIDTH-1:0] S04_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S04_AXIS_tdest,
    input  [ID_WIDTH-1:0] S04_AXIS_tid,
    input  S04_AXIS_tlast,
    input  S05_AXIS_tvalid,
    output S05_AXIS_tready,
    input  [DATA_WIDTH-1:0] S05_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S05_AXIS_tdest,
    input  [ID_WIDTH-1:0] S05_AXIS_tid,
    input  S05_AXIS_tlast,
    input  S06_AXIS_tvalid,
    output S06_AXIS_tready,
    input  [DATA_WIDTH-1:0] S06_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S06_AXIS_tdest,
    input  [ID_WIDTH-1:0] S06_AXIS_tid,
    input  S06_AXIS_tlast,
    input  S07_AXIS_tvalid,
    output S07_AXIS_tready,
    input  [DATA_WIDTH-1:0] S07_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S07_AXIS_tdest,
    input  [ID_WIDTH-1:0] S07_AXIS_tid,
    input  S07_AXIS_tlast,
    input  S08_AXIS_tvalid,
    output S08_AXIS_tready,
    input  [DATA_WIDTH-1:0] S08_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S08_AXIS_tdest,
    input  [ID_WIDTH-1:0] S08_AXIS_tid,
    input  S08_AXIS_tlast,
    input  S09_AXIS_tvalid,
    output S09_AXIS_tready,
    input  [DATA_WIDTH-1:0] S09_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S09_AXIS_tdest,
    input  [ID_WIDTH-1:0] S09_AXIS_tid,
    input  S09_AXIS_tlast,
    input  S10_AXIS_tvalid,
    output S10_AXIS_tready,
    input  [DATA_WIDTH-1:0] S10_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S10_AXIS_tdest,
    input  [ID_WIDTH-1:0] S10_AXIS_tid,
    input  S10_AXIS_tlast,
    input  S11_AXIS_tvalid,
    output S11_AXIS_tready,
    input  [DATA_WIDTH-1:0] S11_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S11_AXIS_tdest,
    input  [ID_WIDTH-1:0] S11_AXIS_tid,
    input  S11_AXIS_tlast,
    input  S12_AXIS_tvalid,
    output S12_AXIS_tready,
    input  [DATA_WIDTH-1:0] S12_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S12_AXIS_tdest,
    input  [ID_WIDTH-1:0] S12_AXIS_tid,
    input  S12_AXIS_tlast,
    input  S13_AXIS_tvalid,
    output S13_AXIS_tready,
    input  [DATA_WIDTH-1:0] S13_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S13_AXIS_tdest,
    input  [ID_WIDTH-1:0] S13_AXIS_tid,
    input  S13_AXIS_tlast,
    input  S14_AXIS_tvalid,
    output S14_AXIS_tready,
    input  [DATA_WIDTH-1:0] S14_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S14_AXIS_tdest,
    input  [ID_WIDTH-1:0] S14_AXIS_tid,
    input  S14_AXIS_tlast,
    input  S15_AXIS_tvalid,
    output S15_AXIS_tready,
    input  [DATA_WIDTH-1:0] S15_AXIS_tdata,
    input  [DEST_WIDTH-1:0] S15_AXIS_tdest,
    input  [ID_WIDTH-1:0] S15_AXIS_tid,
    input  S15_AXIS_tlast,
    output M00_AXIS_tvalid,
    input  M00_AXIS_tready,
    output [DATA_WIDTH-1:0] M00_AXIS_tdata,
    output [DEST_WIDTH-1:0] M00_AXIS_tdest,
    output [ID_WIDTH-1:0] M00_AXIS_tid,
    output M00_AXIS_tlast,
    output M01_AXIS_tvalid,
    input  M01_AXIS_tready,
    output [DATA_WIDTH-1:0] M01_AXIS_tdata,
    output [DEST_WIDTH-1:0] M01_AXIS_tdest,
    output [ID_WIDTH-1:0] M01_AXIS_tid,
    output M01_AXIS_tlast,
    output M02_AXIS_tvalid,
    input  M02_AXIS_tready,
    output [DATA_WIDTH-1:0] M02_AXIS_tdata,
    output [DEST_WIDTH-1:0] M02_AXIS_tdest,
    output [ID_WIDTH-1:0] M02_AXIS_tid,
    output M02_AXIS_tlast,
    output M03_AXIS_tvalid,
    input  M03_AXIS_tready,
    output [DATA_WIDTH-1:0] M03_AXIS_tdata,
    output [DEST_WIDTH-1:0] M03_AXIS_tdest,
    output [ID_WIDTH-1:0] M03_AXIS_tid,
    output M03_AXIS_tlast,
    output M04_AXIS_tvalid,
    input  M04_AXIS_tready,
    output [DATA_WIDTH-1:0] M04_AXIS_tdata,
    output [DEST_WIDTH-1:0] M04_AXIS_tdest,
    output [ID_WIDTH-1:0] M04_AXIS_tid,
    output M04_AXIS_tlast,
    output M05_AXIS_tvalid,
    input  M05_AXIS_tready,
    output [DATA_WIDTH-1:0] M05_AXIS_tdata,
    output [DEST_WIDTH-1:0] M05_AXIS_tdest,
    output [ID_WIDTH-1:0] M05_AXIS_tid,
    output M05_AXIS_tlast,
    output M06_AXIS_tvalid,
    input  M06_AXIS_tready,
    output [DATA_WIDTH-1:0] M06_AXIS_tdata,
    output [DEST_WIDTH-1:0] M06_AXIS_tdest,
    output [ID_WIDTH-1:0] M06_AXIS_tid,
    output M06_AXIS_tlast,
    output M07_AXIS_tvalid,
    input  M07_AXIS_tready,
    output [DATA_WIDTH-1:0] M07_AXIS_tdata,
    output [DEST_WIDTH-1:0] M07_AXIS_tdest,
    output [ID_WIDTH-1:0] M07_AXIS_tid,
    output M07_AXIS_tlast,
    output M08_AXIS_tvalid,
    input  M08_AXIS_tready,
    output [DATA_WIDTH-1:0] M08_AXIS_tdata,
    output [DEST_WIDTH-1:0] M08_AXIS_tdest,
    output [ID_WIDTH-1:0] M08_AXIS_tid,
    output M08_AXIS_tlast,
    output M09_AXIS_tvalid,
    input  M09_AXIS_tready,
    output [DATA_WIDTH-1:0] M09_AXIS_tdata,
    output [DEST_WIDTH-1:0] M09_AXIS_tdest,
    output [ID_WIDTH-1:0] M09_AXIS_tid,
    output M09_AXIS_tlast,
    output M10_AXIS_tvalid,
    input  M10_AXIS_tready,
    output [DATA_WIDTH-1:0] M10_AXIS_tdata,
    output [DEST_WIDTH-1:0] M10_AXIS_tdest,
    output [ID_WIDTH-1:0] M10_AXIS_tid,
    output M10_AXIS_tlast,
    output M11_AXIS_tvalid,
    input  M11_AXIS_tready,
    output [DATA_WIDTH-1:0] M11_AXIS_tdata,
    output [DEST_WIDTH-1:0] M11_AXIS_tdest,
    output [ID_WIDTH-1:0] M11_AXIS_tid,
    output M11_AXIS_tlast,
    output M12_AXIS_tvalid,
    input  M12_AXIS_tready,
    output [DATA_WIDTH-1:0] M12_AXIS_tdata,
    output [DEST_WIDTH-1:0] M12_AXIS_tdest,
    output [ID_WIDTH-1:0] M12_AXIS_tid,
    output M12_AXIS_tlast,
    output M13_AXIS_tvalid,
    input  M13_AXIS_tready,
    output [DATA_WIDTH-1:0] M13_AXIS_tdata,
    output [DEST_WIDTH-1:0] M13_AXIS_tdest,
    output [ID_WIDTH-1:0] M13_AXIS_tid,
    output M13_AXIS_tlast,
    output M14_AXIS_tvalid,
    input  M14_AXIS_tready,
    output [DATA_WIDTH-1:0] M14_AXIS_tdata,
    output [DEST_WIDTH-1:0] M14_AXIS_tdest,
    output [ID_WIDTH-1:0] M14_AXIS_tid,
    output M14_AXIS_tlast,
    output M15_AXIS_tvalid,
    input  M15_AXIS_tready,
    output [DATA_WIDTH-1:0] M15_AXIS_tdata,
    output [DEST_WIDTH-1:0] M15_AXIS_tdest,
    output [ID_WIDTH-1:0] M15_AXIS_tid,
    output M15_AXIS_tlast
);

    wire [NSLAVES-1:0] s_valid;
    wire [NSLAVES-1:0] s_ready;
    wire [NSLAVES*DATA_WIDTH-1:0] s_data;
    wire [NSLAVES*DEST_WIDTH-1:0] s_dest;
    wire [NSLAVES*ID_WIDTH-1:0] s_id;
    wire [NSLAVES-1:0] s_last;
    wire [NMASTERS-1:0] m_valid;
    wire [NMASTERS-1:0] m_ready;
    wire [NMASTERS*DATA_WIDTH-1:0] m_data;
    wire [NMASTERS*DEST_WIDTH-1:0] m_dest;
    wire [NMASTERS*ID_WIDTH-1:0] m_id;
    wire [NMASTERS-1:0] m_last;

if (NSLAVES > 0) begin

    assign s_valid[0] = S00_AXIS_tvalid;
    assign S00_AXIS_tready = s_ready[0];
    assign s_data[DATA_WIDTH*0 +: DATA_WIDTH] = S00_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*0 +: DEST_WIDTH] = S00_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*0 +: ID_WIDTH] = S00_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[0] = S00_AXIS_tlast;
    end

end
if (NSLAVES > 1) begin

    assign s_valid[1] = S01_AXIS_tvalid;
    assign S01_AXIS_tready = s_ready[1];
    assign s_data[DATA_WIDTH*1 +: DATA_WIDTH] = S01_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*1 +: DEST_WIDTH] = S01_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*1 +: ID_WIDTH] = S01_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[1] = S01_AXIS_tlast;
    end

end
if (NSLAVES > 2) begin

    assign s_valid[2] = S02_AXIS_tvalid;
    assign S02_AXIS_tready = s_ready[2];
    assign s_data[DATA_WIDTH*2 +: DATA_WIDTH] = S02_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*2 +: DEST_WIDTH] = S02_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*2 +: ID_WIDTH] = S02_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[2] = S02_AXIS_tlast;
    end

end
if (NSLAVES > 3) begin

    assign s_valid[3] = S03_AXIS_tvalid;
    assign S03_AXIS_tready = s_ready[3];
    assign s_data[DATA_WIDTH*3 +: DATA_WIDTH] = S03_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*3 +: DEST_WIDTH] = S03_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*3 +: ID_WIDTH] = S03_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[3] = S03_AXIS_tlast;
    end

end
if (NSLAVES > 4) begin

    assign s_valid[4] = S04_AXIS_tvalid;
    assign S04_AXIS_tready = s_ready[4];
    assign s_data[DATA_WIDTH*4 +: DATA_WIDTH] = S04_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*4 +: DEST_WIDTH] = S04_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*4 +: ID_WIDTH] = S04_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[4] = S04_AXIS_tlast;
    end

end
if (NSLAVES > 5) begin

    assign s_valid[5] = S05_AXIS_tvalid;
    assign S05_AXIS_tready = s_ready[5];
    assign s_data[DATA_WIDTH*5 +: DATA_WIDTH] = S05_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*5 +: DEST_WIDTH] = S05_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*5 +: ID_WIDTH] = S05_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[5] = S05_AXIS_tlast;
    end

end
if (NSLAVES > 6) begin

    assign s_valid[6] = S06_AXIS_tvalid;
    assign S06_AXIS_tready = s_ready[6];
    assign s_data[DATA_WIDTH*6 +: DATA_WIDTH] = S06_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*6 +: DEST_WIDTH] = S06_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*6 +: ID_WIDTH] = S06_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[6] = S06_AXIS_tlast;
    end

end
if (NSLAVES > 7) begin

    assign s_valid[7] = S07_AXIS_tvalid;
    assign S07_AXIS_tready = s_ready[7];
    assign s_data[DATA_WIDTH*7 +: DATA_WIDTH] = S07_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*7 +: DEST_WIDTH] = S07_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*7 +: ID_WIDTH] = S07_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[7] = S07_AXIS_tlast;
    end

end
if (NSLAVES > 8) begin

    assign s_valid[8] = S08_AXIS_tvalid;
    assign S08_AXIS_tready = s_ready[8];
    assign s_data[DATA_WIDTH*8 +: DATA_WIDTH] = S08_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*8 +: DEST_WIDTH] = S08_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*8 +: ID_WIDTH] = S08_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[8] = S08_AXIS_tlast;
    end

end
if (NSLAVES > 9) begin

    assign s_valid[9] = S09_AXIS_tvalid;
    assign S09_AXIS_tready = s_ready[9];
    assign s_data[DATA_WIDTH*9 +: DATA_WIDTH] = S09_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*9 +: DEST_WIDTH] = S09_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*9 +: ID_WIDTH] = S09_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[9] = S09_AXIS_tlast;
    end

end
if (NSLAVES > 10) begin

    assign s_valid[10] = S10_AXIS_tvalid;
    assign S10_AXIS_tready = s_ready[10];
    assign s_data[DATA_WIDTH*10 +: DATA_WIDTH] = S10_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*10 +: DEST_WIDTH] = S10_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*10 +: ID_WIDTH] = S10_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[10] = S10_AXIS_tlast;
    end

end
if (NSLAVES > 11) begin

    assign s_valid[11] = S11_AXIS_tvalid;
    assign S11_AXIS_tready = s_ready[11];
    assign s_data[DATA_WIDTH*11 +: DATA_WIDTH] = S11_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*11 +: DEST_WIDTH] = S11_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*11 +: ID_WIDTH] = S11_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[11] = S11_AXIS_tlast;
    end

end
if (NSLAVES > 12) begin

    assign s_valid[12] = S12_AXIS_tvalid;
    assign S12_AXIS_tready = s_ready[12];
    assign s_data[DATA_WIDTH*12 +: DATA_WIDTH] = S12_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*12 +: DEST_WIDTH] = S12_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*12 +: ID_WIDTH] = S12_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[12] = S12_AXIS_tlast;
    end

end
if (NSLAVES > 13) begin

    assign s_valid[13] = S13_AXIS_tvalid;
    assign S13_AXIS_tready = s_ready[13];
    assign s_data[DATA_WIDTH*13 +: DATA_WIDTH] = S13_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*13 +: DEST_WIDTH] = S13_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*13 +: ID_WIDTH] = S13_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[13] = S13_AXIS_tlast;
    end

end
if (NSLAVES > 14) begin

    assign s_valid[14] = S14_AXIS_tvalid;
    assign S14_AXIS_tready = s_ready[14];
    assign s_data[DATA_WIDTH*14 +: DATA_WIDTH] = S14_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*14 +: DEST_WIDTH] = S14_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*14 +: ID_WIDTH] = S14_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[14] = S14_AXIS_tlast;
    end

end
if (NSLAVES > 15) begin

    assign s_valid[15] = S15_AXIS_tvalid;
    assign S15_AXIS_tready = s_ready[15];
    assign s_data[DATA_WIDTH*15 +: DATA_WIDTH] = S15_AXIS_tdata;
    if (HAS_DEST) begin
        assign s_dest[DEST_WIDTH*15 +: DEST_WIDTH] = S15_AXIS_tdest;
    end
    if (HAS_ID) begin
        assign s_id[ID_WIDTH*15 +: ID_WIDTH] = S15_AXIS_tid;
    end
    if (HAS_LAST) begin
        assign s_last[15] = S15_AXIS_tlast;
    end

end

if (NMASTERS > 0) begin

    assign M00_AXIS_tvalid = m_valid[0];
    assign m_ready[0] = M00_AXIS_tready;
    assign M00_AXIS_tdata = m_data[DATA_WIDTH*0 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M00_AXIS_tdest = m_dest[DEST_WIDTH*0 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M00_AXIS_tid = m_id[ID_WIDTH*0 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M00_AXIS_tlast = m_last[0];
    end

end
if (NMASTERS > 1) begin

    assign M01_AXIS_tvalid = m_valid[1];
    assign m_ready[1] = M01_AXIS_tready;
    assign M01_AXIS_tdata = m_data[DATA_WIDTH*1 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M01_AXIS_tdest = m_dest[DEST_WIDTH*1 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M01_AXIS_tid = m_id[ID_WIDTH*1 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M01_AXIS_tlast = m_last[1];
    end

end
if (NMASTERS > 2) begin

    assign M02_AXIS_tvalid = m_valid[2];
    assign m_ready[2] = M02_AXIS_tready;
    assign M02_AXIS_tdata = m_data[DATA_WIDTH*2 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M02_AXIS_tdest = m_dest[DEST_WIDTH*2 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M02_AXIS_tid = m_id[ID_WIDTH*2 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M02_AXIS_tlast = m_last[2];
    end

end
if (NMASTERS > 3) begin

    assign M03_AXIS_tvalid = m_valid[3];
    assign m_ready[3] = M03_AXIS_tready;
    assign M03_AXIS_tdata = m_data[DATA_WIDTH*3 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M03_AXIS_tdest = m_dest[DEST_WIDTH*3 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M03_AXIS_tid = m_id[ID_WIDTH*3 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M03_AXIS_tlast = m_last[3];
    end

end
if (NMASTERS > 4) begin

    assign M04_AXIS_tvalid = m_valid[4];
    assign m_ready[4] = M04_AXIS_tready;
    assign M04_AXIS_tdata = m_data[DATA_WIDTH*4 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M04_AXIS_tdest = m_dest[DEST_WIDTH*4 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M04_AXIS_tid = m_id[ID_WIDTH*4 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M04_AXIS_tlast = m_last[4];
    end

end
if (NMASTERS > 5) begin

    assign M05_AXIS_tvalid = m_valid[5];
    assign m_ready[5] = M05_AXIS_tready;
    assign M05_AXIS_tdata = m_data[DATA_WIDTH*5 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M05_AXIS_tdest = m_dest[DEST_WIDTH*5 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M05_AXIS_tid = m_id[ID_WIDTH*5 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M05_AXIS_tlast = m_last[5];
    end

end
if (NMASTERS > 6) begin

    assign M06_AXIS_tvalid = m_valid[6];
    assign m_ready[6] = M06_AXIS_tready;
    assign M06_AXIS_tdata = m_data[DATA_WIDTH*6 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M06_AXIS_tdest = m_dest[DEST_WIDTH*6 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M06_AXIS_tid = m_id[ID_WIDTH*6 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M06_AXIS_tlast = m_last[6];
    end

end
if (NMASTERS > 7) begin

    assign M07_AXIS_tvalid = m_valid[7];
    assign m_ready[7] = M07_AXIS_tready;
    assign M07_AXIS_tdata = m_data[DATA_WIDTH*7 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M07_AXIS_tdest = m_dest[DEST_WIDTH*7 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M07_AXIS_tid = m_id[ID_WIDTH*7 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M07_AXIS_tlast = m_last[7];
    end

end
if (NMASTERS > 8) begin

    assign M08_AXIS_tvalid = m_valid[8];
    assign m_ready[8] = M08_AXIS_tready;
    assign M08_AXIS_tdata = m_data[DATA_WIDTH*8 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M08_AXIS_tdest = m_dest[DEST_WIDTH*8 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M08_AXIS_tid = m_id[ID_WIDTH*8 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M08_AXIS_tlast = m_last[8];
    end

end
if (NMASTERS > 9) begin

    assign M09_AXIS_tvalid = m_valid[9];
    assign m_ready[9] = M09_AXIS_tready;
    assign M09_AXIS_tdata = m_data[DATA_WIDTH*9 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M09_AXIS_tdest = m_dest[DEST_WIDTH*9 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M09_AXIS_tid = m_id[ID_WIDTH*9 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M09_AXIS_tlast = m_last[9];
    end

end
if (NMASTERS > 10) begin

    assign M10_AXIS_tvalid = m_valid[10];
    assign m_ready[10] = M10_AXIS_tready;
    assign M10_AXIS_tdata = m_data[DATA_WIDTH*10 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M10_AXIS_tdest = m_dest[DEST_WIDTH*10 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M10_AXIS_tid = m_id[ID_WIDTH*10 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M10_AXIS_tlast = m_last[10];
    end

end
if (NMASTERS > 11) begin

    assign M11_AXIS_tvalid = m_valid[11];
    assign m_ready[11] = M11_AXIS_tready;
    assign M11_AXIS_tdata = m_data[DATA_WIDTH*11 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M11_AXIS_tdest = m_dest[DEST_WIDTH*11 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M11_AXIS_tid = m_id[ID_WIDTH*11 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M11_AXIS_tlast = m_last[11];
    end

end
if (NMASTERS > 12) begin

    assign M12_AXIS_tvalid = m_valid[12];
    assign m_ready[12] = M12_AXIS_tready;
    assign M12_AXIS_tdata = m_data[DATA_WIDTH*12 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M12_AXIS_tdest = m_dest[DEST_WIDTH*12 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M12_AXIS_tid = m_id[ID_WIDTH*12 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M12_AXIS_tlast = m_last[12];
    end

end
if (NMASTERS > 13) begin

    assign M13_AXIS_tvalid = m_valid[13];
    assign m_ready[13] = M13_AXIS_tready;
    assign M13_AXIS_tdata = m_data[DATA_WIDTH*13 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M13_AXIS_tdest = m_dest[DEST_WIDTH*13 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M13_AXIS_tid = m_id[ID_WIDTH*13 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M13_AXIS_tlast = m_last[13];
    end

end
if (NMASTERS > 14) begin

    assign M14_AXIS_tvalid = m_valid[14];
    assign m_ready[14] = M14_AXIS_tready;
    assign M14_AXIS_tdata = m_data[DATA_WIDTH*14 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M14_AXIS_tdest = m_dest[DEST_WIDTH*14 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M14_AXIS_tid = m_id[ID_WIDTH*14 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M14_AXIS_tlast = m_last[14];
    end

end
if (NMASTERS > 15) begin

    assign M15_AXIS_tvalid = m_valid[15];
    assign m_ready[15] = M15_AXIS_tready;
    assign M15_AXIS_tdata = m_data[DATA_WIDTH*15 +: DATA_WIDTH];
    if (HAS_DEST) begin
        assign M15_AXIS_tdest = m_dest[DEST_WIDTH*15 +: DEST_WIDTH];
    end
    if (HAS_ID) begin
        assign M15_AXIS_tid = m_id[ID_WIDTH*15 +: ID_WIDTH];
    end
    if (HAS_LAST) begin
        assign M15_AXIS_tlast = m_last[15];
    end

end

    axis_switch #(
        .NSLAVES(NSLAVES),
        .NMASTERS(NMASTERS),
        .REG_PIPELINE_DEPTH(REG_PIPELINE_DEPTH),
        .SINGLE_ST(SINGLE_ST),
        .DATA_WIDTH(DATA_WIDTH),
        .DEST_WIDTH(DEST_WIDTH),
        .ID_WIDTH(ID_WIDTH),
        .HAS_ID(HAS_ID),
        .HAS_LAST(HAS_LAST),
        .HAS_DEST(HAS_DEST),
        .DEST_BASE(DEST_BASE),
        .DEST_STRIDE(DEST_STRIDE),
        .DEST_RANGE(DEST_RANGE)
    )
    switch (
        .*
    );

endmodule
