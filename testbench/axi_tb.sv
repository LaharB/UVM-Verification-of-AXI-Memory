`include "uvm_macros.svh"
import uvm_pkg::*;

typedef enum bit[2:0] {wrrdfixed = 0, wrrdincr = 1, wrrdwrap = 2, wrrderrfix = 3, rstdut = 4} oper_mode;

////1.TRANSACTION
class transaction extends uvm_sequence_item;
   `uvm_object_utils(transaction)

   function new(input string path = "transaction");
    super.new(path);
   endfunction 

    //extra signals
    int len = 0;
    rand bit [3:0] id; //giving this same id values to all channels
    oper_mode op;

    //related to interface signals
    //AR channel
    rand bit awvalid; //M to S
    bit awready; //S to M
    bit [3:0] awid; //M to S
    rand bit [3:0] awlen; //M to S, burst length: 1,2,4 beats
    rand bit [2:0] awsize; //M to S, 2**awsize = 1,2,4 bytes(00,01,10)
    rand bit [31:0] awaddr; //M to S
    rand bit [1:0] awburst; //M to S
    
    //W channel 
    bit wvalid; //M to S
    bit wready; //S to M
    bit [3:0] wid;//M to S
    rand bit[31:0] wdata; //M to S
    rand bit [3:0] wstrb; //M to S
    bit wlast; 
    
    //B channel
    bit bready; //M to S
    bit bvalid; //S to M
    bit [3:0] bid; //S to M
    bit [1:0] bresp; //S to M
    
    //AR channel
    rand bit arvalid; //M to S
    bit arready; //S to M
    bit [3:0] arid; //M to S
    rand bit [3:0] arlen; //M to S, burst length: 1,2,4 beats 
    bit [3:0] arsize; //M to S,1,2,4 bytes
    rand bit [31:0] araddr; //M to S
    rand bit [1:0] arburst; //M to S
    
    //R channel
    bit rready; //M to S
    bit rvalid; //S to M
    bit [3:0] rid; //S to M
    bit [31:0] rdata; //S to M
    bit [3:0] rstrb; //S to M
    bit rlast; 
    bit [1:0] rresp; //S to M

    //constraints
    constraint txid {awid == id; wid == id; bid == id; arid == id; rid == id;} //same id for all channels
    constraint burst {awburst inside {0,1,2}; arburst inside {0,1,2};}
    constraint valid {awvalid != arvalid;} //cannot write and read at the same time
    constraint length {awlen == arlen; }

endclass
////2.SEQUENCES
/////different sequences 
class rst_dut extends uvm_sequence#(transaction);
    `uvm_object_utils(rst_dut)

    transaction tr;

    function new(input string path = "rst_dut");
        super.new(path);
    endfunction

    //task body() to randomize data members
    virtual task body();
        repeat(5)
            begin
                tr = transaction::type_id::create("tr");
                $display("-------------------------------------");
                `uvm_info("SEQ", "Sending RST Transaction to DRV", UVM_NONE);
                start_item(tr);
                assert(tr.randomize);
                tr.op = rstdut; //set by self
                finish_item(tr);
            end
    endtask
endclass
///////////////////////////////////////////////////////////////////
class valid_wrrd_fixed extends uvm_sequence#(transaction);
    `uvm_object_utils(valid_wrrd_fixed)

    transaction tr;

    function new(input string path = "valid_wrrd_fixed");
        super.new(path);
    endfunction

    //task body() to randomize data members
    virtual task body();
            tr = transaction::type_id::create("tr");
            $display("-------------------------------------");
            `uvm_info("SEQ", "Sending Fixed mode Transaction to DRV", UVM_NONE);
            start_item(tr);
            assert(tr.randomize);
            tr.op = wrrdfixed; //set by self
            tr.awlen = 7; //overwrite to 7
            tr.awburst = 0; // fixed mode
            tr.awsize = 2; //2**awsize = 4 bytes 
            finish_item(tr);
    endtask
