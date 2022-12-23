
module axilite_controller #(
    parameter AXI_ADDR_WIDTH = 0,
    parameter MAX_ACCS = 0
) (
    input clk,
    input rstn,
    input axilite_arvalid,
    output axilite_arready,
    input [AXI_ADDR_WIDTH-1:0] axilite_araddr,
    input [2:0] axilite_arprot,
    output axilite_rvalid,
    input axilite_rready,
    output [31:0] axilite_rdata,
    output [1:0] axilite_rresp,
    input axilite_awvalid,
    output axilite_awready,
    input [AXI_ADDR_WIDTH-1:0] axilite_awaddr,
    input [2:0] axilite_awprot,
    input axilite_wvalid,
    output axilite_wready,
    input [31:0] axilite_wdata,
    input [3:0] axilite_wstrb,
    output axilite_bvalid,
    input axilite_bready,
    output [1:0] axilite_bresp,
    input OmpSsManager::DbgRegs_t dbg_regs,
    input [MAX_ACCS-1:0] dbg_acc_avail,
    input [MAX_ACCS-1:0] dbg_queue_nempty,
    input [31:0] cmd_in_n_cmds[MAX_ACCS],
    input [31:0] cmd_out_n_cmds[MAX_ACCS]
);

    localparam CMD_IN_N_CMDS_START_ADDR = 'h800;
    localparam CMD_IN_N_CMDS_LEN = MAX_ACCS < 64 ? MAX_ACCS*4 : 256; //64 accs * 4 bytes per acc
    localparam CMD_IN_N_CMDS_END_ADDR   = CMD_IN_N_CMDS_START_ADDR + CMD_IN_N_CMDS_LEN;

    localparam CMD_OUT_N_CMDS_START_ADDR = 'h900; //0x800 + 256
    localparam CMD_OUT_N_CMDS_LEN = MAX_ACCS < 64 ? MAX_ACCS*4 : 256; //64 accs * 4 bytes per acc
    localparam CMD_OUT_N_CMDS_END_ADDR   = CMD_OUT_N_CMDS_START_ADDR + CMD_OUT_N_CMDS_LEN;

    typedef enum bit [1:0] {
       AR,
       SELECT_REG,
       R 
    } RState_t;

    typedef enum bit[1:0] {
        AW,
        W,
        B
    } WState_t;

    RState_t rstate;
    WState_t wstate;

    reg [AXI_ADDR_WIDTH-1:0] raddr;
    reg [31:0] rdata;
    reg [1:0] rresp;
    reg [1:0] bresp;
    wire [31:0] dbg_acc_avail_low;
    wire [31:0] dbg_acc_avail_high;
    wire [31:0] dbg_queue_nempty_low;
    wire [31:0] dbg_queue_nempty_high;

    if (MAX_ACCS < 32) begin
        assign dbg_acc_avail_low = {{32-MAX_ACCS{1'b0}}, dbg_acc_avail};
        assign dbg_queue_nempty_low = {{32-MAX_ACCS{1'b0}}, dbg_queue_nempty};
    end else begin
        assign dbg_acc_avail_low = dbg_acc_avail[31:0];
        assign dbg_queue_nempty_low = dbg_queue_nempty[31:0];
    end

    if (MAX_ACCS <= 32) begin
        assign dbg_acc_avail_high = 32'd0;
        assign dbg_queue_nempty_high = 32'd0;
    end else if (MAX_ACCS < 64) begin
        assign dbg_acc_avail_high = {{64-MAX_ACCS{1'b0}}, dbg_acc_avail[MAX_ACCS-1:32]};
        assign dbg_queue_nempty_high = {{64-MAX_ACCS{1'b0}}, dbg_queue_nempty[MAX_ACCS-1:32]};
    end else begin
        assign dbg_acc_avail_high = dbg_acc_avail[63:32];
        assign dbg_queue_nempty_high = dbg_queue_nempty[63:32];
    end

    assign axilite_arready = rstate == AR;
    assign axilite_rvalid = rstate == R;
    assign axilite_rdata = rdata;
    assign axilite_rresp = rresp;
    assign axilite_awready = wstate == AW;
    assign axilite_wready = wstate == W;
    assign axilite_bvalid = wstate == B;
    assign axilite_bresp = bresp;

    always_ff @(posedge clk) begin

        case (rstate)

            AR: begin
                raddr <= axilite_araddr[AXI_ADDR_WIDTH-1:0];
                if (axilite_arvalid) begin
                    rstate <= SELECT_REG;
                end
            end

            SELECT_REG: begin
                rresp <= 2'b00;
                if (raddr < CMD_IN_N_CMDS_START_ADDR) begin
                    case (raddr)

                        'h0: begin
                            rdata <= dbg_regs.copy_in_opt;
                        end

                        'h4: begin
                            rdata <= dbg_regs.copy_out_opt;
                        end

                        'h8: begin
                            rdata <= dbg_acc_avail_low;
                        end

                        'hC: begin
                            rdata <= dbg_acc_avail_high;
                        end

                        'h10: begin
                            rdata <= dbg_queue_nempty_low;
                        end

                        'h14: begin
                            rdata <= dbg_queue_nempty_high;
                        end

                        default: begin
                            rresp <= 2'b10; //SLVERR
                        end

                    endcase
                end else begin
                    if (raddr[1:0] != 2'd0) begin
                        rresp <= 2'b10;
                    end else if (raddr >= CMD_IN_N_CMDS_START_ADDR && raddr < CMD_IN_N_CMDS_END_ADDR) begin
                        rdata <= cmd_in_n_cmds[(raddr-CMD_IN_N_CMDS_START_ADDR)/4];
                    end else if (raddr >= CMD_OUT_N_CMDS_START_ADDR && raddr < CMD_OUT_N_CMDS_END_ADDR) begin
                        rdata <= cmd_out_n_cmds[(raddr-CMD_OUT_N_CMDS_START_ADDR)/4];
                    end else begin
                        rresp <= 2'b10;
                    end
                end

                rstate <= R;
            end

            R: begin
                if (axilite_rready) begin
                    rstate <= AR;
                end
            end

        endcase

        case (wstate)
        
            AW: begin
                if (axilite_awvalid) begin
                    wstate <= W;
                end
            end
            
            W: begin
                bresp <= 2'b10; //SLVERR
                if (axilite_wvalid) begin
                    wstate <= B;
                end
            end
            
            B: begin
                if (axilite_bready) begin
                    wstate <= AW;
                end
            end

        endcase

        if (!rstn) begin
            rstate <= AR;
            wstate <= AW;
        end
    end

endmodule
