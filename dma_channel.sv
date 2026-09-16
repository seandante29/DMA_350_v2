module dma_channel
#(parameter WIDTH = 32,
  parameter ADDR_W = 32,
  parameter DATA_W = 128,
  parameter ID_W   = 4,
  parameter DEPTH = 145
)
(
    input logic clk,resetn,
    // reg bank signals
    input logic [WIDTH-1 : 0] cfg_channel_start,
    input logic [WIDTH-1 : 0] cfg_channel_status,
    input logic [WIDTH-1 : 0] cfg_interrupt_enable,
    input logic [WIDTH-1 : 0] cfg_control_config,
    input logic [WIDTH-1 : 0] cfg_read_base_addr,
    input logic [WIDTH-1 : 0] cfg_write_base_addr,
    input logic [WIDTH-1 : 0] cfg_x_transfer_count,
    input logic [WIDTH-1 : 0] cfg_read_transfer_cfg,
    input logic [WIDTH-1 : 0] cfg_write_transfer_cfg,
    input logic [WIDTH-1 : 0] cfg_addr_increment_cfg,
    input logic [WIDTH-1 : 0] cfg_fill_data,
    input logic [WIDTH-1 : 0] cfg_read_trigger_cfg,
    input logic [WIDTH-1 : 0] cfg_write_trigger_cfg,
    input logic [WIDTH-1 : 0] cfg_trigger_out_cfg,
    input logic [WIDTH-1 : 0] cfg_auto_restart_config,
    input logic [WIDTH-1 : 0] cfg_next_cmd_addr,
    input logic [WIDTH-1 : 0] cfg_work_reg_pointer,
    input logic [WIDTH-1 : 0] cfg_read_template_data,
    input logic [WIDTH-1 : 0] cfg_write_template_data,
    input logic [WIDTH-1 : 0] cfg_template_config,
    input logic [WIDTH-1 : 0] cfg_line_stride,
    input logic [WIDTH-1 : 0] cfg_y_transfer_count,

    input logic boot_en,
    input logic [29:0] boot_addr,
    input logic is_ch0,

    input logic chn_cmd_wr_en_o,
    input logic chn_stat_wr_en_o,
    input logic chn_intren_wr_en_o,
    input logic chn_ctrl_wr_en_o,
    input logic chn_read_base_addr_wr_en_o,
    input logic chn_write_base_addr_wr_en_o,
    input logic chn_x_transfer_count_wr_en_o,
    input logic chn_srctrans_wr_en_o,
    input logic chn_destrans_wr_en_o,
    input logic chn_xaddrinc_wr_en_o,
    input logic chn_fillval_wr_en_o,
    input logic chn_srctrigin_wr_en_o,
    input logic chn_destrigin_wr_en_o,
    input logic chn_trigout_wr_en_o,
    input logic chn_autocfg_wr_en_o,
    input logic chn_next_cmd_addr_wr_en_o,
    input logic chn_tmpltcfg_wr_en_o,chn_destmplt_wr_en_o,chn_srctmplt_wr_en_o,chn_y_transfer_count_wr_en_o,chn_yaddrestride_wr_en_o,chn_work_reg_pointer_wr_en_o,



    //inter reg signals
    output logic [(WIDTH*18)-1 : 0] chn_reg_out,
    output logic reg_wr_en,
    output  logic IRQ,
    //cmd fsm signal
    input logic ARREADY,
    input logic [ID_W-1:0] RID,
    input logic [DATA_W-1 : 0]RDATA_I,
    input logic [1:0]RRESP,
    input logic RLAST,
    input logic RVALID,

    input logic WREADY,
    input logic AWREADY,
    input logic [ID_W-1:0] BID,
    input logic BVALID,
    input logic [1:0] BRESP,
    input logic stop_cmd_apb,pause_cmd_apb,
    //trig matrix o/p's as i/p's to channel
    input logic SRCTRIGINSELERR, DESTRIGINSELERR, TRIGOUTSELERR,
    input logic src_trig_req,
    input logic [1:0]  src_trig_req_type,

    input logic         des_trig_req,
    input logic  [1:0]  des_trig_req_type,

    input logic ch_trigout_ack,

    output logic        ch_src_ack,
    output logic [1:0]  ch_src_ack_type,

    output logic        ch_des_ack,
    output logic [1:0]  ch_des_ack_type,

    output logic        ch_trigout_req,

    output logic stat_err,



    // to sys mem
    output logic [ID_W -1:0] ARID,
    output logic [7:0] ARLEN,
    output logic[2:0] ARSIZE,
    output logic [1:0] ARBURST,
    output logic ARVALID,
    output logic [ADDR_W-1 : 0]ARADDR,
    output logic RREADY,

    output logic [ID_W -1:0] AWID_D,
    output logic [7:0] AWLEN_D,
    output logic[2:0] AWSIZE_D,
    output logic [1:0] AWBURST_D,
    output logic AWVALID_D,
    output logic [ADDR_W-1:0]AWADDR_D,
    output logic WVALID_D,
    output logic [DATA_W -1 :0] WDATA_D,
    output logic WLAST_D,
    output logic BREADY_D,
    output logic [3:0] AWQOS,
    output logic [3:0] ARQOS,
    output logic [1:0]  src_trigin_type,
    output logic [7:0]  src_trigin_sel,
    output logic [1:0]  des_trigin_type,
    output logic [7:0]  des_trigin_sel,
    output logic [1:0]  trigout_type,
    output logic [5:0]  trigout_sel,
    output logic        use_trigout,
    output logic        use_des_trigin,
    output logic        use_src_trigin,
    output logic [(WIDTH*3)-1 : 0] src_des_x_transfer_count_updated,
    output logic [WIDTH -1:0]wrkregval_rd,
    output logic [(DATA_W/8)-1:0] WSTRB,
    output   logic [WIDTH -1:0] read_base_addr_UPDATED,
    output logic [WIDTH -1:0]  write_base_addr_UPDATED,
    output logic [WIDTH -1:0]  x_transfer_count_UPDATED,y_transfer_count_UPDATED,
    output logic enable_cmd_to_apb

);

    logic [3:0] src_max_burst_len;
    logic [3:0] des_max_burst_len;
    logic [4:0] des_tmplt_size;
    logic [4:0] src_tmplt_size;
    logic [31:0] des_tmplt;
    logic [31:0] src_tmplt;
    logic [7:0]des_trigin_blk_size;
    logic [7:0]src_trigin_blk_size;
    logic [15:0] src_yaddr_stride;
    logic [15:0] des_yaddr_stride;
    logic [15:0] src_y_transfer_count;
    logic[15:0] des_y_transfer_count;
    logic [3:0] ch_prio;

    logic [31:0] read_base_addr_INITIAL,read_base_addr_LINEINITIAL;
    logic [31:0] write_base_addr_INITIAL,write_base_addr_LINEINITIAL;
    logic [31:0] SRCx_transfer_count_INITIAL,DESy_transfer_count_INITIAL;
    logic [31:0] DESx_transfer_count_INITIAL,SRCy_transfer_count_INITIAL;
    logic cmd_done_1;
    logic [(WIDTH * 21) -1:0]  mux_logic_in;
    logic deassert_stat_done;
    logic [15:0] restart_cnt_reg1;
    // wires to part select

    logic [31:0] control_config_O;
    logic [31:0] interrupt_enable_O;
    logic [31:0] x_transfer_count_O;
    logic [31:0] CH_next_cmd_addr_O;
    logic [31:0] channel_start_O;
    logic [31:0] channel_status_O;
    logic [31:0] addr_increment_cfg_O;
    logic [31:0] read_transfer_cfg_O;
    logic [31:0] write_transfer_cfg_O;
    logic [31:0] read_trigger_cfg_O;
    logic [31:0] write_trigger_cfg_O;
    logic [31:0] trigger_out_cfg_O;
    logic [31:0] read_base_addr_O;
    logic [31:0] write_base_addr_O;
    logic [31:0] fill_data_O;
    logic [31:0] write_template_data_O;
    logic [31:0] read_template_data_O;
    logic [31:0] template_config_O;
    logic [31:0] auto_restart_config_O;
    logic [31:0] line_stride_O;
    logic [31:0] y_transfer_count_O;
    logic cmd_restart_en;
    logic [15:0] cmd_restart_cnt;
    logic [2:0] reg_reload_type;
    logic [2:0] done_type;
    logic done_pause_en;

    logic  wr_en_for_updated;
    //wires to data fsm

    logic [2:0] x_type,y_type;
    logic [2:0] transize;
    logic [15:0] srcx_transfer_count;
    logic [15:0] desx_transfer_count;
    logic [31:0] next_cmd_addr;
    logic next_cmd_addren;
    logic stop_cmd;
    logic enable_cmd;
    logic disable_cmd;
    logic pause_cmd;
    logic resume_cmd;
    logic [1:0] src_trigin_sw_type, des_trigin_sw_type;
    logic src_trigin_sw;
    logic [1:0]  src_trigin_sw_req_type;
    logic des_trigin_sw;
    logic [1:0] des_trigin_sw_req_type;
    logic trigout_ack_sw;
    logic [1:0] src_trigin_mode;
    logic [1:0] des_trigin_mode;
    logic [31:0] src_addr;
    logic [31:0] des_addr;
    logic [31:0] fillval;
    logic [15:0] src_xaddr_inc;
    logic [15:0] des_xaddr_inc;
    logic stat_done;
    logic DONE;
    logic wr_en;
    // wires to internal reg from data fsm( stat and cmd)
    logic STAT_TRIGOUTACKWAIT_DATA;
    logic STAT_DESTRIGINWAIT_DATA;
    logic STAT_SRCTRIGINWAIT_DATA;
    logic STAT_RESUMEWAIT_DATA;
    logic STAT_STOPPED_DATA;
    logic STAT_PAUSED_DATA;
    logic STAT_DISABLED_DATA;
    logic STAT_DONE_DATA;

    logic ENABLECMD_DATA;
    logic DISABLECMD_DATA;
    logic STOPCMD_DATA;
    logic  SWTRIGOUTACK_DATA,SRCSWTRIGINREQ_DATA ,DESSWTRIGINREQ_DATA;

    // wires to cmd fsm
    logic [31:0] RDATA_O;
    logic [31:0] LINK_HEADER;
    logic [4:0] wptr;
    logic LINKHDERR;
    logic CMD_DONE,STAT_CMD_DONE; //done signal to data fsm
    logic AXIRDRESPERR;//address out of range error
    logic AXIRDPOISERR;//corrupted data error
    logic BUSERR;//any axi error asserts this

    //wires to trig mtx

    logic [1:0] des_trigin_ack_type;
    logic [1:0] src_trigin_ack_type;
    logic trig_out_req;
    logic des_trigack;
    logic src_trigack;
    logic stat_done_intr_reg ,stat_disable_intr_reg,stat_stopped_intr_reg ,stat_err_intr_reg ;
    assign wr_en =chn_ctrl_wr_en_o || chn_stat_wr_en_o || chn_intren_wr_en_o  ||
                chn_read_base_addr_wr_en_o || chn_write_base_addr_wr_en_o || chn_x_transfer_count_wr_en_o
                || chn_srctrans_wr_en_o || chn_destrans_wr_en_o || chn_xaddrinc_wr_en_o ||
                chn_fillval_wr_en_o || chn_srctrigin_wr_en_o || chn_destrigin_wr_en_o ||
                chn_trigout_wr_en_o || chn_next_cmd_addr_wr_en_o || chn_autocfg_wr_en_o || chn_srctmplt_wr_en_o || chn_destmplt_wr_en_o || chn_tmpltcfg_wr_en_o;


    logic [3:0] ARID_D;
    logic [7:0] ARLEN_D;
    logic[2:0] ARSIZE_D;
    logic [1:0] ARBURST_D;
    logic ARVALID_D;
    logic [31:0]ARADDR_D;
    logic RREADY_D ;
    logic [3:0] ARQOS_D;

    logic [3:0] ARID_CMD;
    logic [7:0] ARLEN_CMD;
    logic[2:0] ARSIZE_CMD;
    logic [1:0] ARBURST_CMD;
    logic ARVALID_CMD;
    logic [31:0]ARADDR_CMD;
    logic RREADY_CMD ;
    logic [3:0] ARQOS_CMD;
    logic pause_cmd_apb_reg;
    always @(posedge clk or negedge resetn)
    begin
        if(!resetn)
            pause_cmd_apb_reg <= 0;
        else
            pause_cmd_apb_reg <= pause_cmd_apb;
    end


    logic [54 : 0] AR_D;
    assign AR_D = (pause_cmd_apb|pause_cmd_apb_reg) ? {ARVALID_D, ARADDR_D, ARSIZE_D, ARBURST_D, ARID_D, ARLEN_D,1'b0,ARQOS_D} : {ARVALID_D, ARADDR_D, ARSIZE_D, ARBURST_D, ARID_D, ARLEN_D,RREADY_D,ARQOS_D};
    logic [54 : 0] AR_CMD;
    assign AR_CMD = (pause_cmd_apb|pause_cmd_apb_reg) ? {ARVALID_CMD, ARADDR_CMD, ARSIZE_CMD, ARBURST_CMD, ARID_CMD, ARLEN_CMD,1'b0,ARQOS_CMD}:{ARVALID_CMD, ARADDR_CMD, ARSIZE_CMD, ARBURST_CMD, ARID_CMD, ARLEN_CMD,RREADY_CMD,ARQOS_CMD};
    assign {ARVALID, ARADDR, ARSIZE, ARBURST, ARID, ARLEN,RREADY,ARQOS} = CMD_DONE?AR_D:AR_CMD;
    assign enable_cmd_to_apb = enable_cmd;
    logic rst_posedge;
  


    internal_reg  #(.WIDTH (WIDTH),.DEPTH ( DEPTH)) dut0
    (
    .clk(clk),
    .resetn(resetn),
    .boot_addr(boot_addr),
    .rst_posedge(rst_posedge),
    .boot_en(boot_en),
    .is_ch0(is_ch0),
    .deassert_stat_done(deassert_stat_done),
    .data_in(mux_logic_in),
    .AXIRDRESPERR(AXIRDRESPERR),
    .AXIRDPOISERR(AXIRDPOISERR),
    .AXIWRRESPERR(AXIWRRESPERR),
    .BUSERR(BUSERR),
    .config_error(config_error),
    .regval_error(regval_error),
    .SRCTRIGINSELERR(SRCTRIGINSELERR),
    .DESTRIGINSELERR(DESTRIGINSELERR),
    .TRIGOUTSELERR(TRIGOUTSELERR),
    .AXIRDRESPERR_CMDFSM(AXIRDRESPERR_CMDFSM),
    .AXIRDPOISERR_CMDFSM(AXIRDPOISERR_CMDFSM),
    .BUSERR_CMDFSM(BUSERR_CMDFSM),
    .LINKHDERR(LINKHDERR),
    .STAT_TRIGOUTACKWAIT_DATA(STAT_TRIGOUTACKWAIT_DATA),
    .STAT_DESTRIGINWAIT_DATA(STAT_DESTRIGINWAIT_DATA),
    .STAT_SRCTRIGINWAIT_DATA(STAT_SRCTRIGINWAIT_DATA),
    .STAT_RESUMEWAIT_DATA(STAT_RESUMEWAIT_DATA),
    .STAT_STOPPED_DATA(STAT_STOP_DATA),
    .STAT_PAUSED_DATA(STAT_PAUSED_DATA),
    .STAT_DISABLED_DATA(STAT_DISABLE_DATA),
    .STAT_DONE_DATA(STAT_DONE_DATA),
    .ENABLECMD_DATA(ENABLECMD_DATA),
    .DISABLECMD_DATA(DISABLECMD_DATA),
    .STOPCMD_DATA(STOPCMD_DATA),
    .SWTRIGOUTACK_DATA(SWTRIGOUTACK_DATA),
    .SRCSWTRIGINREQ_DATA(SRCSWTRIGINREQ_DATA),
    .DESSWTRIGINREQ_DATA(DESSWTRIGINREQ_DATA),
    .chn_reg_out(chn_reg_out),
    .reg_wr_en(reg_wr_en),
    .control_config_O(control_config_O),
    .interrupt_enable_O(interrupt_enable_O),
    .x_transfer_count_O(x_transfer_count_O),
    .CH_next_cmd_addr_O(CH_next_cmd_addr_O),
    .channel_start_O(channel_start_O),
    .channel_status_O(channel_status_O),
    .addr_increment_cfg_O(addr_increment_cfg_O),
    .read_transfer_cfg_O(read_transfer_cfg_O),
    .write_transfer_cfg_O(write_transfer_cfg_O),
    .read_trigger_cfg_O(read_trigger_cfg_O),
    .write_trigger_cfg_O(write_trigger_cfg_O),
    .trigger_out_cfg_O(trigger_out_cfg_O),
    .read_base_addr_O(read_base_addr_O),
    .write_base_addr_O(write_base_addr_O),
    .fill_data_O(fill_data_O),
    .auto_restart_config_O(auto_restart_config_O),
    .line_stride_O(line_stride_O),
    .y_transfer_count_O(y_transfer_count_O),
    .stat_done_intr_reg(stat_done_intr_reg),
    .stat_disable_intr_reg(stat_disable_intr_reg),
    .stat_stopped_intr_reg (stat_stopped_intr_reg ),
    .stat_err_intr_reg (stat_err_intr_reg ),
    .IRQ(IRQ),
    .src_des_x_transfer_count_updated(src_des_x_transfer_count_updated),
    .read_base_addr_INITIAL(read_base_addr_INITIAL),
    .write_base_addr_INITIAL(write_base_addr_INITIAL),
    .write_base_addr_LINEINITIAL(write_base_addr_LINEINITIAL),
    .read_base_addr_LINEINITIAL(read_base_addr_LINEINITIAL),
    .SRCx_transfer_count_INITIAL(SRCx_transfer_count_INITIAL),
    .DESx_transfer_count_INITIAL(DESx_transfer_count_INITIAL),
    .DESy_transfer_count_INITIAL(DESy_transfer_count_INITIAL),
    .SRCy_transfer_count_INITIAL(SRCy_transfer_count_INITIAL),
    .wrkregval_rd(wrkregval_rd),
    .cfg_work_reg_pointer(cfg_work_reg_pointer),
    .template_config_O(template_config_O),
    .read_template_data_O(read_template_data_O),
    .write_template_data_O(write_template_data_O)

    );

    partselect dut1(
    .control_config(control_config_O),
    .x_transfer_count(x_transfer_count_O),
    .CH_next_cmd_addr(CH_next_cmd_addr_O),
    .channel_start(channel_start_O),
    .channel_status(channel_status_O),
    .addr_increment_cfg(addr_increment_cfg_O),
    .read_trigger_cfg(read_trigger_cfg_O),
    .write_trigger_cfg(write_trigger_cfg_O),
    .trigger_out_cfg(trigger_out_cfg_O),
    .read_transfer_cfg(read_transfer_cfg_O),
    .write_transfer_cfg(write_transfer_cfg_O),
    .read_base_addr(read_base_addr_O),
    .write_base_addr(write_base_addr_O),
    .fill_data(fill_data_O),
    .template_config(template_config_O),
    .read_template_data(read_template_data_O),
    .write_template_data(write_template_data_O),
    .auto_restart_config(auto_restart_config_O),
    .line_stride(line_stride_O),
    .y_transfer_count(y_transfer_count_O),
    .use_trigout(use_trigout),
    .use_des_trigin(use_des_trigin),
    .use_src_trigin(use_src_trigin),
    .x_type(x_type),
    .y_type(y_type),
    .ch_prio(ch_prio),
    .transize(transize),
    .srcx_transfer_count(srcx_transfer_count),
    .done_pause_en(done_pause_en),
    .desx_transfer_count(desx_transfer_count),
    .next_cmd_addr(next_cmd_addr),
    .next_cmd_addren(next_cmd_addren),
    .enable_cmd(enable_cmd),
    .disable_cmd(disable_cmd),
    .pause_cmd(pause_cmd),
    .resume_cmd(resume_cmd),
    .stop_cmd(stop_cmd),
    .src_trigin_sw(src_trigin_sw),
    .src_trigin_sw_type(src_trigin_sw_type),
    .des_trigin_sw(des_trigin_sw),
    .des_trigin_sw_type(des_trigin_sw_type),
    .trigout_ack_sw(trigout_ack_sw),
    .src_trigin_mode(src_trigin_mode),
    .src_trigin_type(src_trigin_type),
    .src_trigin_sel(src_trigin_sel),
    .des_trigin_mode(des_trigin_mode),
    .des_trigin_type(des_trigin_type),
    .des_trigin_sel(des_trigin_sel),
    .trigout_type(trigout_type),
    .trigout_sel(trigout_sel),
    .src_addr(src_addr),
    .des_addr(des_addr),
    .fillval(fillval),
    .src_xaddr_inc(src_xaddr_inc),
    .des_xaddr_inc(des_xaddr_inc),
    .stat_done(stat_done),
    .stat_err(stat_err),
    .des_tmplt_size(des_tmplt_size),
    .src_tmplt_size(src_tmplt_size),
    .des_tmplt(des_tmplt),
    .src_tmplt(src_tmplt),
    .src_trigin_blk_size(src_trigin_blk_size),
    .des_trigin_blk_size(des_trigin_blk_size),
    .des_max_burst_len(des_max_burst_len),
    .src_max_burst_len(src_max_burst_len),
    .cmd_restart_en(cmd_restart_en),
    .cmd_restart_cnt(cmd_restart_cnt),
    .reg_reload_type(reg_reload_type),
    .done_type(done_type),
    .src_yaddr_stride(src_yaddr_stride),
    .des_yaddr_stride(des_yaddr_stride),
    .src_y_transfer_count(src_y_transfer_count),
    .des_y_transfer_count(des_y_transfer_count)

    );

    cmd_fsm #(
    .DATA_W(DATA_W)
    ) dut2(.clk(clk),
    .resetn(resetn),
    .rst_posedge(rst_posedge),
    .STAT_ERROR_PARTSEL(stat_err),
    .next_cmd_addr(next_cmd_addr),
    .link_enable(next_cmd_addren),
    .wr_en(wr_en),
    .stop_cmd(stop_cmd_apb),
    .resume_cmd(resume_cmd),
    .pause_cmd(pause_cmd_apb),
    .stat_disable_intr_reg(stat_disable_intr_reg),
    .stat_stopped_intr_reg(stat_stopped_intr_reg),
    .ch_prio(ch_prio),
    .data_done(DONE),
    .ARREADY(ARREADY),
    .ARID(ARID_CMD),
    .ARLEN(ARLEN_CMD),
    .ARSIZE(ARSIZE_CMD),
    .ARBURST(ARBURST_CMD),
    .ARVALID(ARVALID_CMD),
    .ARADDR(ARADDR_CMD),
    .ARQOS(ARQOS_CMD),
    .RID(RID),
    .RDATA_I(RDATA_I),
    .RRESP(RRESP),
    .RLAST(RLAST),
    .RVALID(RVALID),
    .RREADY(RREADY_CMD),
    .RDATA_O(RDATA_O),
    .LINK_HEADER(LINK_HEADER),
    .wptr(wptr),
    .LINKHDRERR(LINKHDERR),
    .CMD_DONE(CMD_DONE),
    .STAT_CMD_DONE(STAT_CMD_DONE),
    .AXIRDRESPERR(AXIRDRESPERR_CMDFSM),
    .AXIRDPOISERR(AXIRDPOISERR_CMDFSM),
    .BUSERR(BUSERR_CMDFSM),
    .cmd_done_1(cmd_done_1)
    );

    mux_logic  #(.WIDTH (WIDTH))
    dut3  (.cmd_data(RDATA_O),
    .clk(clk),
    .resetn(resetn),
    .rst_posedge(rst_posedge),
    .read_base_addr_UPDATED(read_base_addr_UPDATED),
    .write_base_addr_UPDATED(write_base_addr_UPDATED),
    .x_transfer_count_UPDATED(x_transfer_count_UPDATED),
    .y_transfer_count_UPDATED(y_transfer_count_UPDATED),
    .wr_en_for_updated(wr_en_for_updated),
    .wptr(wptr),
    .data_done(DONE),
    .cmd_done(STAT_CMD_DONE),
    .link_en(next_cmd_addren),
    .cmd_restart_en(cmd_restart_en),.restart_cnt_reg1(restart_cnt_reg1),
    .header_in(LINK_HEADER),
    .channel_status(channel_status_O),
    .control_config(control_config_O),
    .interrupt_enable(interrupt_enable_O),
    .x_transfer_count(x_transfer_count_O),
    .CH_next_cmd_addr(CH_next_cmd_addr_O),
    .addr_increment_cfg(addr_increment_cfg_O),
    .read_transfer_cfg(read_transfer_cfg_O),
    .write_transfer_cfg(write_transfer_cfg_O),
    .read_trigger_cfg(read_trigger_cfg_O),
    .write_trigger_cfg(write_trigger_cfg_O),
    .trigger_out_cfg(trigger_out_cfg_O),
    .read_base_addr(read_base_addr_O),
    .write_base_addr(write_base_addr_O),
    .fill_data(fill_data_O),
    .template_config(template_config_O),
    .write_template_data(write_template_data_O),
    .read_template_data(read_template_data_O),
    .auto_restart_config(auto_restart_config_O),
    .line_stride(line_stride_O),
    .y_transfer_count(y_transfer_count_O),
    .read_base_addr_INITIAL(read_base_addr_INITIAL),
    .write_base_addr_INITIAL(write_base_addr_INITIAL),
    .write_base_addr_LINEINITIAL(write_base_addr_LINEINITIAL),
    .read_base_addr_LINEINITIAL(read_base_addr_LINEINITIAL),
    .SRCx_transfer_count_INITIAL(SRCx_transfer_count_INITIAL),
    .DESx_transfer_count_INITIAL(DESx_transfer_count_INITIAL),
    .DESy_transfer_count_INITIAL(DESy_transfer_count_INITIAL),
    .SRCy_transfer_count_INITIAL(SRCy_transfer_count_INITIAL),
    .cfg_channel_start            (cfg_channel_start),
    .cfg_channel_status         (cfg_channel_status),
    .cfg_interrupt_enable         (cfg_interrupt_enable),
    .cfg_control_config           (cfg_control_config),
    .cfg_read_base_addr        (cfg_read_base_addr),
    .cfg_write_base_addr        (cfg_write_base_addr),
    .cfg_x_transfer_count          (cfg_x_transfer_count),
    .cfg_read_transfer_cfg    (cfg_read_transfer_cfg),
    .cfg_write_transfer_cfg    (cfg_write_transfer_cfg),
    .cfg_addr_increment_cfg       (cfg_addr_increment_cfg),
    .cfg_fill_data        (cfg_fill_data),
    .cfg_read_trigger_cfg   (cfg_read_trigger_cfg),
    .cfg_write_trigger_cfg   (cfg_write_trigger_cfg),
    .cfg_trigger_out_cfg     (cfg_trigger_out_cfg),
    .cfg_next_cmd_addr          (cfg_next_cmd_addr),
    .cfg_template_config(cfg_template_config),
    .cfg_read_template_data(cfg_read_template_data),
    .cfg_write_template_data(cfg_write_template_data),
    .cfg_auto_restart_config (cfg_auto_restart_config),
    .cfg_line_stride(cfg_line_stride),
    .cfg_y_transfer_count(cfg_y_transfer_count),
    .chn_cmd_wr_en_o       (chn_cmd_wr_en_o),
    .chn_stat_wr_en_o      (chn_stat_wr_en_o),
    .chn_intren_wr_en_o    (chn_intren_wr_en_o),
    .chn_ctrl_wr_en_o      (chn_ctrl_wr_en_o),
    .chn_read_base_addr_wr_en_o   (chn_read_base_addr_wr_en_o),
    .chn_write_base_addr_wr_en_o   (chn_write_base_addr_wr_en_o),
    .chn_x_transfer_count_wr_en_o     (chn_x_transfer_count_wr_en_o),
    .chn_srctrans_wr_en_o  (chn_srctrans_wr_en_o),
    .chn_destrans_wr_en_o  (chn_destrans_wr_en_o),
    .chn_xaddrinc_wr_en_o  (chn_xaddrinc_wr_en_o),
    .chn_fillval_wr_en_o   (chn_fillval_wr_en_o),
    .chn_srctrigin_wr_en_o (chn_srctrigin_wr_en_o),
    .chn_destrigin_wr_en_o (chn_destrigin_wr_en_o),
    .chn_trigout_wr_en_o   (chn_trigout_wr_en_o),
    .chn_next_cmd_addr_wr_en_o  (chn_next_cmd_addr_wr_en_o),
    .chn_tmpltcfg_wr_en_o (chn_tmpltcfg_wr_en_o),
    .chn_destmplt_wr_en_o (chn_destmplt_wr_en_o),
    .chn_srctmplt_wr_en_o (chn_srctmplt_wr_en_o),
    .chn_autocfg_wr_en_o (chn_autocfg_wr_en_o),
    .chn_y_transfer_count_wr_en_o(chn_y_transfer_count_wr_en_o),
    .chn_yaddr_wr_en_o(chn_yaddrestride_wr_en_o),
    .mux_out_reg(mux_logic_in)
    );

    data_fsm #(.ADDR_W(ADDR_W),.DATA_W(DATA_W), .ID_W(ID_W)) dut4(
    .clk(clk),
    .resetn(resetn),
    .read_base_addr_UPDATED(read_base_addr_UPDATED),
    .write_base_addr_UPDATED(write_base_addr_UPDATED),
    .x_transfer_count_UPDATED(x_transfer_count_UPDATED),
    .LINKHDERR(LINKHDERR),
    .deassert_stat_done(deassert_stat_done),
    .des_trigin_sw_type(des_trigin_sw_type),
    .src_trigin_sw_type(src_trigin_sw_type),
    .cmd_restart_en(cmd_restart_en),.restart_cnt_reg1(restart_cnt_reg1),
    .cmd_restart_cnt(cmd_restart_cnt),
    .reg_reload_type(reg_reload_type),
    .done_type(done_type),
    .done_pause_en(done_pause_en),
    .src_trigin_blk_size(src_trigin_blk_size),
    .des_trigin_blk_size(des_trigin_blk_size),
    .wr_en_for_updated(wr_en_for_updated),
    .stat_error_intr_reg(stat_err_intr_reg),
    .stat_done_intr_reg(stat_done_intr_reg),
    .link_en(next_cmd_addren),
    .des_tmplt_size(des_tmplt_size),
    .src_tmplt_size(src_tmplt_size),
    .des_tmplt(des_tmplt),
    .src_tmplt(src_tmplt),
    .enable_cmd_partsel(enable_cmd),
    .pause_cmd_partsel(pause_cmd_apb),//pause_cmd
    .disable_cmd_partsel(disable_cmd),
    .stop_cmd_partsel(stop_cmd),
    . resume_cmd_partsel(resume_cmd),
    .cmd_done(CMD_DONE),
    .stat_disable_intr_reg(stat_disable_intr_reg),
    .stat_stop_intr_reg(stat_stopped_intr_reg),
    .use_src_trigin(use_src_trigin),
    .src_trigin_type(src_trigin_type),
    .src_trigin_mode(src_trigin_mode),
    .src_trigin_sel(src_trigin_sel),
    .use_des_trigin(use_des_trigin),
    .des_trigin_type(des_trigin_type),
    .des_trigin_mode(des_trigin_mode),
    .des_trigin_sel(des_trigin_sel),
    .use_trigout(use_trigout),
    .trigout_type(trigout_type),
    .trigout_sel(trigout_sel),
    .src_trigin_sw(src_trigin_sw),
    .des_trigin_sw(des_trigin_sw),
    .trig_out_ack_sw(trigout_ack_sw),
    .src_trig_req_type(src_trig_req_type),//
    .des_trig_req_type(des_trig_req_type),//trig mtx
    .src_trigack_type(ch_src_ack_type),//to trig mtx
    .des_trigack_type(ch_des_ack_type),
    .src_trigin(src_trig_req),//from trig
    .des_trigin(des_trig_req),//from trig
    .src_trigack(ch_src_ack),//to trig
    .des_trigack(ch_des_ack),
    .trig_out_req(ch_trigout_req),
    .trig_out_ack(ch_trigout_ack),//from trig
    .SRC_ADDR(src_addr),//
    .des_ADDR(des_addr),
    .transize(transize),
    .srcx_transfer_count(srcx_transfer_count),
    .desx_transfer_count(desx_transfer_count),
    .x_type(x_type),
    .y_type(y_type),
    .ch_prio(ch_prio),
    .fillval(fillval),
    .src_xaddr_inc(src_xaddr_inc),
    .des_xaddr_inc(des_xaddr_inc),
    .ARREADY(ARREADY),
    .ARVALID(ARVALID_D),
    .ARADDR(ARADDR_D),
    .ARSIZE(ARSIZE_D),
    .ARBURST(ARBURST_D),
    .ARID(ARID_D),
    .ARLEN(ARLEN_D),
    .ARQOS(ARQOS_D),
    .RID(RID),
    .RVALID(RVALID),
    .RDATA(RDATA_I),
    .RRESP(RRESP),
    .RLAST(RLAST),
    .RREADY(RREADY_D),
    .AWREADY(AWREADY),
    .AWVALID(AWVALID_D),
    .AWADDR(AWADDR_D),
    .AWSIZE(AWSIZE_D),
    .AWBURST(AWBURST_D),
    .AWLEN(AWLEN_D),
    .AWID(AWID_D),
    .AWQOS(AWQOS),
    .WREADY(WREADY),
    .WVALID(WVALID_D),
    .WDATA(WDATA_D),
    .WLAST(WLAST_D),
    .BID(BID),
    .BVALID(BVALID),
    .BRESP(BRESP),
    .BREADY(BREADY_D),
    .DONE(DONE),
    .config_error(config_error),
    .ard_error(AXIRDRESPERR),
    .arpoison_error(AXIRDPOISERR),
    .awr_error(AXIWRRESPERR),
    .bus_error(BUSERR),
    .regvalerr(regval_error),
    .ENABLECMD_DATA(ENABLECMD_DATA),
    .DISABLECMD_DATA(DISABLECMD_DATA),
    .STOPCMD_DATA(STOPCMD_DATA),
    .SWTRIGOUTACK_DATA(SWTRIGOUTACK_DATA),
    .SRCSWTRIGINREQ_DATA(SRCSWTRIGINREQ_DATA),
    .DESSWTRIGINREQ_DATA(DESSWTRIGINREQ_DATA),
    .STAT_STOP_DATA(STAT_STOP_DATA),
    .STAT_DISABLE_DATA(STAT_DISABLE_DATA),
    .STAT_RESUMEWAIT_DATA(STAT_RESUMEWAIT_DATA),
    .STAT_TRIGOUTACKWAIT_DATA(STAT_TRIGOUTACKWAIT_DATA),
    .STAT_SRCTRIGINWAIT_DATA(STAT_SRCTRIGINWAIT_DATA),
    .STAT_DESTRIGINWAIT_DATA(STAT_DESTRIGINWAIT_DATA),
    .STAT_PAUSED_DATA(STAT_PAUSED_DATA),
    .STAT_DONE_DATA(STAT_DONE_DATA),
    .read_base_addr_INITIAL(read_base_addr_INITIAL),
    .write_base_addr_INITIAL(write_base_addr_INITIAL),
    .write_base_addr_LINEINITIAL(write_base_addr_LINEINITIAL),
    .read_base_addr_LINEINITIAL(read_base_addr_LINEINITIAL),
    .SRCx_transfer_count_INITIAL(SRCx_transfer_count_INITIAL),
    .DESx_transfer_count_INITIAL(DESx_transfer_count_INITIAL),
    .y_transfer_count_UPDATED(y_transfer_count_UPDATED),
    .DESy_transfer_count_INITIAL(DESy_transfer_count_INITIAL),
    .SRCy_transfer_count_INITIAL(SRCy_transfer_count_INITIAL),
    .des_max_burst_len(des_max_burst_len),
    .src_max_burst_len(src_max_burst_len),
    .WSTRB(WSTRB),
    .stop_cmd_apb(stop_cmd_apb),
    .src_yaddr_stride(src_yaddr_stride),
    .des_yaddr_stride(des_yaddr_stride),
    .src_y_transfer_count(src_y_transfer_count),
    .des_y_transfer_count(des_y_transfer_count)
    );

endmodule