endclass
///////////////////////////////////////////////////////////////////
class valid_wrrd_incr extends uvm_sequence#(transaction);
    `uvm_object_utils(valid_wrrd_incr)

    transaction tr;

    function new(input string path = "valid_wrrd_incr");
        super.new(path);
    endfunction

    //task body() to randomize data members
    virtual task body();
            tr = transaction::type_id::create("tr");
            $display("-------------------------------------");
            `uvm_info("SEQ", "Sending INCR mode Transaction to DRV", UVM_NONE);
            start_item(tr);
            assert(tr.randomize);
            tr.op = wrrdincr; //set by self
            tr.awlen = 7; //overwrite to 7
            tr.awburst = 1; // incr mode
            tr.awsize = 2; //2**awsize = 4 bytes 
            finish_item(tr);
    endtask
endclass
///////////////////////////////////////////////////////////////////
class valid_wrrd_wrap extends uvm_sequence#(transaction);
    `uvm_object_utils(valid_wrrd_wrap)

    transaction tr;

    function new(input string path = "valid_wrrd_wrap");
        super.new(path);
    endfunction

    //task body() to randomize data members
    virtual task body();
            tr = transaction::type_id::create("tr");
            $display("-------------------------------------");
            `uvm_info("SEQ", "Sending WRAP mode Transaction to DRV", UVM_NONE);
            start_item(tr);
            assert(tr.randomize);
            tr.op = wrrdwrap; //set by self
            tr.awlen = 7; //overwrite to 7
            tr.awburst = 2; // wrap mode
            tr.awsize = 2; //2**awsize = 4 bytes 
            finish_item(tr);
    endtask
endclass
///////////////////////////////////////////////////////////////////
class err_wrrd_fix extends uvm_sequence#(transaction);
    `uvm_object_utils(err_wrrd_fix)

    transaction tr;

    function new(input string path = "err_wrrd_fix");
        super.new(path);
    endfunction

    //task body() to randomize data members
    virtual task body();
            tr = transaction::type_id::create("tr");
            $display("-------------------------------------");
            `uvm_info("SEQ", "Sending INCR mode Transaction to DRV", UVM_NONE);
            start_item(tr);
            assert(tr.randomize);
            tr.op = wrrderrfix; //set by self
            tr.awlen = 7; //overwrite to 7
            tr.awburst = 0; // fixed mode
            tr.awsize = 2; //2**awsize = 4 bytes 
            finish_item(tr);
    endtask
endclass
///////////////////////////////////////////////////////////////////
/////3.DRIVER
class driver extends uvm_driver#(transaction);
    `uvm_component_utils(driver)

    virtual axi_if vif; //interface handle to get access to
    transaction tr;   //to store packet sent by sequence

    function new(input string path = "driver", uvm_component parent = null);
        super.new(path, parent);
    endfunction
    
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr", null);
        if(!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif))
            `uvm_error("DRV", "Unable to access interface");
    endfunction

    //task to reset the dut
    task reset_dut();
        begin
            `uvm_info("DRV", "System Reset : Start of Simulation", UVM_MEDIUM);
            vif.resetn <= 1'b0; //active low reset
            vif.awvalid <= 1'b0;
            vif.awid <= 1'b0;
            vif.awlen <= 0;
            vif.awsize <= 0;
            vif.awaddr <= 0;
            vif.awburst <= 0;

            vif.wvalid <= 0;
            vif.wid <= 0;
            vif.wdata <= 0;
            vif.wstrb <= 0;
            vif.wlast <= 0;

            vif.bready <= 0;

            vif.arvalid <= 1'b0;
            vif.arid <= 1'b0;
            vif.arlen <= 0;
            vif.arsize <= 0;
            vif.araddr <= 0;
            vif.arburst <= 0;

            vif.rready <= 0;
            @(posedge vif.clk); //wait for 1 clk tick
        end
    endtask
///////////////////////////////////////////////////////////////////////////////
    //write read in FIXED mode
    ///////// WRITE ////////////////
    task wrrd_fixed_wr(); //write transaction in write read fixed mode
        `uvm_info("DRV", "Fixed Mode Write Transaction Started", UVM_NONE);
        vif.resetn <= 1'b1;

        vif.awvalid <= 1'b1; //M to S
        vif.awid <= tr.id; //set according to the constraint 
        vif.awlen <= 7; //8 beats 
        vif.awsize <= 2; //4 bytes
        vif.awaddr <= 5; //overwrite to 5
        vif.awburst <= 0; //fixed mode

        vif.wvalid <= 1'b1; //M to S
        vif.wid <= tr.id;
        vif.wdata <= $urandom_range(0,10); //overwrite , 1st beat
        vif.wstrb <= 4'b1111; //overwrite to all 4 lanes valid 
        vif.wlast <= 0; //make wlast 1 when all transactions are complete 
