# AXI4 Protocol: Functional Specification & Implementation

## Introduction
The **Advanced eXtensible Interface(AXI)** is part of the ARM AMBA (Advanced Microcontroller Bus Architecture) family. It is a point-to-point interconnect protocol designed for high-performance, high-frequency system designs. 

This repository contains the RTL implementation (Verilog/SystemVerilog) and UVM-based verification environment for an AXI4-based system.

## Key Architecture Features
* **Independent Channels:** 5 separate channels for address/control and data.
* **Burst-based Transactions:** Supports burst lengths up to 256 beats (AXI4).
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

---

## 4. Signal Summary Table (AXI4 Full)

| Signal Group | Signal Name | Source | Purpose |
| :--- | :--- | :--- | :--- |
| **Global** | `ACLK` | System | Clock Signal |
| **Global** | `ARESETn` | System | Reset (Active Low) |
| **Write Addr** | `AWADDR` | Master | Write Address |
| **Write Data** | `WDATA` | Master | Write Data |
| **Write Resp** | `BRESP` | Slave | Write Status |
| **Read Addr** | `ARADDR` | Master | Read Address |
| **Read Data** | `RDATA` | Slave | Read Data + Status |

---

