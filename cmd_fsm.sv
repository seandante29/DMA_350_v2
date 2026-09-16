module cmd_fsm
#(parameter DATA_W = 128)
(
    input logic clk,
    input logic resetn,
    input logic rst_posedge,
    input logic pause_cmd,resume_cmd,
    input logic stop_cmd,
    input logic [3:0] ch_prio,
    input logic [31:0]next_cmd_addr,// from intern reg
    input logic link_enable,// from intern reg
    input logic data_done,// from intern reg
    input logic wr_en,//OR of every write enable
    input logic stat_disable_intr_reg,stat_stopped_intr_reg,
    // AR signals
    input logic ARREADY,
    output logic [3:0] ARID,
    output logic [7:0] ARLEN,
    output logic[2:0] ARSIZE,
    output logic [1:0] ARBURST,
    output logic ARVALID,
    output logic [31:0]ARADDR,
    output logic [3:0] ARQOS,

    // R signals
    input logic [3:0]RID,
    input logic [DATA_W - 1:0]RDATA_I,//32
    input logic [1:0]RRESP,
    input logic RLAST,
    input logic RVALID,
    output  logic RREADY, //combo
    output logic [31:0]RDATA_O,//32
    output logic [31:0] LINK_HEADER,
    output logic [4:0] wptr,
    // ERROR and STATUS signals
    output  logic cmd_done_1,// to mux_logic as select (1 cycle pulse)
    output logic LINKHDRERR,
    output logic CMD_DONE,//done signal to data fsm
    output logic STAT_CMD_DONE, //done signal to muxlogic
    output logic AXIRDRESPERR,//address out of range error
    output logic AXIRDPOISERR,//corrupted data error
    output logic BUSERR,//any axi error asserts this
    input logic STAT_ERROR_PARTSEL
);
    logic [4:0] temp_wptr,temp_rptr;
    logic [DATA_W - 1 : 0] fifo_temp [0:31];
    logic wr_en_reg;
    logic [4:0] current_state, next_state,pause_nxt_st;
    logic [7:0] count;
    logic [7:0] count1;
    logic [7:0] count2;
    logic [7:0] count_reg;
    logic stat_stop_cmd;
    logic rst_posedge_reg;
    logic  max_transfer_count;
    logic data_done_reg;
    logic link_enable_reg;
    logic STAT_ERROR_reg;
    integer i,j;
    logic count_flag;
    logic [$clog2(DATA_W/32)-1:0] chunk_cnt;
    logic [DATA_W-1:0] aligned_data;
    logic [$clog2(DATA_W/8)-1:0] byte_offset;

    logic cmd_error;
    assign cmd_error = (LINKHDRERR | AXIRDRESPERR | AXIRDPOISERR | BUSERR);
    localparam IDLE   = 5'd0;
    localparam AR     = 5'd1;
    localparam R      = 5'd2;
    localparam COUNT  = 5'd3;
    localparam PAUSE  = 5'd4;

    assign RREADY = (current_state == R)? 1:0;

    always @(posedge clk or negedge resetn)
    begin
        if(!resetn) begin
            data_done_reg <= 'd0;
            link_enable_reg <= 'd0;
            STAT_ERROR_reg <= 'd0;
            rst_posedge_reg <= 0;
        end
        else begin
            data_done_reg <= data_done;
            rst_posedge_reg <= rst_posedge;
            link_enable_reg <= link_enable;
            STAT_ERROR_reg <= STAT_ERROR_PARTSEL;
        end
    end

    always@(posedge clk or negedge resetn)
    begin
        if(!resetn)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // pause_next_state logic
    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            pause_nxt_st <= IDLE;
        end
        else begin
            if (next_state != PAUSE)
                pause_nxt_st <= next_state;
        end
    end

    always @(posedge clk or negedge resetn) begin
        if(!resetn) begin
            stat_stop_cmd <= 0;
        end
        else if(stop_cmd) begin
            stat_stop_cmd <= 1;
        end
        else if(!stat_stopped_intr_reg)
            stat_stop_cmd <= 0;
    end

    //combo always
    always@(*) begin
        if(stop_cmd)
            next_state = IDLE;
        else if(pause_cmd)
            next_state = PAUSE;
        else
        begin
            case(current_state)

                IDLE:
                    if(link_enable_reg && (data_done || rst_posedge_reg) && !cmd_error && !stat_disable_intr_reg && !stat_stopped_intr_reg)
                    next_state = AR;
                    else
                    next_state = IDLE;

                PAUSE :
                    if(resume_cmd)
                        next_state = pause_nxt_st;
                    else
                        next_state = PAUSE;
                AR:
                    if(cmd_error)
                    next_state = IDLE;
                    else if(ARREADY && ARVALID)
                    next_state = R;
                    else
                    next_state = AR;

                R:
                    if(cmd_error)
                    next_state = IDLE;
                    else if(RVALID && RREADY && RLAST && count == 0)
                    next_state = COUNT;
                    else  if(RVALID && RREADY && RLAST)
                    begin
                        if(RVALID && RREADY && RLAST  && ((count <=16) || DATA_W != 'd32) )
                            next_state = IDLE;
                        else
                        next_state = AR;
                    end
                    else
                    next_state = R;

                COUNT : begin
                    if(cmd_error)
                    next_state = IDLE;
                    else
                    next_state = AR;
                end

                default : next_state = IDLE;
            endcase
        end
    end

    always@(*) begin
        aligned_data = RDATA_I >> (byte_offset * 8);
        count1 = count;
        if(current_state == IDLE  )
            count1 = 0;
        else if(current_state == COUNT)begin
            count1 = 0;
            for( i = 0 ; i < 32 ; i = i + 1)
                if(!(i == 0 || i == 1 || i == 23||i == 25 || i == 27))
                    count1 = count1 + LINK_HEADER[i];
        end
    end

    always @(posedge clk or negedge resetn)
    begin
        if(!resetn)
            count<='d0;
        else
            if (current_state == IDLE ) count <= 0;
            else if (current_state == COUNT )
            count <= count1;
            else if (current_state == AR && max_transfer_count)
                count <= (count <=16)? count:count - (16);
    end

    always@(posedge clk or negedge resetn)
    begin
        if(!resetn)
            wr_en_reg <= 'd0;
        else
            wr_en_reg <= wr_en;
    end

    assign byte_offset = ARADDR[$clog2(DATA_W/8)-1:0];

    always @(posedge clk or negedge resetn) begin
        if (!resetn) begin
            RDATA_O   <= 32'd0;
            CMD_DONE <= 0;
            temp_rptr <= 0;
            chunk_cnt <= 0;
            wptr <= 0;
            count2 <= 0;
        end
        else begin
            CMD_DONE <= 1;

            if(current_state == IDLE)
            CMD_DONE <= ( ((data_done || count2 > 0) || stop_cmd) ? 0 : 1) ;
            else if (current_state == AR || current_state == COUNT || current_state == PAUSE )
            CMD_DONE <= 0;
            else if (current_state == R)
            CMD_DONE <= ( (count2==0 && count_flag ) ? 1 : CMD_DONE) ;

            if(current_state == AR ) begin
                temp_rptr <= (temp_wptr == 0)? 0 : temp_rptr;
                wptr <= ((count1 == 0) && !max_transfer_count)? 0 :wptr;
                chunk_cnt <= byte_offset/4;
                if(!max_transfer_count)
                    count2 <= (count1 > 0)?count1:count2;
                else
                    count2<=count2;
            end
            // FIFO not empty
            else if (temp_rptr != temp_wptr && count2 !='h0) begin
                // align data for narrow / unaligned transfer
                count2 <= count2 -1 ;
                // output 32-bit chunk
                RDATA_O <= fifo_temp[temp_rptr][chunk_cnt*32 +: 32];
                wptr <= wptr + 1;
                // chunk progression
                if (chunk_cnt == (DATA_W/32 - 1)) begin
                    chunk_cnt <= 0;
                    temp_rptr <= temp_rptr + 1;   // move to next FIFO word
                end
                else begin
                    chunk_cnt <= chunk_cnt + 1;
                end
            end
            else if(temp_wptr == 0)
                temp_rptr <= 0;
        end
    end

    // ERROR HANDLING
    always@(posedge clk or negedge resetn)
    begin
        if(!resetn)
        begin
            for(j=0;j<32;j=j+1) begin
                fifo_temp[j] <= 'd0;end
            count_flag <= 0;
            AXIRDRESPERR <= 0;//address out of range error
            AXIRDPOISERR <= 0;//corrupted data error
            BUSERR <= 0;//any axi error asserts this
            ARADDR <= 0;
            ARID   <= 0;
            count_reg <= 0;
            ARLEN  <= 0;
            ARSIZE <= 'd2;
            ARBURST <=0;
            max_transfer_count <= 0;
            temp_wptr <= 0;
            ARVALID <=0;
            ARQOS <= 0;
            LINKHDRERR <= 0;
            LINK_HEADER <= 0;
            STAT_CMD_DONE <= 1'b0;
            cmd_done_1 <= 1'b0;
        end
        else
        begin
            cmd_done_1 <= 1'b0;
            STAT_CMD_DONE <= cmd_done_1 ;
            ARQOS <= 0;
            case(current_state)

                IDLE:
                begin
                    count_flag <= 0;
                    cmd_done_1 <= (!CMD_DONE && count2 ==0  && link_enable_reg) ;
                    ARADDR <= 0;
                    ARID   <= 1;
                    max_transfer_count <= 0;
                    ARLEN  <= 0;
                    ARSIZE <= 'd2;
                    ARBURST <=0;
                    ARVALID <=0;
                    if(count2 ==0 || stat_stop_cmd) begin
                        temp_wptr <= 0;
                    end
                    if(~STAT_ERROR_PARTSEL)
                    begin
                        BUSERR <= 0;
                        AXIRDPOISERR <= 0;
                        AXIRDRESPERR <= 0;
                        LINKHDRERR <= 0;
                    end
                    if(wr_en_reg)
                        LINK_HEADER <= 0;
                end

                AR:
                begin
                    count_flag <= 0;
                    ARSIZE <= ($clog2(DATA_W/8)) ;//
                    ARVALID <= 1;
                    ARQOS <= ch_prio;
                    if (count == 0) begin
                        ARADDR <= {2'b00,next_cmd_addr[29:0]};
                        ARLEN <= 0;
                        ARBURST <= 1;
                    end
                    else begin
                        ARADDR <= (!ARVALID) ? ( (max_transfer_count) ? ARADDR + 'h40 :ARADDR + 'h4) : ARADDR;

                        if (max_transfer_count) begin
                            ARLEN <= count_reg - 'd17;
                        end
                        else begin
                            if (((count - 1 + (byte_offset/4)) / (DATA_W/32)) > 'd15) begin
                                ARLEN <= 'd15;
                            end
                            else begin
                                ARLEN <= ((count - 1 + (byte_offset/4)) / (DATA_W/32));
                            end
                        end

                        ARBURST <= 1;
                    end
                end

                R:
                begin
                    ARVALID <= 0;
                    if(RREADY && RVALID && !pause_cmd) begin
                        if(count!=0)begin
                            fifo_temp[temp_wptr] <= RDATA_I ;
                            temp_wptr <= temp_wptr +1;
                        end
                        else if(RLAST  && !(|(( (RDATA_I >> ((ARADDR[$clog2(DATA_W/8)-1:0]) * 8)) ) & 32'hffffFFFF)))
                            LINKHDRERR <= 1;
                        else if(RLAST  && (|(((RDATA_I >> ((ARADDR[$clog2(DATA_W/8)-1:0]) * 8))) & 32'hffffFFFF)) && count ==0)begin
                            LINK_HEADER <=(((RDATA_I >> ((ARADDR[$clog2(DATA_W/8)-1:0]) * 8))) & 32'hffffFFFF);
                            temp_wptr <= 0;
                        end

                        if((RRESP == 2'b00 || RRESP == 2'b01) && RLAST)
                        begin
                            if(count!=0) begin
                                max_transfer_count <= 1;
                            end
                        end
                        else if(RRESP == 2'b11)
                        begin
                            BUSERR <= 1'b1;
                            AXIRDRESPERR <=1'b1;
                        end
                        else if(RRESP == 2'b10)
                        begin
                            BUSERR <=1'b1;
                            AXIRDPOISERR <= 1'b1;
                        end
                    end
                end

                COUNT : begin
                    count_flag <= 1;
                    count_reg <= count1;
                end

                default:
                begin
                    count_flag <= 0;
                    ARADDR <= 0;
                    ARID   <= 0;
                    ARLEN  <= 0;
                    ARSIZE <= 3'b111;
                    ARBURST <=0;
                    ARVALID <=0;
                end
            endcase
        end
    end

endmodule