//we cannot keep arvalid and awvalid both 1 at the same time so we need another task
        vif.arvalid <= 1'b0; //turn off read
        vif.rready <= 1'b0; 
        vif.bready <= 1'b0; //M to S, will be 1 when transaction is complete 
        @(posedge vif.clk);
        //wait for slave to give response
        @(posedge vif.wready); //wready = 1 denotes 1st transaction complete , now send new data and repeat
        @(posedge vif.clk); 
    //7 more beats to go , as 1st beat already done
        for(int i = 0; i < (vif.awlen); i++) //0 to 6 - 7 beats
            begin
                vif.wdata <= $urandom_range(0,10);
                vif.wstrb <= 4'b1111; //for further beats , we set it again
                @(posedge vif.wready); //wait for slave response just like 1st beat outside for loop
                @(posedge vif.clk); 
            end
        //after 8 beats , set them 
        vif.awvalid <= 1'b0; 
        vif.wvalid <= 1'b0;
        vif.wlast <= 1'b1; //M to S, since last beat written make it 1
        vif.bready <= 1'b1; //M to S , M ready for response from slave 
        
        //Wait for slave to give response 
        @(negedge vif.bvalid);
        vif.wlast <= 1'b0;
        vif.bready <= 1'b0;
    endtask

///After write task, do the read task
    /////////////  READ  /////////////////
    task wrrd_fixed_rd(); //read those transactions, after write transactions in write read fixed mode
        `uvm_info("DRV", "Fixed Mode Read Transaction Started", UVM_NONE);
        @(posedge vif.clk);
        vif.arid <= tr.id; //same id for all channels
        vif.arlen <= 7; //8 beats
        vif.arsize <= 2; //4 bytes
        vif.araddr <= 5; //read from the starting address , 1st read beat
        vif.arburst <= 0; //fixed mode while reading as well
        vif.arvalid <= 1'b1; //M to S 
        vif.rready <= 1'b1; //M to S , M ready to get read data from slave
//1st read beat will take place and so on repeat till 8 beats 
        for(int i = 0; i < (vif.arlen + 1); i++) //0 to 7 - 8 beats 
            begin
            //wait for slave response rvalid or can also use arready(M to S) as both become 1 at the same time 
            //@(posedge vif.arready);
            @(posedge vif.rvalid); //S to M
            //wait for 1 clk tick
            @(posedge vif.clk);
            end
            //after 8th read beat
            @(negedge vif.rlast); //S to M. rlast = 1 indicates completion of reading all beats 
            vif.arvalid <= 1'b0; 
            vif.rready <= 1'b0;         
    endtask

////////////////////////////////////////////////////////////////////////////////
    //write read in INCR mode
    /////  WRITE //////////
    task wrrd_incr_wr(); //write transaction in write read incr mode
        `uvm_info("DRV", "INCR Mode Write Transaction Started", UVM_NONE);
        vif.resetn <= 1'b1;

        vif.awvalid <= 1'b1; //M to S
        vif.awid <= tr.id; //set according to the constraint 
        vif.awlen <= 7; //8 beats 
        vif.awsize <= 2; //4 bytes
        vif.awaddr <= 5; //overwrite to 5
        vif.awburst <= 1; //INCR mode

        vif.wvalid <= 1'b1; //M to S
        vif.wid <= tr.id;
        vif.wdata <= $urandom_range(0,10); //overwrite , 1st beat
        vif.wstrb <= 4'b1111; //overwrite to all 4 lanes valid 
        vif.wlast <= 0;
