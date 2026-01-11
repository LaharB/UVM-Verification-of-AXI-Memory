# UVM based Verification AXI Memory

This repository showcases the verification of AXI Lite Memory using UVM.The design code acts as the AXI slave and the testbench acts as the AXI master.We have not implemented IDs,Pipelining and Out of Order transactions in this design. 

<details><summary>Functional Specification & Implementation</summary>

## Introduction
The **Advanced eXtensible Interface(AXI)** is part of the ARM AMBA (Advanced Microcontroller Bus Architecture) family. It is a point-to-point interconnect protocol designed for high-performance, high-frequency system designs. 

This repository contains the RTL implementation (Verilog/SystemVerilog) and UVM-based verification environment for an AXI-based system.

## Key Architecture Features
* **Independent Channels:** 5 separate channels for address/control and data.
* **Burst-based Transactions:** Supports burst lengths up to 128 (AXI3) and 256 beats (AXI4).
* **Separate Phases:** Address and Data phases are decoupled, allowing for high-frequency operation and pipelining.
* **Out-of-Order Completion:** Uses ID tags to allow transactions to finish out of order, optimizing memory controller efficiency.

---

## 1. The 5-Channel Architecture
The AXI protocol defines five independent channels to enable simultaneous bidirectional data transfer.

### A. Write Address Channel (AW)
The master uses this channel to send the starting address and control signals for a write burst.
* **Key Signals:** `AWADDR`, `AWLEN` (Burst Length), `AWSIZE` (Burst Size), `AWBURST` (Type).
* **Handshake:** `AWVALID` (Master) & `AWREADY` (Slave).

### B. Write Data Channel (W)
The actual data payload is sent here. 
* **Key Signals:** `WDATA`, `WSTRB` (Write Strobe for byte-level masking), `WLAST` (Last beat indicator).
* **Handshake:** `WVALID` & `WREADY`.

### C. Write Response Channel (B)
Used by the slave to signal the completion of a write transaction.
* **Key Signals:** `BRESP` (Status: OKAY, EXOKAY, SLVERR, DECERR).
* **Handshake:** `BVALID` (Slave) & `BREADY` (Master).

### D. Read Address Channel (AR)
The master sends the starting address and control signals for a read burst.
* **Key Signals:** `ARADDR`, `ARLEN`, `ARSIZE`, `ARBURST`.
* **Handshake:** `ARVALID` & `ARREADY`.

### E. Read Data Channel (R)
The slave sends the requested data and the status of the read back to the master.
* **Key Signals:** `RDATA`, `RRESP`, `RLAST`.
* **Handshake:** `RVALID` & `RREADY`.

---

## 2. Handshake Mechanism (VALID/READY)
Every channel in AXI follows a strict **VALID/READY** handshake protocol. 
1.  The **Source** asserts `VALID` when it has valid data/control info.
2.  The **Destination** asserts `READY` when it can accept it.
3.  **Data Transfer:** Occurs only at the rising edge of `ACLK` when both `VALID` && `READY` are high.

### Handshake Dependencies
* A Master/Slave must not wait for `READY` before asserting `VALID`.
* A Master/Slave can wait for `VALID` before asserting `READY`.

---

## 3. Burst Types
AXI supports three main burst types, defined by the `AWBURST` or `ARBURST` signals:

1.  **FIXED:** The address remains the same for every beat (Used for FIFO peripherals).
2.  **INCR (Incrementing):** The address increments by the size of the transfer (Used for normal memory access).
3.  **WRAP:** Similar to INCR, but the address wraps around once it reaches a boundary (Used for Cache Line fills).

## AXI Channels 

![alt text](docs/AXI_Protocol_Channels.jpg)

---

## 4. Signal Summary Table

### AXI3 Slave Signal Summary

