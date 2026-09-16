
module partselect (
    // INTERNAL REGISTERS
    input  logic [31:0] control_config,
    input  logic [31:0] x_transfer_count,
    input  logic [31:0] CH_next_cmd_addr,
    input  logic [31:0] channel_start,
    input  logic [31:0] channel_status,
    //input  logic [31:0] ERROR_INFO,
    input  logic [31:0] addr_increment_cfg,
    input  logic [31:0] read_trigger_cfg,
    input  logic [31:0] write_trigger_cfg,
    input  logic [31:0] trigger_out_cfg,
    input  logic [31:0] read_base_addr,
    input  logic [31:0] write_base_addr,
    input  logic [31:0] fill_data,
    input  logic [31:0] template_config,
    input  logic [31:0]line_stride,
    input  logic [31:0] y_transfer_count,
    input  logic [31:0] read_template_data,
    input  logic [31:0] write_template_data,
    input  logic [31:0] write_transfer_cfg,
    input  logic [31:0] read_transfer_cfg,
    input  logic [31:0] auto_restart_config,
    output logic        use_trigout,
    output logic        use_des_trigin,
    output logic        use_src_trigin,
    output logic [2:0]  x_type,y_type,
    output logic [3:0]  ch_prio,
    output logic [2:0]  transize,
    output logic [15:0] srcx_transfer_count,
    output logic [15:0] desx_transfer_count,
    output logic [31:0] next_cmd_addr,
    output logic        next_cmd_addren,
    output logic [4:0] des_tmplt_size,
    output logic [4:0] src_tmplt_size,
    output logic [31:0] des_tmplt,
    output logic [31:0] src_tmplt,
    // COMMAND OUTPUTS
    output logic        enable_cmd,
    output logic        disable_cmd,
    output logic        pause_cmd,
    output logic        resume_cmd,
    output logic        stop_cmd,
    output logic        src_trigin_sw,
    output logic [1:0]  src_trigin_sw_type,
    output logic        des_trigin_sw,
    output logic [1:0]  des_trigin_sw_type,
    output logic        trigout_ack_sw,
    // TRIGGER CONFIG OUTPUTS
    output logic [1:0]  src_trigin_mode,
    output logic [1:0]  src_trigin_type,
    output logic [7:0]  src_trigin_sel,
    output logic [1:0]  des_trigin_mode,
    output logic [1:0]  des_trigin_type,
    output logic [7:0]  des_trigin_sel,
    output logic [1:0]  trigout_type,
    output logic [5:0]  trigout_sel,
    // ADDRESS / FILL
    output logic [31:0] src_addr,
    output logic [31:0] des_addr,
    output logic [31:0] fillval,
    // ADDRESS INC
    output logic [15:0] src_xaddr_inc,
    output logic [15:0] des_xaddr_inc,
    output logic [7:0]des_trigin_blk_size,
    output logic [7:0]src_trigin_blk_size,
    // STATUS / ERROR
    output logic        stat_done,
    output logic        stat_err,
    output logic [3:0] src_max_burst_len,
    output logic [3:0] des_max_burst_len,  
    output logic [15:0] src_yaddr_stride,
    output logic [15:0] des_yaddr_stride,
    output logic [15:0] src_y_transfer_count,
    output logic [15:0] des_y_transfer_count,
    output logic done_pause_en,
    output logic cmd_restart_en,
    output logic [15:0] cmd_restart_cnt,
    output logic [2:0] reg_reload_type, 
    output logic [2:0] done_type
);
assign use_trigout          = control_config[27];
assign use_des_trigin       = control_config[26];
assign use_src_trigin       = control_config[25];
assign x_type               = control_config[11:9];
assign y_type               = control_config[14:12]; 
assign ch_prio              = control_config[7:4];
assign transize             = control_config[2:0];
assign desx_transfer_count  = x_transfer_count[31:16];
assign srcx_transfer_count  = x_transfer_count[15:0];
assign src_yaddr_stride     = line_stride[15:0];
assign des_yaddr_stride     = line_stride[31:16];
assign src_y_transfer_count = y_transfer_count[15:0];
assign des_y_transfer_count = y_transfer_count[31:16];
assign next_cmd_addr        = {2'b00,CH_next_cmd_addr[31:2]};
assign next_cmd_addren      = CH_next_cmd_addr[0];
assign trigout_ack_sw       = channel_start[24];
assign des_trigin_sw_type   = channel_start[22:21];
assign des_trigin_sw        = channel_start[20];
assign src_trigin_sw_type   = channel_start[18:17];
assign src_trigin_sw        = channel_start[16];
assign resume_cmd           = channel_start[5];
assign pause_cmd            = channel_start[4];
assign stop_cmd             = channel_start[3];
assign disable_cmd          = channel_start[2];
assign enable_cmd           = channel_start[0];
assign stat_err             = channel_status[17];
assign stat_done            = channel_status[16];
assign des_xaddr_inc        = addr_increment_cfg[31:16];
assign src_xaddr_inc        = addr_increment_cfg[15:0];
assign src_trigin_mode      = read_trigger_cfg[11:10];
assign src_trigin_type      = read_trigger_cfg[9:8];
assign src_trigin_sel       = read_trigger_cfg[7:0];
assign des_trigin_mode      = write_trigger_cfg[11:10];
assign des_trigin_type      = write_trigger_cfg[9:8];
assign des_trigin_sel       = write_trigger_cfg[7:0];
assign trigout_type         = trigger_out_cfg[9:8];
assign trigout_sel          = trigger_out_cfg[5:0];
assign src_addr             = read_base_addr;
assign des_addr             = write_base_addr;
assign fillval              = fill_data;
assign src_tmplt            = read_template_data;
assign des_tmplt            = write_template_data;
assign src_tmplt_size       = template_config[12:8];
assign des_tmplt_size       = template_config [20:16];
assign src_trigin_blk_size  = read_trigger_cfg[23:16];
assign des_trigin_blk_size  = write_trigger_cfg[23:16];
assign des_max_burst_len    = write_transfer_cfg[19:16];
assign src_max_burst_len    = read_transfer_cfg[19:16];
assign cmd_restart_en       = auto_restart_config [16];
assign cmd_restart_cnt      = auto_restart_config [15:0];
assign reg_reload_type      = control_config[20:18];
assign done_type            = control_config[23:21];
assign done_pause_en        = control_config [24];
    
endmodule
 
