module apb_reg #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter STRB_WIDTH = DATA_WIDTH / 8,
    parameter NUM_CH     = 3,
    parameter WIDTH      = 32
) (
    // APB signals
    input logic                         clk,
    input logic                         resetn,
    input logic [ADDR_WIDTH-1:0]        PADDR,
    input logic                         PWRITE,
    input logic                         PENABLE,
    input logic                         PSEL,
    input logic [NUM_CH-1:0]            enable_cmd_to_apb,
    input logic [(NUM_CH*WIDTH*18)-1:0] chn_reg_in,
    input logic [DATA_WIDTH-1:0]        PWDATA,
    input logic [STRB_WIDTH-1:0]        PSTRB,

    output logic [DATA_WIDTH-1:0]       PRDATA,
    output logic                        PREADY,
    output logic                        PSLVERR,

    // Configuration outputs
    output logic [NUM_CH*WIDTH-1:0]     cfg_channel_start,
    output logic [NUM_CH*WIDTH-1:0]     cfg_channel_status,
    output logic [NUM_CH*WIDTH-1:0]     cfg_interrupt_enable,
    output logic [NUM_CH*WIDTH-1:0]     cfg_control_config,
    output logic [NUM_CH*WIDTH-1:0]     cfg_read_base_addr,
    output logic [NUM_CH*WIDTH-1:0]     cfg_write_base_addr,
    output logic [NUM_CH*WIDTH-1:0]     cfg_x_transfer_count,
    output logic [NUM_CH*WIDTH-1:0]     cfg_read_transfer_cfg,
    output logic [NUM_CH*WIDTH-1:0]     cfg_write_transfer_cfg,
    output logic [NUM_CH*WIDTH-1:0]     cfg_addr_increment_cfg,
    output logic [NUM_CH*WIDTH-1:0]     cfg_fill_data,
    output logic [NUM_CH*WIDTH-1:0]     cfg_read_trigger_cfg,
    output logic [NUM_CH*WIDTH-1:0]     cfg_write_trigger_cfg,
    output logic [NUM_CH*WIDTH-1:0]     cfg_trigger_out_cfg,
    output logic [NUM_CH*WIDTH-1:0]     cfg_next_cmd_addr,
    output logic [NUM_CH*WIDTH-1:0]     cfg_auto_restart_config,
    output logic [NUM_CH*WIDTH-1:0]     cfg_work_reg_pointer,
    output logic [NUM_CH*WIDTH-1:0]     cfg_line_stride,
    output logic [NUM_CH*WIDTH-1:0]     cfg_y_transfer_count,
    output logic [NUM_CH*32-1:0]        cfg_read_template_data,
    output logic [NUM_CH*32-1:0]        cfg_write_template_data,
    output logic [NUM_CH*32-1:0]        cfg_template_config,

    // Channel write enables
    output logic [NUM_CH-1:0]           chn_cmd_wr_en_o,
    output logic [NUM_CH-1:0]           chn_stat_wr_en_o,
    output logic [NUM_CH-1:0]           chn_intren_wr_en_o,
    output logic [NUM_CH-1:0]           chn_ctrl_wr_en_o,
    output logic [NUM_CH-1:0]           chn_read_base_addr_wr_en_o,
    output logic [NUM_CH-1:0]           chn_write_base_addr_wr_en_o,
    output logic [NUM_CH-1:0]           chn_x_transfer_count_wr_en_o,
    output logic [NUM_CH-1:0]           chn_srctrans_wr_en_o,
    output logic [NUM_CH-1:0]           chn_destrans_wr_en_o,
    output logic [NUM_CH-1:0]           chn_xaddrinc_wr_en_o,
    output logic [NUM_CH-1:0]           chn_fillval_wr_en_o,
    output logic [NUM_CH-1:0]           chn_srctrigin_wr_en_o,
    output logic [NUM_CH-1:0]           chn_destrigin_wr_en_o,
    output logic [NUM_CH-1:0]           chn_trigout_wr_en_o,
    output logic [NUM_CH-1:0]           chn_next_cmd_addr_wr_en_o,
    output logic [NUM_CH-1:0]           chn_autocfg_wr_en_o,
    output logic [NUM_CH-1:0]           chn_work_reg_pointer_wr_en_o,
    output logic [NUM_CH-1:0]           chn_tmpltcfg_wr_en_o,
    output logic [NUM_CH-1:0]           chn_destmplt_wr_en_o,
    output logic [NUM_CH-1:0]           chn_srctmplt_wr_en_o,
    output logic [NUM_CH-1:0]           chn_yaddrestride_wr_en_o,
    output logic [NUM_CH-1:0]           chn_y_transfer_count_wr_en_o,

    // Channel status/control
    input logic [NUM_CH*(WIDTH*3)-1:0]  src_des_x_transfer_count_updated,
    input logic [NUM_CH*WIDTH-1:0]      wrkregval_rd,

    output logic [NUM_CH-1:0]           stop_cmd_apb,
    output logic [NUM_CH-1:0]           pause_cmd_apb,

    input logic [NUM_CH*32-1:0]         read_base_addr_UPDATED,
    input logic [NUM_CH*32-1:0]         write_base_addr_UPDATED,
    input logic [NUM_CH*32-1:0]         x_transfer_count_UPDATED,
    input logic [NUM_CH*32-1:0]         y_transfer_count_UPDATED
);

    // Internal signals
    logic                         cfg_rd_en;
    logic                         cfg_wr_en;
    logic [DATA_WIDTH-1:0]        cfg_wdata;
    logic [ADDR_WIDTH-1:0]        cfg_addr;
    logic [DATA_WIDTH-1:0]        cfg_data_out;

    // APB Slave Instance

    apb_slave dut0 (
        .PCLK                       (clk),
        .PRESETn                    (resetn),
        .PADDR                      (PADDR),
        .PWRITE                     (PWRITE),
        .PSEL                       (PSEL),
        .PENABLE                    (PENABLE),
        .PWDATA                     (PWDATA),
        .PSTRB                      (PSTRB),
        .PRDATA                     (PRDATA),
        .PREADY                     (PREADY),
        .PSLVERR                    (PSLVERR),

        .cfg_rdata                  (cfg_data_out),
        .cfg_wdata                  (cfg_wdata),
        .cfg_addr                   (cfg_addr),
        .enable_cmd_to_apb          (enable_cmd_to_apb),
        .cfg_wr_en                  (cfg_wr_en),
        .cfg_rd_en                  (cfg_rd_en),

        .read_base_addr_UPDATED     (read_base_addr_UPDATED),
        .write_base_addr_UPDATED    (write_base_addr_UPDATED),
        .x_transfer_count_UPDATED   (x_transfer_count_UPDATED),
        .y_transfer_count_UPDATED   (y_transfer_count_UPDATED),

        .stop_cmd_apb               (stop_cmd_apb),
        .pause_cmd_apb              (pause_cmd_apb),

        .cfg_write_base_addr        (cfg_write_base_addr),
        .cfg_read_base_addr         (cfg_read_base_addr),
        .cfg_x_transfer_count       (cfg_x_transfer_count),
        .cfg_y_transfer_count       (cfg_y_transfer_count)
    );

    // Register Bank Instance

    register_bank dut1 (
        .clk                            (clk),
        .resetn                         (resetn),
        .cfg_rd_en                      (cfg_rd_en),
        .cfg_wr_en                      (cfg_wr_en),
        .cfg_data_in                    (cfg_wdata),
        .addr_in                        (cfg_addr),
        .chn_reg_in                     (chn_reg_in),
        .cfg_data_out                   (cfg_data_out),

        // Configuration registers
        .cfg_channel_start              (cfg_channel_start),
        .cfg_channel_status             (cfg_channel_status),
        .cfg_interrupt_enable           (cfg_interrupt_enable),
        .cfg_control_config             (cfg_control_config),
        .cfg_read_base_addr             (cfg_read_base_addr),
        .cfg_write_base_addr            (cfg_write_base_addr),
        .cfg_x_transfer_count           (cfg_x_transfer_count),
        .cfg_read_transfer_cfg          (cfg_read_transfer_cfg),
        .cfg_write_transfer_cfg         (cfg_write_transfer_cfg),
        .cfg_addr_increment_cfg         (cfg_addr_increment_cfg),
        .cfg_fill_data                  (cfg_fill_data),
        .cfg_read_trigger_cfg           (cfg_read_trigger_cfg),
        .cfg_write_trigger_cfg          (cfg_write_trigger_cfg),
        .cfg_trigger_out_cfg            (cfg_trigger_out_cfg),
        .cfg_next_cmd_addr              (cfg_next_cmd_addr),
        .cfg_template_config             (cfg_template_config),
        .cfg_write_template_data        (cfg_write_template_data),
        .cfg_read_template_data         (cfg_read_template_data),
        .cfg_work_reg_pointer           (cfg_work_reg_pointer),
        .cfg_line_stride                (cfg_line_stride),
        .cfg_y_transfer_count           (cfg_y_transfer_count),
        .cfg_auto_restart_config        (cfg_auto_restart_config),

        // Channel write enables
        .chn_cmd_wr_en_o                (chn_cmd_wr_en_o),
        .chn_stat_wr_en_o               (chn_stat_wr_en_o),
        .chn_intren_wr_en_o             (chn_intren_wr_en_o),
        .chn_ctrl_wr_en_o               (chn_ctrl_wr_en_o),
        .chn_read_base_addr_wr_en_o     (chn_read_base_addr_wr_en_o),
        .chn_write_base_addr_wr_en_o    (chn_write_base_addr_wr_en_o),
        .chn_x_transfer_count_wr_en_o   (chn_x_transfer_count_wr_en_o),
        .chn_srctrans_wr_en_o           (chn_srctrans_wr_en_o),
        .chn_destrans_wr_en_o           (chn_destrans_wr_en_o),
        .chn_xaddrinc_wr_en_o            (chn_xaddrinc_wr_en_o),
        .chn_fillval_wr_en_o             (chn_fillval_wr_en_o),
        .chn_srctrigin_wr_en_o           (chn_srctrigin_wr_en_o),
        .chn_destrigin_wr_en_o           (chn_destrigin_wr_en_o),
        .chn_trigout_wr_en_o             (chn_trigout_wr_en_o),
        .chn_next_cmd_addr_wr_en_o       (chn_next_cmd_addr_wr_en_o),
        .chn_autocfg_wr_en_o             (chn_autocfg_wr_en_o),
        .chn_work_reg_pointer_wr_en_o    (chn_work_reg_pointer_wr_en_o),
        .chn_tmpltcfg_wr_en_o            (chn_tmpltcfg_wr_en_o),
        .chn_destmplt_wr_en_o            (chn_destmplt_wr_en_o),
        .chn_srctmplt_wr_en_o            (chn_srctmplt_wr_en_o),
        .chn_yaddrestride_wr_en_o        (chn_yaddrestride_wr_en_o),
        .chn_y_transfer_count_wr_en_o    (chn_y_transfer_count_wr_en_o),

        // Updated transfer information
        .src_des_x_transfer_count_updated(src_des_x_transfer_count_updated),
        .wrkregval_rd                    (wrkregval_rd)
    );

endmodule
