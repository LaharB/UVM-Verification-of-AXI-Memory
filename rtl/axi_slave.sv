//the design acts as slave and the tb acts as master

module axi_slave(
    //global control signals 
    input clk,
    input resetn,
    //write Address(AW)channel
    input awvalid, //M to S
    output reg awready, //S to M
    input [31:0] awaddr, //M to S
    input [3:0] awid, //M to S, unique ID for each transaction
    input [3:0] awlen, //M to S, burst length AXI3 : 1, 2, 4, 8, 16 beats,AXI4: 1 to 256, beats(burst length) = awlen + 1
    input [2:0] awsize, //M to S, unique transaction size of each beat : 2**awsize, awsize = 0, 1, 2 (generally 2**awsize = 1,2,4,8,16,....128)
    input [1:0] awburst, //M to S, burst type: fixed, INCR, WRAP

    //Write data(W) channel
    input wvalid, //M to S
    output reg wready, //S to M
    input [31:0] wdata, //M to S
    input [3:0] wid, //M to S, unique id for transaction
    input [3:0] wstrb, //M to S, for telling which lane(s) has/have valid data
    input wlast, //M to S, last transfer in write burst

    //Write response(B) channel
    input bready, //M to S
    output reg bvalid, //S to M
    output reg [3:0] bid, //S to M, unique id for transaction
    output reg [1:0] bresp, //S to M

    //Read Address (AR) channel
    input arvalid, //M to S
    output reg arready, //S to M
    input [31:0] araddr, //M to S
    input [3:0] arid, //M to S
    input [3:0] arlen, //M to S
    input [2:0] arsize, //M to S
    input [1:0] arburst, //M to S, burst type: fixed, INCR, WRAP

    //Read Data (R) channel
    input rready, //M to S
    output reg rvalid, //S to M
    output reg [3:0] rid, //S to M, read data id
    output reg [31:0] rdata, //S to M , read data from slave
    output reg rlast, //S to M, read last data signal
    output reg [1:0] rresp //S to M, read response signal
);
    //these are the states to be used for write address channel
    typedef enum bit[1:0] {awidle = 2'b00, awstart = 2'b01, awreadys = 2'b10} awstate_type;
    awstate_type awstate, awnext_state; 

    typedef enum bit [2:0] {widle = 0, wstart = 1, wreadys = 2, wvalids = 3, waddr_dec = 4} wstate_type;
    wstate_type wstate, wnext_state;

    typedef enum bit[1:0] {bidle = 0, bdetect_last = 1, bstart = 2, bwait = 3} bstate_type;
    bstate_type bstate, bnext_state;

    typedef enum bit [1:0] {aridle = 0, arstart = 1, arreadys =2} arstate_type;
    arstate_type arstate, arnext_state;

    typedef enum bit [2:0] {ridle = 0, rstart = 1, rwait = 2, rvalids = 3, rerror = 4} rstate_type;
    rstate_type rstate, rnext_state;

    reg [31:0] awaddrt; //temp reg to store the add value from aw bus

    //reset decoder
    always_ff@(posedge clk or negedge resetn) //async reset
        begin
            if(!resetn) //active low reset
                begin
                    awstate <= awidle; //idle state for write addr FSM 
                    wstate <= widle; //idle state for write data FSM
                    bstate <= bidle; //idle state for write response FSM
                end
            else 
                begin
                    awstate <= awnext_state;
                    wstate <= wnext_state;
                    bstate <= bnext_state;
                end
        end

//3 FSMs - AW FSM, W FSM, B FSM
//////////////////////////////////////////////////////////////////////////////////////////
//FSM for Write address channel
    always_comb
        begin
            case(awstate)
                awidle:
                    begin
                        awready = 1'b0; //S to M
                        awnext_state = awstart;
                    end
                awstart:
                    begin
                        if(awvalid) //M to S
                            begin
                                awaddrt = awaddr; //storing address into temp
                                awnext_state = awreadys;
                            end
                        else 
                            awnext_state = awstart; //esle stay in awstart
                    end
                awreadys:
                    begin
                        awready = 1'b1; //S to M
                        if(wstate == wreadys)
                            awnext_state = awidle;
                        else
                            awnext_state = awreadys; 
                    end 
            endcase
        end
//////////////FSM for write data channel
    //temp regs to store data from buses
    reg [31:0] wdatat;
    reg [7:0] mem[128] = '{default:0}; //mem to write data 
    reg [31:0] return_addr; //addr value returned by function for burst: fixed, INC, WRAP
    reg first; //to check operation executed first time

//////function to compute next address during FIXED burst type
    function bit[31:0] data_wr_fixed(input [3:0] wstrb, input [31:0] awaddrt);
        unique case(wstrb)
            4'b0001: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[7:0];
                end
            4'b0010: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[15:8];
                end
            4'b0011: //only 2 lanes 
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdata[15:8]; 
                end
            4'b0100: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[23:16];
                end
            4'b0101: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[23:16];
                end
            4'b0110: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[15:8];
                    mem[awaddrt + 1] = wdatat[23:16];
                end
            4'b0111: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8];
                    mem[awaddrt + 2] = wdatat[23:16];
                end
            4'b1000: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[31:24];
                end
            4'b1001: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[31:24];
                end
            4'b1010: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[15:8];
                    mem[awaddrt + 1] = wdatat[31:24];
                end
            4'b1011: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8];
                    mem[awaddrt + 2] = wdatat[31:24];
                end 
            4'b1100: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[23:16];
                    mem[awaddrt + 1] = wdatat[31:24];
                end
            4'b1101: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[23:16];
                    mem[awaddrt + 2] = wdatat[31:24];
                end 
            4'b1110: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[15:8];
                    mem[awaddrt + 1] = wdatat[23:16];
                    mem[awaddrt + 2] = wdatat[31:24];
                end
            4'b1111: //all 4 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8];
                    mem[awaddrt + 2] = wdatat[23:16];
                    mem[awaddrt + 3] = wdatat[31:24];
                end
        endcase
        return awaddrt; //fixed awaddr value returned
    endfunction

//////function to compute next address during INCR burst type   
    function bit[31:0] data_wr_incr(input [3:0] wstrb, input [31:0] awaddrt);

    bit [31:0] addr; //varibale to return the incremented address 

        unique case(wstrb)
            4'b0001: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[7:0];
                    addr = awaddrt + 1;
                end
            4'b0010: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[15:8];
                    addr = awaddrt + 1;
                end
            4'b0011: //only 2 lanes 
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8]; 
                    addr = awaddrt + 2; 
                end
            4'b0100: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[23:16];
                    addr = awaddrt + 1;
                end
            4'b0101: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[23:16];
                    addr = awaddrt + 2;
                end
            4'b0110: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[15:8];
                    mem[awaddrt + 1] = wdatat[23:16];
                    addr = awaddrt + 2;
                end
            4'b0111: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8];
                    mem[awaddrt + 2] = wdatat[23:16];
                    addr = awaddrt + 3;
                end
            4'b1000: //only 1 lane
                begin
                    mem[awaddrt] = wdatat[31:24];
                    addr = awaddr + 1;
                end
            4'b1001: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[31:24];
                    addr = awaddrt + 2;
                end
            4'b1010: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[15:8];
                    mem[awaddrt + 1] = wdatat[31:24];
                    addr = awaddrt + 2;
                end
            4'b1011: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8];
                    mem[awaddrt + 2] = wdatat[31:24];
                    addr = awaddrt + 3;
                end 
            4'b1100: //only 2 lanes
                begin
                    mem[awaddrt] = wdatat[23:16];
                    mem[awaddrt + 1] = wdatat[31:24];
                    addr = awaddrt + 2;
                end
            4'b1101: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[23:16];
                    mem[awaddrt + 2] = wdatat[31:24];
                    addr = awaddrt + 3;
                end 
            4'b1110: //only 3 lanes
                begin
                    mem[awaddrt] = wdatat[15:8];
                    mem[awaddrt + 1] = wdatat[23:16];
                    mem[awaddrt + 2] = wdatat[31:24];
                    addr = awaddrt + 3;
                end
            4'b1111: //all 4 lanes
                begin
                    mem[awaddrt] = wdatat[7:0];
                    mem[awaddrt + 1] = wdatat[15:8];
                    mem[awaddrt + 2] = wdatat[23:16];
                    mem[awaddrt + 3] = wdatat[31:24];
                    addr = awaddrt + 4;
                end
        endcase
        return addr; //incremented awaddr value returned
    endfunction