//we cannot keep arvalid and awvalid both 1 at the same time so we need another task
        vif.arvalid <= 1'b0; //turn off read
        vif.rready <= 1'b0; 
        vif.bready <= 1'b0;
        @(posedge vif.clk);
        //wait for slave to give response
        @(posedge vif.wready); 
        @(posedge vif.clk); 
    //7 more beats to go , as 1st beat already done
        for(int i = 0; i < (vif.awlen); i++) //0 to 6 - 7 beats
            begin
                vif.wdata <= $urandom_range(0,10);
                vif.wstrb <= 4'b1111; //for further beats , we set it again
                @(posedge vif.wready); //wait for slave response
                @(posedge vif.clk); 
            end
        //after 8 beats , set them 
        vif.wlast <= 1'b1; //M to S, since last beat written make it 1
        vif.bready <= 1'b1; //M to S , ready for response
        vif.awvalid <= 1'b0;
        vif.wvalid <= 1'b0;
        //Wait for slave to give response 
        @(negedge vif.bvalid);
        vif.wlast <= 1'b0;
        vif.bready <= 1'b0;
    endtask

///After write task, do the read task
    /////////////  READ  /////////////////
    task wrrd_incr_rd(); //read those transactions, after write transactions in write read incr mode
        `uvm_info("DRV", "INCR Mode Read Transaction Started", UVM_NONE);
        @(posedge vif.clk);
        vif.arid <= tr.id; //same id for all channels
        vif.arlen <= 7; //8 beats
        vif.arsize <= 2; //4 bytes
        vif.araddr <= 5; //read from the starting address , 1st read beat
        vif.arburst <= 1; //fixed mode while reading as well
        vif.arvalid <= 1'b1; //M to S
        vif.rready <= 1'b1; //M to S
//1st read beat will take place and so on repeat till 8 beats 
        for(int i = 0; i < (vif.arlen + 1); i++) //0 to 7 - 8 beats 
            begin
            //wait for slave response 
            //@(posedge vif.arready);
            @(posedge vif.rvalid); //S to M
            //wait for 1 clk tick
            @(posedge vif.clk);
            end
            //after 8th read beat
            @(negedge vif.rlast); //S to M
            vif.arvalid <= 1'b0; 
            vif.rready <= 1'b0;         
    endtask

////////////////////////////////////////////////////////////////////////////////
    //write read in WRAP mode
    /////  WRITE //////////
    task wrrd_wrap_wr(); //write transaction in write read fixed mode
        `uvm_info("DRV", "WRAP Mode Write Transaction Started", UVM_NONE);
        vif.resetn <= 1'b1;

        vif.awvalid <= 1'b1; //M to S
        vif.awid <= tr.id; //set according to the constraint 
        vif.awlen <= 7; //8 beats 
        vif.awsize <= 2; //4 bytes
        vif.awaddr <= 5; //overwrite to 5
        vif.awburst <= 2; //WRAP mode

        vif.wvalid <= 1'b1; //M to S
        vif.wid <= tr.id;
        vif.wdata <= $urandom_range(0,10); //overwrite , 1st beat
        vif.wstrb <= 4'b1111; //overwrite to all 4 lanes valid 
        vif.wlast <= 0;
//we cannot keep arvalid and awvalid both 1 at the same time so we need another task
        vif.arvalid <= 1'b0; //turn off read
        vif.rready <= 1'b0; //M to S
        vif.bready <= 1'b0; //M to S
        @(posedge vif.clk);
        //wait for slave to give response
        @(posedge vif.wready); 
        @(posedge vif.clk); 
    //7 more beats to go , as 1st beat already done
        for(int i = 0; i < (vif.awlen); i++) //0 to 6 - 7 beats
            begin
                vif.wdata <= $urandom_range(0,10);
                vif.wstrb <= 4'b1111; //for further beats , we set it again
                @(posedge vif.wready); //wait for slave response
                @(posedge vif.clk); 
            end
        //after 8 beats , set them 
        vif.wlast <= 1'b1; //M to S, since last beat written make it 1
        vif.bready <= 1'b1; //M to S , ready for response
        vif.awvalid <= 1'b0;
        vif.wvalid <= 1'b0;
        //Wait for slave to give response 
        @(negedge vif.bvalid);
        vif.wlast <= 1'b0;
        vif.bready <= 1'b0;
    endtask