| Channel | Signal | Direction (Slave) | Width | Description |
| :--- | :--- | :--- | :--- | :--- |
| **Global** | `clk` | Input | 1 | Clock signal; all signals sampled on rising edge. |
| **Global** | `resetn` | Input | 1 | Global reset signal (Active Low). |
| **AW** | `awvalid` | Input | 1 | Master indicates valid write address/control. |
| **AW** | `awready` | **Output** | 1 | Slave indicates readiness to accept address. |
| **AW** | `awaddr` | Input | [31:0] | Write address of the first beat in a burst. |
| **AW** | `awid` | Input | [3:0] | Transaction ID tag for the write address group. |
| **AW** | `awlen` | Input | [3:0] | Burst length (number of beats = `awlen + 1`). |
| **AW** | `awsize` | Input | [2:0] | Size of each beat in bytes ($2^{awsize}$). |
| **AW** | `awburst` | Input | [1:0] | Burst type: FIXED(00), INCR(01), WRAP(10). |
| **W** | `wvalid` | Input | 1 | Master indicates valid write data is available. |
| **W** | `wready` | **Output** | 1 | Slave indicates readiness to accept write data. |
| **W** | `wdata` | Input | [31:0] | Write data bus. |
| **W** | `wid` | Input | [3:0] | Write ID tag (matches `awid` for the burst). |
| **W** | `wstrb` | Input | [3:0] | Byte strobes; indicates which byte lanes are valid. |
| **W** | `wlast` | Input | 1 | Indicates the final transfer in a write burst. |
| **B** | `bready` | Input | 1 | Master indicates it can accept a write response. |
| **B** | `bvalid` | **Output** | 1 | Slave indicates a valid write response is ready. |
| **B** | `bid` | **Output** | [3:0] | Response ID tag (matches `awid`). |
| **B** | `bresp` | **Output** | [1:0] | Write status: OKAY, EXOKAY, SLVERR, or DECERR. |
| **AR** | `arvalid` | Input | 1 | Master indicates valid read address/control. |
| **AR** | `arready` | **Output** | 1 | Slave indicates readiness to accept read address. |
| **AR** | `araddr` | Input | [31:0] | Read address of the first beat in a burst. |
| **AR** | `arid` | Input | [3:0] | Transaction ID tag for the read address group. |
| **AR** | `arlen` | Input | [3:0] | Burst length (number of beats = `arlen + 1`). |
| **AR** | `arsize` | Input | [2:0] | Size of each beat in bytes ($2^{arsize}$). |
| **AR** | `arburst` | Input | [1:0] | Burst type: FIXED(00), INCR(01), WRAP(10). |
| **R** | `rready` | Input | 1 | Master indicates it can accept read data/status. |
| **R** | `rvalid` | **Output** | 1 | Slave indicates valid read data is available. |
| **R** | `rid` | **Output** | [3:0] | Read ID tag (matches `arid`). |
| **R** | `rdata` | **Output** | [31:0] | Read data bus. |
| **R** | `rlast` | **Output** | 1 | Indicates the final transfer in a read burst. |
| **R** | `rresp` | **Output** | [1:0] | Read status: OKAY, EXOKAY, SLVERR, or DECERR. |

---

</details>

-----

<details><summary>RTL Design</summary>

```systemverilog

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
```
</details>

---

<details><summary>Testbench</summary>

```systemverilog
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
```
</details>

-----

<details><summary>Simulation</summary>

###  1.Reset the DUT

![alt text](<sim/1.rst_dut seq P1.png>)

![alt text](<sim/2.rst_dut seq P2.png>)

### 2.Write and Read in Fixed Mode

![alt text](<sim/3.wrrd_fx seq P1.png>)

![alt text](<sim/5.wrrd_fx seq P3.png>)

![alt text](<sim/4.wrrd_fx memory update P2.png>)

### 3.Write and Read in INCR mode

![alt text](<sim/6.wrrd_incr seq P1.png>)

![alt text](<sim/7.wrrd_incr seq P2.png>)

### 4.Write and Read in WRAP mode

![alt text](<sim/8.wrrd_wrap seq P1.png>)

![alt text](<sim/9.wrrd_wrap seq P2.png>)

</details>

----