//////function to compute wrapping boundary
    function bit [7:0] wrap_boundary(input bit [3:0] awlen, input bit [2:0] awsize);
        bit [7:0] boundary;
        //burst_length = awlen + 1
        unique case(awlen) //awlen - 1, 3, 7, 15
            4'b0001: //awlen = 1
                begin
                    unique case(awsize) //awsize - 0,1,2
                        3'b000: //2**0 = 1 byte 
                            begin
                                boundary = 2 * 1; // (awlen+1)*(2**awsize)
                            end
                        3'b001: //2**1 = 2 bytes
                            begin
                                boundary = 2 * 2; // (awlen+1)*(2**awsize)
                            end
                        3'b010: //2**2 = 4 bytes
                            begin
                                boundary = 2 * 4; // (awlen+1)*(2**awsize) 
                            end
                    endcase
                end
            4'b0011: //awlen = 3
                begin
                    unique case(awsize) //awsize - 0,1,2
                        3'b000: //2**0 = 1 byte 
                            begin
                                boundary = 4 * 1; // (awlen+1)*(2**awsize)
                            end
                        3'b001: //2**1 = 2 bytes
                            begin
                                boundary = 4 * 2; // (awlen+1)*(2**awsize)
                            end
                        3'b010: //2**2 = 4 bytes
                            begin
                                boundary = 4 * 4; // (awlen+1)*(2**awsize) 
                            end
                    endcase
                end
             4'b0111: //awlen = 7
                begin
                    unique case(awsize) //awsize - 0,1,2
                        3'b000: //2**0 = 1 byte 
                            begin
                                boundary = 8 * 1; // (awlen+1)*(2**awsize)
                            end
                        3'b001: //2**1 = 2 bytes
                            begin
                                boundary = 8 * 2; // (awlen+1)*(2**awsize)
                            end
                        3'b010: //2**2 = 4 bytes
                            begin
                                boundary = 8 * 4; // (awlen+1)*(2**awsize) 
                            end
                    endcase
                end
             4'b1111: //awlen = 15
                begin
                    unique case(awsize) //awsize - 0,1,2
                        3'b000: //2**0 = 1 byte 
                            begin
                                boundary = 16 * 1; // (awlen+1)*(2**awsize)
                            end
                        3'b001: //2**1 = 2 bytes
                            begin
                                boundary = 16 * 2; // (awlen+1)*(2**awsize)
                            end
                        3'b010: //2**2 = 4 bytes
                            begin
                                boundary = 16 * 4; // (awlen+1)*(2**awsize) 
                            end
                    endcase
                end
        endcase

        return boundary;
        
    endfunction