///After write task, do the read task
    /////////////  READ  /////////////////
    task wrrd_wrap_rd(); //read those transactions, after write transactions in write read fixed mode
        `uvm_info("DRV", "WRAP Mode Read Transaction Started", UVM_NONE);
        @(posedge vif.clk);
        vif.arid <= tr.id; //same id for all channels
        vif.arlen <= 7; //8 beats
        vif.arsize <= 2; //4 bytes
        vif.araddr <= 5; //read from the starting address , 1st read beat
        vif.arburst <= 2; //incr mode while reading as well
        vif.arvalid <= 1'b1; //M to S
        vif.rready <= 1'b1; //M to S
//1st read beat will take place and so on repeat till 8 beats 
        for(int i = 0; i < (vif.arlen + 1); i++) //0 to 7 - 8 beats 
            begin
            //wait for slave response 
            //@(posedge vif.arready);
            @(posedge vif.rvalid); //S to M
            //wait for 1 clk tick
            @(posedge vif.clk);
            end
            //after 8th read beat
            @(negedge vif.rlast); //S to M
            vif.arvalid <= 1'b0; 
            vif.rready <= 1'b0;        
    endtask

//////////////////////////////////////////////////////////////////////////////////////
//WRITE READ ERROR
    /////  WRITE ERROR //////////
    task err_wr(); //write transaction in write read fixed mode
        `uvm_info("DRV", "Error Write Transaction Started", UVM_NONE);
        vif.resetn <= 1'b1;

        vif.awvalid <= 1'b1; //M to S
        vif.awid <= tr.id; //set according to the constraint 
        vif.awlen <= 7; //8 beats
        vif.awsize <= 2; //4 bytes
        vif.awaddr <= 128; //overwrite to 128 , addr out of range , we want to test error
        vif.awburst <= 0; //fixed mode

        vif.wvalid <= 1'b1; //M to S
        vif.wid <= tr.id;
        vif.wdata <= $urandom_range(0,10); //overwrite , 1st beat
        vif.wstrb <= 4'b1111; //overwrite to all 4 lanes valid 
        vif.wlast <= 0;
//we cannot keep arvalid and awvalid both 1 at the same time so we need nother task
        vif.arvalid <= 1'b0; //turn off read
        vif.rready <= 1'b0; 
        vif.bready <= 1'b0;
        @(posedge vif.clk);
        //wait for slave to give response
        @(posedge vif.wready); 
        @(posedge vif.clk); 
    //7 more beats to go , as 1st beat already done
        for(int i = 0; i < (vif.awlen); i++) //0 to 6 - 7 beats
            begin
                vif.wdata <= $urandom_range(0,10);
                vif.wstrb <= 4'b1111; //for further beats , we set it again
                @(posedge vif.wready); //wait for slave response
                @(posedge vif.clk); 
            end
        //after 8 beats , set them 
        vif.wlast <= 1'b1; //M to S, since last beat written make it 1
        vif.bready <= 1'b1; //M to S , ready for response
        vif.awvalid <= 1'b0;
        vif.wvalid <= 1'b0;
        //Wait for slave to give response 
        @(negedge vif.bvalid);
        vif.wlast <= 1'b0;
        vif.bready <= 1'b0;
    endtask

