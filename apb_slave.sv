module apb_slave #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8,
    parameter NUM_CH     = 3
) (
    // APB4 signals
    input  logic                     PCLK,
    input  logic                     PRESETn,
    input  logic [ADDR_WIDTH-1:0]    PADDR,
    input  logic                     PWRITE,
    input  logic                     PSEL,
    input  logic [NUM_CH-1:0]        enable_cmd_to_apb,
    input  logic                     PENABLE,
    input  logic [DATA_WIDTH-1:0]    PWDATA,
    input  logic [STRB_WIDTH-1:0]    PSTRB,
    output logic  [DATA_WIDTH-1:0]    PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR,

    // Register bank signals
    input  logic [DATA_WIDTH-1:0]    cfg_rdata,
    output logic  [DATA_WIDTH-1:0]    cfg_wdata,
    output logic  [ADDR_WIDTH-1:0]    cfg_addr,
    output logic                      cfg_wr_en,
    output logic                      cfg_rd_en,

    input  logic [NUM_CH*32-1:0]     read_base_addr_UPDATED, cfg_read_base_addr,
    input  logic [NUM_CH*32-1:0]     write_base_addr_UPDATED, cfg_write_base_addr,
    input  logic [NUM_CH*32-1:0]     x_transfer_count_UPDATED, cfg_x_transfer_count,
    input  logic [NUM_CH*32-1:0]     y_transfer_count_UPDATED, cfg_y_transfer_count,

    output logic [NUM_CH-1:0]        stop_cmd_apb,
    output logic [NUM_CH-1:0]        pause_cmd_apb
);

    localparam IDLE_ST   = 3'b001;
    localparam SETUP_ST  = 3'b010;
    localparam ACCESS_ST = 3'b100;

    logic  [2:0]            current_state, next_state;
    logic                    PWRITE_q;
    logic  [DATA_WIDTH-1:0] PWDATA_q;
    logic  [STRB_WIDTH-1:0] PSTRB_q;
    logic  [3:0]            count;

    logic [1:0] ch_no;
    assign ch_no = (cfg_addr / 'h100) - 1;

    logic strobe_error_q;
    assign strobe_error_q = PWRITE_q && (PSTRB_q != {STRB_WIDTH{1'b1}});

    assign stop_cmd_apb[2] = (current_state == ACCESS_ST && PREADY && PWRITE == 1'b1 && PENABLE &&
                              (PADDR == 'h0300) && PWDATA[3] && enable_cmd_to_apb[ch_no]) ? 1'b1 : 1'b0;
    assign stop_cmd_apb[1] = (current_state == ACCESS_ST && PREADY && PWRITE == 1'b1 && PENABLE &&
                              (PADDR == 'h0200) && PWDATA[3] && enable_cmd_to_apb[ch_no]) ? 1'b1 : 1'b0;
    assign stop_cmd_apb[0] = (current_state == ACCESS_ST && PREADY && PWRITE == 1'b1 && PENABLE &&
                              (PADDR == 'h0100) && PWDATA[3] && enable_cmd_to_apb[ch_no]) ? 1'b1 : 1'b0;

    assign pause_cmd_apb[2] = (current_state == ACCESS_ST && PREADY && PWRITE == 1'b1 && PENABLE &&
                               (PADDR == 'h0300) && PWDATA[4] && enable_cmd_to_apb[ch_no]) ? 1'b1 : 1'b0;
    assign pause_cmd_apb[1] = (current_state == ACCESS_ST && PREADY && PWRITE == 1'b1 && PENABLE &&
                               (PADDR == 'h0200) && PWDATA[4] && enable_cmd_to_apb[ch_no]) ? 1'b1 : 1'b0;
    assign pause_cmd_apb[0] = (current_state == ACCESS_ST && PREADY && PWRITE == 1'b1 && PENABLE &&
                               (PADDR == 'h0100) && PWDATA[4] && enable_cmd_to_apb[ch_no]) ? 1'b1 : 1'b0;

    logic RO_error;
    assign RO_error = ((cfg_addr % 'h100 == 'h80) || (cfg_addr % 'h100 == 'h8C) ||
                     (cfg_addr % 'h100 == 'h90)) && PWRITE_q;
    logic address_error;
    assign address_error = !(cfg_addr >= 'h0100 && cfg_addr <= 'h03ff);

    // PRDATA generation
    always @(*) begin
        if (current_state == ACCESS_ST && PREADY && PWRITE == 1'b0 && PENABLE) begin
            if (cfg_addr % 'h100 == 'h10)
                PRDATA = enable_cmd_to_apb[ch_no] ? (read_base_addr_UPDATED  >> (32*ch_no))
                                                   : (cfg_read_base_addr     >> (32*ch_no));
            else if (cfg_addr % 'h100 == 'h18)
                PRDATA = enable_cmd_to_apb[ch_no] ? (write_base_addr_UPDATED >> (32*ch_no))
                                                   : (cfg_write_base_addr    >> (32*ch_no));
            else if (cfg_addr % 'h100 == 'h20)
                PRDATA = enable_cmd_to_apb[ch_no] ? (x_transfer_count_UPDATED >> (32*ch_no))
                                                   : (cfg_x_transfer_count    >> (32*ch_no));
            else if (cfg_addr % 'h100 == 'h3C)
                PRDATA = enable_cmd_to_apb[ch_no] ? (y_transfer_count_UPDATED >> (32*ch_no))
                                                   : (cfg_y_transfer_count    >> (32*ch_no));
            else
                PRDATA = cfg_rdata;
        end
        else
            PRDATA = 0;
    end

    // PREADY generation
    always @(*) begin
        if (current_state == ACCESS_ST) begin
            if (PWRITE) begin
                PREADY = 1'b1;
            end
            else begin
                if ((((cfg_addr % 'h100 == 'h10) || (cfg_addr % 'h100 == 'h18) ||
                      (cfg_addr % 'h100 == 'h20)) && enable_cmd_to_apb[ch_no]) ||
                    (cfg_addr % 'h100 == 'h04)) begin
                    if (((cfg_addr % 'h100 == 'h04) && count == 6) ||
                        ((cfg_addr % 'h100 == 'h10) && count == 1) ||
                        ((cfg_addr % 'h100 == 'h18) && count == 1) ||
                        ((cfg_addr % 'h100 == 'h20) && count == 1))
                        PREADY = 1'b1;
                    else
                        PREADY = 1'b0;
                end
                else if ((((cfg_addr % 'h100 == 'h38) || (cfg_addr % 'h100 == 'h20) ||
                           (cfg_addr % 'h100 == 'h18) || (cfg_addr % 'h100 == 'h10) ||
                           (cfg_addr % 'h100 == 'h90) || (cfg_addr % 'h100 == 'h88) ||
                           (cfg_addr % 'h100 == 'h8C) || (cfg_addr % 'h100 == 'h78) ||
                           (cfg_addr % 'h100 == 'h54) || (cfg_addr % 'h100 == 'h50) ||
                           (cfg_addr % 'h100 == 'h4C) || (cfg_addr % 'h100 == 'h30) ||
                           (cfg_addr % 'h100 == 'h2C) || (cfg_addr % 'h100 == 'h28) ||
                           (cfg_addr % 'h100 == 'h0C) || (cfg_addr % 'h100 == 'h08)) &&
                          count == 2) ||
                         ((cfg_addr % 'h100 == 'h00) && count == 3))
                    PREADY = 1'b1;
                else
                    PREADY = 1'b0;
            end
        end
        else
            PREADY = 1'b0;
    end

    // State register
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)
            current_state <= IDLE_ST;
        else
            current_state <= next_state;
    end

    // Next-state logic
    always @(*) begin
        case (current_state)
            IDLE_ST:   next_state = (PSEL && !PENABLE) ? SETUP_ST : IDLE_ST;
            SETUP_ST:  next_state = (PSEL && PENABLE)  ? ACCESS_ST : SETUP_ST;
            ACCESS_ST: next_state = (PREADY && PENABLE) ? (PSEL ? SETUP_ST : IDLE_ST) : ACCESS_ST;
            default:   next_state = IDLE_ST;
        endcase
    end

    // Sequential control logic
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            count     <= 0;
            PWRITE_q  <= 1'b0;
            PWDATA_q  <= {DATA_WIDTH{1'b0}};
            PSLVERR   <= 1'b0;
            PSTRB_q   <= {STRB_WIDTH{1'b0}};
            cfg_wr_en <= 1'b0;
            cfg_rd_en <= 1'b0;
            cfg_addr  <= {ADDR_WIDTH{1'b0}};
            cfg_wdata <= {DATA_WIDTH{1'b0}};
        end
        else begin
            cfg_wr_en <= 1'b0;
            cfg_rd_en <= 1'b0;
            PSLVERR   <= 1'b0;

            // read wait-state counter
            if (current_state == ACCESS_ST) begin
                if (cfg_addr % 'h100 == 'h04)
                    count <= count + 1;
                else if ((cfg_addr % 'h100 == 'h20) && enable_cmd_to_apb[ch_no])
                    count <= count + 1;
                else if ((cfg_addr % 'h100 == 'h10) || (cfg_addr % 'h100 == 'h18))
                    count <= count + 1;
                else if (((cfg_addr % 'h100 == 'h10) || (cfg_addr % 'h100 == 'h18) ||
                          (cfg_addr % 'h100 == 'h20)) && (count == 1) && enable_cmd_to_apb[ch_no])
                    count <= 0;
                else if ((cfg_addr % 'h100 == 'h38) || (cfg_addr % 'h100 == 'h20) ||
                         (cfg_addr % 'h100 == 'h78) || (cfg_addr % 'h100 == 'h54) ||
                         (cfg_addr % 'h100 == 'h50) || (cfg_addr % 'h100 == 'h4C) ||
                         (cfg_addr % 'h100 == 'h30) || (cfg_addr % 'h100 == 'h2C) ||
                         (cfg_addr % 'h100 == 'h28) || (cfg_addr % 'h100 == 'h0C) ||
                         (cfg_addr % 'h100 == 'h08) || (cfg_addr % 'h100 == 'h00) ||
                         (cfg_addr % 'h100 == 'h90) || (cfg_addr % 'h100 == 'h88) ||
                         (cfg_addr % 'h100 == 'h8C))
                    count <= count + 1;
            end
            else begin
                count <= 0;
            end

            // APB state-dependent logic
            case (current_state)
                SETUP_ST: begin
                    cfg_addr  <= PADDR;
                    PWRITE_q  <= PWRITE;
                    PWDATA_q  <= (cfg_addr == 'h100 && enable_cmd_to_apb[ch_no]) ? {PWDATA[31:1], 1'b0} : PWDATA;
                    PSTRB_q   <= PSTRB;
                    PSLVERR   <= 1'b0;
                    cfg_rd_en <= (!PWRITE) ? 1'b1 : 1'b0;
                end

                ACCESS_ST: begin
                    cfg_rd_en <= (!PWRITE) ? 1'b1 : 1'b0;
                    PSLVERR   <= strobe_error_q | RO_error | address_error;
                    if (PWRITE_q) begin
                        cfg_wdata <= PWDATA_q;
                        cfg_wr_en <= 1'b1;
                    end
                end

                default: begin
                    PSLVERR <= 1'b0;
                end
            endcase
        end
    end

endmodule