///////////////////////////////////////////////////////////////////////////////////////////
    function bit [31:0] data_wr_wrap(input [3:0] wstrb, input [31:0] awaddrt, input [7:0] wboundary);
        
        bit [31:0] addr1, addr2, addr3, addr4; //vars to store next addresses

        unique case(wstrb)
            4'b0001: //only 1 lane
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;
                        
                    return addr1; 
                end

            4'b0010: //only 1 lane
                begin
                    mem[awaddrt] = wdata[15:8];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    return addr1; 
                end

            4'b0011: //only 2 lanes
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[15:8];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    return addr2; 
                end

            4'b0100: //only 1 lane
                begin
                    mem[awaddrt] = wdata[23:16];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    return addr1; 
                end

            4'b0101: //only 2 lanes
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[23:16];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    return addr2;
                end 

            4'b0110: //only 2 lanes
                begin
                    mem[awaddrt] = wdata[15:8];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[23:16];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    return addr2;
                end

            4'b0111: //only 3 lanes
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[15:8];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    mem[addr2] = wdata[23:16];

                    if((addr2 + 1) % wboundary == 0)
                        addr3 = (addr2 + 1) - wboundary;
                    else
                        addr3 = addr2 + 1;

                    return addr3;
                end
            
            4'b1000: //only 1 lane
                begin
                    mem[awaddrt] = wdata[31:24];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    return addr1; 
                end

            4'b1001: //only 2 lanes
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[31:24];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    return addr2;
                end
            
            4'b1010: //only 2 lanes
                begin
                    mem[awaddrt] = wdata[15:8];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[31:24];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    return addr2;
                end
            
            4'b1011: //only 3 lanes
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[15:8];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    mem[addr2] = wdata[23:16];

                    if((addr2 + 1) % wboundary == 0)
                        addr3 = (addr2 + 1) - wboundary;
                    else
                        addr3 = addr2 + 1;

                    return addr3;
                end 

            4'b1100: //only 2 lanes
                begin
                    mem[awaddrt] = wdata[23:16];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[31:24];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    return addr2;
                end

            4'b1110: //only 3 lanes
                begin
                    mem[awaddrt] = wdata[15:8];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[23:16];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    mem[addr2] = wdata[31:24];

                    if((addr2 + 1) % wboundary == 0)
                        addr3 = (addr2 + 1) - wboundary;
                    else
                        addr3 = addr2 + 1;

                    return addr3;
                end
            
            4'b1111: //all 4 lanes
                begin
                    mem[awaddrt] = wdata[7:0];

                    if((awaddrt + 1) % wboundary == 0)
                        addr1 = (awaddrt + 1) - wboundary;
                    else
                        addr1 = awaddrt + 1;

                    mem[addr1] = wdata[15:8];

                    if((addr1 + 1) % wboundary == 0)
                        addr2 = (addr1 + 1) - wboundary;
                    else
                        addr2 = addr1 + 1;

                    mem[addr2] = wdata[23:16];

                    if((addr2 + 1) % wboundary == 0)
                        addr3 = (addr2 + 1) - wboundary;
                    else
                        addr3 = addr2 + 1;

                    mem[addr3] = wdata[31:24];

                    if((addr3 + 1) % wboundary == 0)
                        addr4 = (addr3 + 1) - wboundary;
                    else
                        addr4 = addr3 + 1;

                    return addr4;
                end    
        endcase   
    endfunction

    reg [7:0] boundary; //storing boundary
    reg [3:0] wlen_count; //keeping count of the burst length
    reg [31:0] nextaddr;

    always_comb
        begin
            case(wstate)

                widle: 
                    begin
                        wready = 1'b0; //S to M
                        wnext_state = wstart;
                        first = 1'b0; //to detect the first time,we enter write data FSM
                        wlen_count = 0;
                    end
                
                wstart: 
                    begin
                        if(wvalid)
                            begin
                                wnext_state = waddr_dec;
                                wdatat = wdata;
                            end
                        else //else stay in this state
                            begin
                                wnext_state = wstart; 
                            end
                    end

                waddr_dec:
                    begin
                        wnext_state = wreadys;
                        if(first == 0)
                            begin
                                nextaddr = awaddr;
                                first = 1'b1;
                                wlen_count = 0;
                            end
                        else if(wlen_count < (awlen + 1)) //if count < burst length, need next address value returned from the functions
                            begin
                                nextaddr = return_addr; //computed by functions:Fixed, INCR, Wrap
                            end
                        else 
                            begin
                                nextaddr = awaddr; 
                            end
                    end


                wreadys:
                    begin
                        if(wlast == 1'b1) //to see last packet written
                            begin
                                wnext_state = widle;
                                wready = 1'b0;
                                wlen_count = 0;
                                first = 0;
                            end
                        else if(wlen_count < (awlen + 1))
                            begin
                                wnext_state = wvalids;
                                wready = 1'b1;
                            end
                        else 
                            wnext_state = wreadys;
            //within wreadys state, we also calculate the next address computed by the functions and return it to waddr_dec state
                        case(awburst)
                            2'b00: ///fixed mode
                                begin
                                    return_addr = data_wr_fixed(wstrb, awaddr); //func for fixed mode
                                end

                            2'b01: //Incr mode
                                begin
                                    return_addr = data_wr_incr(wstrb, nextaddr); //func for incr mode
                                end
                            
                            2'b10: //wrapping mode
                                begin
                                    boundary = wrap_boundary(awlen, awsize); ///for wrapping boundary 
                                    return_addr = data_wr_wrap(wstrb, nextaddr, boundary); //for nextaddr value
                                end
                        endcase

                    end

                wvalids: 
                    begin
                        wready = 1'b0;
                        wnext_state = wstart;
                        if(wlen_count < (awlen + 1))
                            wlen_count = wlen_count + 1;
                        else 
                            wlen_count = wlen_count; 
                    end       
            endcase
        end

///////////fsm for write response 
    always_comb
        begin
            case(bstate)
                bidle:
                    begin
                        bid = 1'b0;
                        bresp = 1'b0;
                        bvalid = 1'b0;
                        bnext_state = bdetect_last;
                    end

                bdetect_last:
                    begin
                        if(wlast) 
                            bnext_state = bstart;
                        else
                            bnext_state = bdetect_last; 
                    end

                bstart:
                    begin
                        bid = awid;
                        bvalid = 1'b1;
                        bnext_state = bwait;
                        if((awaddr < 128) && (awsize <= 3'b010))
                            bresp = 2'b00; //okay
                        else if(awsize > 3'b010)
                            bresp = 2'b10; //slverr
                        else 
                            bresp = 2'b11; //no slave address(out of range)
                    end

                bwait:
                    begin
                        if(bready == 1'b1)
                            bnext_state = bidle;
                        else
                            bnext_state = bwait; 
                    end

            endcase
        end
/////////////////////////////////////////////////////////////////////////////////////////////

    reg [31:0] araddrt; //temp reg to store read address

    /////////fsm for read address
    always_ff@(posedge clk, negedge resetn)
        begin
            if(!resetn)
                begin
                    arstate <= aridle;
                    rstate <= ridle;
                end
            else 
                begin
                    arstate <= arnext_state;
                    rstate <= rnext_state;
                end
        end

    always_comb
        begin
            case(arstate)

                aridle:
                    begin
                        arready = 1'b0; //S to M
                        arnext_state = arstart;
                    end

                arstart:
                    begin
                        if(arvalid == 1'b1)
                            begin
                                arnext_state = arreadys;
                                araddrt = araddr;
                            end 
                        else
                            arnext_state = arstart;
                    end

                arreadys:
                    begin
                        arnext_state = aridle;
                        arready = 1'b1;
                    end
            endcase    
        end
    
///////read data in FIXED mode
    function void read_data_fixed(input [31:0] addr, input [2:0]  arsize);
        unique case(arsize)
            
            3'b000:  //1 byte size, 2**arsize
                begin
                    rdata[7:0] = mem[addr]; //rdata is 32 bit bus 
                end
            
            3'b001: //2 bytes , 2**arsize
                begin
                    rdata[7:0] = mem[addr];
                    rdata[15:8] = mem[addr + 1];
                end
            3'b010: //4 bytes, 2**arsize
                begin
                    rdata[7:0] = mem[addr];
                    rdata[15:8] = mem[addr + 1];
                    rdata[23:16] = mem[addr + 2];
                    rdata[31:24] = mem[addr + 3];
                end
        endcase

    endfunction
//////read data in INCR mode
    function bit [31:0] read_data_incr(input [31:0]addr, input [2:0] arsize);
        bit [31:0] nextaddr; //return this next read addr 

        unique case(arsize)
            3'b000:  //1 byte size, 2**arsize
                begin
                    rdata[7:0] = mem[addr]; //rdata is 32 bit bus
                    nextaddr = addr + 1; 
                end
            
            3'b001: //2 bytes , 2**arsize
                begin
                    rdata[7:0] = mem[addr];
                    rdata[15:8] = mem[addr + 1];
                    nextaddr = addr + 2;
                end
            3'b010: //4 bytes, 2**arsize
                begin
                    rdata[7:0] = mem[addr];
                    rdata[15:8] = mem[addr + 1];
                    rdata[23:16] = mem[addr + 2];
                    rdata[31:24] = mem[addr + 3];
                    nextaddr = addr + 4;
                end 

        endcase

        return nextaddr;
        
    endfunction

//////////////read data in WRAP mode
    function bit [31:0] read_data_wrap(input bit [31:0] addr, input bit [2:0] rsize, input [7:0] rboundary);

        bit[31:0] addr1, addr2, addr3, addr4; //temp vars to store next address

        unique case(rsize)
            3'b000: //1 byte 
                begin
                    rdata[7:0] = mem[addr];
                    
                    if((addr + 1) % rboundary == 0)
                        addr1 = (addr + 1) - rboundary;
                    else 
                        addr1 = (addr + 1);
                    
                    return addr1;
                end
            
            3'b001: //2 bytes
                begin
                    rdata[7:0] = mem[addr];
                    
                    if((addr + 1) % rboundary == 0)
                        addr1 = (addr + 1) - rboundary;
                    else 
                        addr1 = (addr + 1);
                    
                    rdata[15:8] = mem[addr1];
                    
                    if((addr1 + 1) % rboundary == 0)
                        addr2 = (addr1 + 1) - rboundary;
                    else 
                        addr2 = (addr1 + 1);

                    return addr2;
                end
            
            3'b010: //4 bytes
                begin
                    rdata[7:0] = mem[addr];
                    
                    if((addr + 1) % rboundary == 0)
                        addr1 = (addr + 1) - rboundary;
                    else 
                        addr1 = (addr + 1);
                    
                    rdata[15:8] = mem[addr1];
                    
                    if((addr1 + 1) % rboundary == 0)
                        addr2 = (addr1 + 1) - rboundary;
                    else 
                        addr2 = (addr1 + 1);
                    
                    rdata[23:16] = mem[addr2];

                    if((addr2 + 1) % rboundary == 0)
                        addr3 = (addr2 + 1) - rboundary;
                    else 
                        addr3 = (addr2 + 1);
                    
                    rdata[31:24] = mem[addr3];
                    
                    if((addr3 + 1) % rboundary == 0)
                        addr4 = (addr3 + 1) - rboundary;
                    else 
                        addr4 = (addr3 + 1);
                    
                    return addr4;
                end
        endcase
    endfunction

/////////////////////////////////////////////////////////////////////////////////
    reg rdfirst; //to indicate first time data is read 
    bit [31:0] rdnextaddr, rdreturn_addr;
    reg [3:0] len_count; //to count read burst length
    reg [7:0] rdboundary; //to store boundary value returned from boudnary calc function

    always_comb
        begin
            case(rstate)
                ridle: 
                    begin
                        rid = 0;
                        rdfirst = 0;
                        rdata = 0;
                        rresp = 0;
                        rlast = 0;
                        rvalid = 0;
                        len_count = 0;

                        if(arvalid) //M to S
                            rnext_state = rstart;
                        else 
                            rnext_state = ridle;
                    end

                    rstart:
                        begin
                            if((araddrt < 128) && (arsize <= 3'b010))
                                begin
                                    rid = arid;
                                    rvalid = 1'b1; //S to M
                                    rnext_state = rwait;
                                    rresp = 2'b00;

                            //calculating read address to be returned by functions : fixed, incr, wrap
                                    unique case(arburst)

                                        /////////fixed mode 
                                        2'b00:
                                            begin
                                                if(rdfirst == 0)
                                                    begin
                                                        rdnextaddr = araddr; //same fixed addr is returned
                                                        rdfirst = 1'b1;
                                                        len_count = 0;
                                                    end 
                                                else if(len_count != (arlen + 1))
                                                    begin
                                                        rdnextaddr = araddr;
                                                    end
                                                read_data_fixed(araddrt, arsize);
                                            end
                                        ////////////INCR mode
                                        2'b01:
                                            begin
                                                if(rdfirst == 0)
                                                    begin
                                                        rdnextaddr = araddr;
                                                        rdfirst = 1'b1;
                                                        len_count = 0;
                                                    end
                                                else if(len_count != (arlen + 1))
                                                    begin
                                                        rdnextaddr = rdreturn_addr; //passing next addr calculated by read_data_incr fucntion
                                                    end
                                                
                                                rdreturn_addr = read_data_incr(rdnextaddr, arsize);
                                            end
                                        ///////////Burst mode
                                        2'b10:
                                            begin
                                                if(rdfirst == 0)
                                                    begin
                                                        rdnextaddr = araddr;
                                                        rdfirst = 1'b1;
                                                        len_count = 0;
                                                    end 
                                                else if(len_count != (arlen + 1))
                                                    begin
                                                        rdnextaddr = rdreturn_addr;
                                                    end
                                                
                                                rdboundary = wrap_boundary(arlen, arsize);
                                                rdreturn_addr = read_data_wrap(rdnextaddr, arsize, rdboundary);
                                            end
                                    endcase
                                end  

                            else if((araddr >= 128) && (arsize <= 2'b010))
                                begin
                                    rresp = 2'b11;
                                    rvalid = 1'b1;
                                    rnext_state = rerror;
                                end
                            else if(arsize > 3'b010) //araddr < 128 but arsize > 2 (> 4 bytes)
                                begin
                                    rresp = 2'b10;
                                    rvalid = 1'b1;
                                    rnext_state = rerror;    
                                end
                        end

                rwait:
                    begin
                        rvalid = 1'b0;
                        if(rready == 1'b1)
                            begin
                                rnext_state = rvalids;
                            end
                        else 
                            rnext_state = rwait;
                    end
                
                rvalids:
                    begin
                        len_count = len_count + 1;
                        if(len_count == (arlen + 1))
                            begin
                                rnext_state = ridle;
                                rlast = 1'b1;
                            end
                        else 
                            begin
                                rnext_state = rstart;
                                rlast = 1'b0;
                            end
                    end

                rerror:
                    begin
                        rvalid = 1'b0;

                        if(len_count < (arlen))
                            begin
                                if(arready)
                                //if(rready)
                                    begin
                                        rnext_state = rstart;
                                        len_count = len_count + 1;
                                    end 
                                else
                                    begin
                                        rlast = 1'b1;
                                        rnext_state = ridle;
                                        len_count = 0;
                                    end
                            end    
                    end
                
                default: rnext_state = ridle;
            endcase    
        end
endmodule
////////////////////////////////////////////////////////////////////////////////////////////
/////////INTERFACE ////////////////
interface axi_if();
    //global control signals 
    logic clk;
    logic resetn;

    //Address Write(AW) channel
    logic awvalid; //M to S
    logic awready; //S to M
    logic [31:0] awaddr; //M to S
    logic [3:0] awid; //M to S, unique id for each transaction
    logic [3:0] awlen; //M to S, burst length = awlen + 1
    logic [2:0] awsize; //M to S, awsize : 0, 1, 2 (generally 2**awsize = 1,2,4,8,16,....128)
    logic [1:0] awburst; //M to S, burst type: fixed, incr, wrap

    //Write Data(W) channel
    logic wvalid; //M to S
    logic wready; //S to M
    logic [3:0] wid; //M to S, unique id for transaction
    logic [31:0] wdata; //M to S
    logic [3:0] wstrb; //M to S, lane having valid data
    logic wlast; //M to S, last transfer in write burst

    //Write Response(B) channel
    logic bready; //M to S
    logic bvalid; //S to M
    logic [3:0] bid; //S to M, unique id for transaction
    logic [1:0] bresp; //S to M

    //Read Address(AR) channel
    logic arvalid; //M to S
    logic arready; //S to M
    logic [3:0] arid; //M to S, unique id for transaction
    logic [3:0] arlen; //M to S, burst length = arlen + 1
    logic [2:0] arsize; //M to S, 2**arsize = 1,2,4 bytes
    logic [31:0] araddr; //M to S
    logic [1:0] arburst; //M to S, burst type: fixed, incr, wrap

    //Read data(R) channel
    logic rvalid; //S to M
    logic rready; //M to S
    logic [3:0] rid; //S to M
    logic [31:0] rdata; //S t M
    logic [3:0] rstrb; //S to M , lane having valid data
    logic rlast; //last transfer in write burst
    logic [1:0] rresp; //S to M

    ///extra vars for next_addr in write and read 
    logic [31:0] next_addrwr;
    logic [31:0] next_addrrd;

endinterface 