///After write error task, do the read error task
    /////////////  READ ERROR /////////////////
    task err_rd(); //read those transactions, after write transactions in write read fixed mode
        `uvm_info("DRV", "Error Read Transaction Started", UVM_NONE);
        @(posedge vif.clk);
        vif.arvalid <= 1'b1; //M to S
        vif.rready <= 1'b1; //M to S
        vif.arid <= tr.id; //same id for all channels
        vif.arlen <= 7; //8 beats
        vif.arsize <= 2; //4 bytes
        vif.araddr <= 128; //read from the starting address , 1st read beat
        vif.arburst <= 0; //fixed mode while reading as well
//1st read beat will take place and so on repeat till 8 beats 
        for(int i = 0; i < (vif.arlen + 1); i++) //0 to 7 - 8 beats 
            begin
            //wait for slave response 
            //@(posedge vif.arready);
            @(posedge vif.rvalid); //S to M, rvalid goes 1 8 times for 8 read beats 
            //wait for 1 clk tick
            @(posedge vif.clk);
            end
            //after 8th read beat
            @(negedge vif.rlast); //S to M
            vif.arvalid <= 1'b0; 
            vif.rready <= 1'b0;         
    endtask
/////////////////////////////////////////////////////////////////////////

    //run_phase
    virtual task run_phase(uvm_phase phase);
        forever
            begin
                seq_item_port.get_next_item(tr); //telling sequencer to send next packet 
                if(tr.op == rstdut)
                    reset_dut(); //calling reset task
                else if(tr.op == wrrdfixed)
                    begin
                        `uvm_info("DRV", $sformatf("Fixed Mode Write -> Read WLEN:%0d WSIZE:%0d", tr.awlen+1, tr.awsize), UVM_MEDIUM);
                        wrrd_fixed_wr();
                        wrrd_fixed_rd();
                    end
                else if(tr.op == wrrdincr)
                    begin
                        `uvm_info("DRV", $sformatf("INCR Mode Write -> Read WLEN:%0d WSIZE:%0d", tr.awlen+1, tr.awsize), UVM_MEDIUM);
                        wrrd_incr_wr();
                        wrrd_incr_rd();
                    end
                else if(tr.op == wrrdwrap)
                    begin
                       `uvm_info("DRV", $sformatf("WRAP Mode Write -> Read WLEN:%0d WSIZE:%0d", tr.awlen+1, tr.awsize), UVM_MEDIUM);
                        wrrd_wrap_wr();
                        wrrd_wrap_rd(); 
                    end
                else if(tr.op == wrrderrfix)
                    begin
                        `uvm_info("DRV", $sformatf("Error Transaction Mode WLEN:%0d WSIZE:%0d", tr.awlen+1, tr.awsize), UVM_MEDIUM);
                        err_wr();
                        err_rd();
                    end
                seq_item_port.item_done();
            end
    endtask
endclass
////////////////////////////////////////////////////////////////////////////////////////////
////5.MONITOR
class mon extends uvm_monitor;
    `uvm_component_utils(mon)

    transaction tr; //to store response sent by DUT
    virtual axi_if vif; //to get access to interface 

    logic [31:0] arr[128]; //temp arr[128] to store data being written into arr[awaddr]
    
    //vars to store the responses
    logic [1:0] rdresp; 
    logic [1:0] wrresp;  

    int err = 0;

    function new(input string path = "mon", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    //build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        tr = transaction::type_id::create("tr");
        if(!uvm_config_db#(virtual axi_if)::get(this, "", "vif", vif)) //uvm_tb_top.e.a.mon
            `uvm_error("MON", "Unable to acces interface");
    endfunction
////////////////////////////////////////////////////////////////////////////////////////////
    //compare task to compare DUT response and data stored in temp array[128]
    task compare();
        if(err == 0 && rdresp == 0 && wrresp == 0)
            begin
                `uvm_info("MON", $sformatf("Test Passed err:%0d, wrresp:%0d, rdresp:%0d", err, rdresp, wrresp), UVM_MEDIUM);
                 err = 0;
            end
        else
            begin
                `uvm_info("MON", $sformatf("Test Failed err:%0d, wrresp:%0d, rdresp:%0d", err, rdresp, wrresp), UVM_MEDIUM);
                 err = 0;
            end
    endtask

//////run_phase
    virtual task run_phase(uvm_phase phase);
        forever 
            begin
                @(posedge vif.clk); //wait ofr 1 clk tick
                if(!vif.resetn)
                    begin
                        `uvm_info("MON", "System Reset Detected", UVM_MEDIUM);
                    end 
                else if(vif.resetn && vif.awaddr < 128)
                    begin
                        wait(vif.awvalid == 1'b1);

                        for(int i = 0; i < (vif.awlen + 1); i++) //storing wdata for all 8 beats 
                            begin
                                @(posedge vif.wready);
                                arr[vif.next_addrwr] = vif.wdata;
                            end
                            //bvalid = 1 indicates completion of all writes 
                            @(posedge vif.bvalid); //wait for write response from slave
                            wrresp = vif.bresp; //0 - no error
                        ///////////////////////////////////////////////////////
                        //both awvalid and arvalid cannot be 1 at the same time
                        wait(vif.arvalid == 1'b1); //wait for read to start

                        for(int i = 0; i < (vif.arlen + 1); i++) //check for all 8 beats
                            begin
                            @(posedge vif.rvalid); //S to M, goes 1 8 times for 8 beats
                            if(vif.rdata != arr[vif.next_addrrd])
                                begin
                                    err++;
                                end 
                            end
                                @(posedge vif.rlast); //rlast indicates completion of all reads
                                rdresp = vif.rresp; //passing read response to temp var

                                compare();
                                $display("-------------------------------------------------------");
                    end
                else if(vif.resetn && vif.awaddr >= 128)
                    begin
                        wait(vif.awvalid == 1'b1);

                        for(int i = 0; i < (vif.arlen + 1); i++)
                            begin
                                @(negedge vif.wready); //wait for slave response
                            end
                        @(posedge vif.bvalid);
                        wrresp = vif.bresp;
                        //both awvalid and arvalid cannot be 1 at the same time
                        wait(vif.arvalid == 1'b1);

                        for(int i = 0; i < (vif.arlen + 1); i++) //check for all 8 beats
                            begin
                                @(posedge vif.arready);
                                if(vif.rresp != 2'b00)
                                    begin
                                        err++;
                                    end
                            end
                        @(posedge vif.rlast);
                        rdresp = vif.rresp;

                        compare();
                        $display("------------------------------------------------------");
                    end
            end
    endtask
endclass
///////////////////////////////////////////////////////////////////////////////////////////////
///6.AGENT
class agent extends uvm_agent;
    `uvm_component_utils(agent)

    function new(input string path = "agent", uvm_component parent = null);
        super.new(path, parent);
    endfunction
    
    uvm_sequencer#(transaction) seqr;
    driver d;
    mon m;
     
    //agent contains sequencer, driver and monitor
    //build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        seqr = uvm_sequencer#(transaction)::type_id::create("seqr", this);
        d = driver::type_id::create("d", this); //2 args  
        m = mon::type_id::create("m", this); //2 args 
    endfunction

    //connect_phase
    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        d.seq_item_port.connect(seqr.seq_item_export); //connect driver and seqr
    endfunction 

endclass
////////l///////////////////////////////////////////////////////////////////////////////////
///7.ENVIRONMENT
class env extends uvm_env;
    `uvm_component_utils(env)

    function new(input string path = "env", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    agent a;

    //build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        a = agent::type_id::create("a", this); 
    endfunction

endclass
/////////////////////////////////////////////////////////////////////////////////////////////
///8.TEST
class test extends uvm_test;
    `uvm_component_utils(test)

    function new(input string path = "test", uvm_component parent = null);
        super.new(path, parent);
    endfunction

    env e;
    //instances of different seqeunces
    valid_wrrd_fixed vwrrdfx;
    valid_wrrd_incr vwrrdincr;
    valid_wrrd_wrap vwrrdwrap;
    err_wrrd_fix errwrrdfix;
    rst_dut rdut;

    //build_phase
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        e = env::type_id::create("e", this);
        vwrrdfx = valid_wrrd_fixed::type_id::create("vwrrdfx"); //1 arg 
        vwrrdincr = valid_wrrd_incr::type_id::create("vwrrdincr"); //1 arg 
        vwrrdwrap = valid_wrrd_wrap::type_id::create("vwrrdwrap"); //1 arg 
        errwrrdfix = err_wrrd_fix::type_id::create("errwrrdfix");
        rdut = rst_dut::type_id::create("rdut");
    endfunction

    //run_phase
    virtual task run_phase(uvm_phase phase);
        phase.raise_objection(this); //to hold the simulator 
            //rdut.start(e.a.seqr); //start the sequencer 
            //#20;
            //vwrrdfx.start(e.a.seqr); 
            //#20;
            //vwrrdincr.start(e.a.seqr); //start the sequencer 
            //#20;
            //vwrrdwrap.start(e.a.seqr); //start the sequencer 
            //#20;
            errwrrdfix.start(e.a.seqr); //start the seqeuncer
            #20;
        phase.drop_objection(this);
    endtask

endclass
////////////////////////////////////////////////////////////////////////////////////////////
///9.TB_TOP
module tb;

    //interface instance 
    axi_if vif();

    //dut instance
    axi_slave dut(
        //global control signals 
        .clk(vif.clk),
        .resetn(vif.resetn),

        //write Address(AW)channel
        .awvalid(vif.awvalid), //M to S
        .awready(vif.awready), //S to Ml
        .awaddr(vif.awaddr), //M to S
        .awid(vif.awid), //M to S, unique ID for each transaction
        .awlen(vif.awlen), //M to S, burst length AXI3 : 1, 2, 4, 8, 16 beats,AXI4: 1 to 256, beats(burst length) = awlen + 1
        .awsize(vif.awsize), //M to S, unique transaction size of each beat : 2**awsize, awsize = 0, 1, 2 (generally 2**awsize = 1,2,4,8,16,....128)
        .awburst(vif.awburst), //M to S, burst type: fixed, INCR, WRAP

        //Write data(W) channel
        .wvalid(vif.wvalid), //M to S
        .wready(vif.wready), //S to M
        .wdata(vif.wdata), //M to S
        .wid(vif.wid), //M to S, unique id for transaction
        .wstrb(vif.wstrb), //M to S, for telling which lane(s) has/have valid data
        .wlast(vif.wlast), //M to S, last transfer in write burst

        //Write response(B) channel
        .bready(vif.bready), //M to S
        .bvalid(vif.bvalid), //S to M
        .bid(vif.bid), //S to M, unique id for transaction
        .bresp(vif.bresp), //S to M

        //Read Address (AR) channel
        .arvalid(vif.arvalid), //M to S
        .arready(vif.arready), //S to M
        .araddr(vif.araddr), //M to S
        .arid(vif.arid), //M to S
        .arlen(vif.arlen), //M to S
        .arsize(vif.arsize), //M to S
        .arburst(vif.arburst), //M to S, burst type: fixed, INCR, WRAP

        //Read Data (R) channel
        .rready(vif.rready), //M to S
        .rvalid(vif.rvalid), //S to M
        .rid(vif.rid), //S to M, read data id
        .rdata(vif.rdata), //S to M , read data from slave
        .rlast(vif.rlast), //S to M, read last data signal
        .rresp(vif.rresp) //S to M, read response signal
    );
    //connecting extra interface signals to get access to next address of DUT during write and read
    assign vif.next_addrwr = dut.nextaddr; //next address during write
    assign vif.next_addrrd = dut.rdnextaddr; //next address during read
    
    //initialize 
    initial 
        begin
            vif.clk <= 0;
        end

    //clk generation
    always #5 vif.clk <= ~vif.clk;

    //to give interface access and start test 
    initial 
        begin
            uvm_config_db#(virtual axi_if)::set(null, "*", "vif", vif);//giving access of intf handle to driver and monitor
            run_test("test"); 
        end
    //for waveform
    initial 
        begin
            $dumpfile("dump.vcd");
            $dumpvars;
        end    
            
endmodule