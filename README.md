# SpaceMRI - Hardware Acceleration Interface

## 1. System Description
This repository contains the VHDL hardware design files and Python simulation software for a high-reliability hardware-in-the-loop (HIL) acceleration interface. Designed for the [SpaceMRI](https://www.haw-hamburg.de/forschung/forschungsprojekte-detail/project/project/show/spacemri/) project, the architecture features a robust UART transceiver pipeline (8N2 configuration), a dynamic autobaud estimator, and a strict Host Interface Controller. The system enforces an 8-byte fixed-length packet protocol with hardware-accelerated CRC-8-ATM validation, a structured telemetry header with diagnostic error flags, and an RX Watchdog to ensure secure, deadlock-free data routing to internal processing modules like the upcoming SORN-based Hardware Acceleration Unit.

## 2. Component Overview

### 2.1 Hardware (VHDL)
-   **space_mri_pkg.vhd**  
    Centralises global system constants including baud rate, frame sizing, watchdog timeouts, CRC polynomials, and structured command/error codes to ensure dynamic, single-source-of-truth instantiation across all modules.
-   **autobaud_estimator.vhd**  
    Measures the initial synchronisation byte (`0x55`) to calculate the operational baud period. Monitors for timeouts and framing errors to dynamically drop locks and self-heal the communication line.
-   **uart_rx.vhd & uart_rx_top.vhd**  
    The 8N2 receiver subsystem. Utilises a bus-idle gatekeeper (waiting 1.5 baud periods) and the estimator's dynamic baud period to safely convert serial input into parallel payloads.
-   **crc8_atm_core.vhd**  
    A standalone, reusable Galois LFSR IP core for CRC-8-ATM ($x^8 + x^2 + x + 1$). Computes remainder checksums on-the-fly without zero-padding, decoupling mathematical evaluation from the control path.
-   **host_interface.vhd**  
    The main packet parser and controller. Enforces a strict 8-byte Big-Endian frame and decodes the structured header (5-bit opcode, 3-bit error flag). Integrates a 5ms RX Watchdog to prevent FSM deadlocks during mid-packet link failures. Instantiates `crc8_atm_core` to verify incoming packet integrity, triggers the hardware accelerator, and calculates and appends a new 1-byte FCS to the outgoing payload.
-   **dummy_accelerator.vhd**  
    A temporary placeholder processing unit implementing a +3 Caesar cipher on the 48-bit payload to verify FSM handshaking and data routing prior to SORN integration.
-   **uart_tx.vhd**  
    The 8N2 transmitter module. Dynamically slices and transmits data using a strict 1 start bit, 8 data bits, and 2 stop bits protocol.
-   **space_mri_top.vhd**  
    The top-level structural wrapper integrating the transceiver pipeline, host controller, and accelerator, mapping internal diagnostic flags to physical board LEDs.

### 2.2 Software (Python)
-   **host_test.py**  
    A pyserial-based hardware-in-the-loop simulator. Handles dynamic autobaud calibration (`0x55`), constructs 8-byte command frames, receives the 8-byte response frame from the FPGA, and performs a local mathematical CRC check to validate bidirectional packet integrity. Features an automated timeout recovery mechanism to seamlessly handle link disconnections or loss of baud lock.

## 3. Technical Specifications

| Parameter | Specification |
| :--- | :--- |
| **Target Hardware** | Digilent Basys 3 (xc7a35tcpg236-1) |
| **System Clock** | 100 MHz |
| **Data Protocol** | 115200 Baud, 8N2 (8 Data, No Parity, 2 Stop) |
| **Packet Format** | 8-Byte Fixed (1B Header, 6B Payload, 1B CRC) |
| **Byte Order** | Big-Endian (MSB First) |
| **CRC Algorithm** | CRC-8-ATM (Polynomial: `0x07` / `x^8 + x^2 + x + 1`) |
| **Synchronisation** | `0x55` or `0b01010101` (ASCII 'U') |
| **RX Watchdog Timeout** | 5 ms (500,000 clock cycles at 100 MHz) |
| **System Reset** | Active-low (Mapped to SW0: HIGH = Run, LOW = Reset) |

## 4. Command Protocol & Error Handling

Communications utilise a strict 8-byte frame. The 1-byte header is structured into two fields: a 5-bit Command Opcode (Bits 7:3) and a 3-bit Error Flag mask (Bits 2:0). 

### 4.1 Command Opcodes (Host to FPGA)
The lower 3 bits must be `0` when sending a valid command from the host.
-   **`0x08` (Accelerator Command):** Routes the 6-byte payload to the hardware accelerator. Returns the processed 6-byte payload.
-   **`0x10` (Housekeeping Command):** Triggers internal system status routines.

### 4.2 Hardware Diagnostic Flags (FPGA to Host)
If a packet fails integrity checks or contains an unrecognised header, the FPGA aborts the operation, zeroes out the payload, injects a diagnostic error flag into the lower 3 bits of the echoed header, recalculates the CRC, and bounces the 8-byte error frame back to the host.
-   **Bit 2 (`0x04`):** Invalid Command Opcode Received
-   **Bit 1 (`0x02`):** CRC Integrity Check Failed
-   **Bit 0 (`0x01`):** UART RX Baud/Framing Error

## 5. Architectural Considerations

### 5.1 FSM Byte Misalignment & RX Watchdog
In asynchronous master-slave telemetry architectures, loss of framing (byte misalignment) can occur during system boot or EMI transients. If the FPGA autobaud estimator calculates its baud rate using a live data packet rather than a `0x55` sync byte, the UART receiver will miss the first several bytes of the transmission. 

Without protection, the `host_interface` FSM would capture the remaining bytes and hang indefinitely in the `GET_PACKET` state waiting for the rest of the frame, cannibalising subsequent retry packets and causing a total link deadlock. To prevent this, a hardware **RX Watchdog** enforces a 5ms inter-byte timeout. If the host line goes silent mid-packet (e.g., during a host read timeout), the Watchdog trips, flushes the FSM registers, and resets the interface to `IDLE`, guaranteeing a clean slate for the host's automated sync and retry recovery sequence.

## 6. Directory Structure

The repository is organised to separate synthesizable logic, simulation environments, physical hardware constraints, and host software.

```text
Space_MRI/
└── source_files/
    ├── hdl/                  
    │   ├── space_mri_pkg.vhd
    │   ├── space_mri_top.vhd
    │   ├── host_interface.vhd
    │   ├── crc8_atm_core.vhd
    │   ├── dummy_accelerator.vhd
    │   ├── autobaud_estimator.vhd
    │   ├── uart_rx_top.vhd
    │   ├── uart_rx.vhd
    │   ├── uart_tx.vhd
    │   └── uart_loopback_top.vhd
    ├── scripts/
    │   └── host_test.py                  
    ├── sim/                  
    │   └── tb_uart_rx_top.vhd
    └── xdc/                  
        ├── basys3_space_mri_top.xdc
        └── basys3_loopback.xdc