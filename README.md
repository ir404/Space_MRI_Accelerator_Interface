# SpaceMRI - Hardware Acceleration Interface

## 1. System Description
This repository contains the VHDL hardware design files and Python simulation software for a high-reliability hardware-in-the-loop (HIL) acceleration interface. Designed for the [SpaceMRI](https://www.haw-hamburg.de/forschung/forschungsprojekte-detail/project/project/show/spacemri/) project, the architecture features a robust UART transceiver pipeline (8N2 configuration), a dynamic autobaud estimator, and a strict Host Interface Controller. The system enforces an 8-byte fixed-length packet protocol with hardware-accelerated CRC-8-ATM validation, a structured telemetry header with diagnostic error flags, and an RX Watchdog to ensure secure, deadlock-free routing of fixed-point spatial coordinates (`sfixed(3 downto -4)`) to the SORN-based Hardware Acceleration Unit.

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
    The main packet parser and controller. Enforces a strict 8-byte Big-Endian frame and decodes the structured header (5-bit opcode, 3-bit error flag). Integrates a 5 ms RX Watchdog to prevent FSM deadlocks during mid-packet link failures. Instantiates `crc8_atm_core` to verify incoming packet integrity, triggers the hardware accelerator, monitors accelerator fault flags, and calculates and appends a new 1-byte FCS to the outgoing payload.
-   **sorn_accelerator/ (`accelerator_pkg.vhd` & `accelerator.vhd`)**  
    External SORN inverse kinematics accelerator IP operating on 8-bit `sfixed(3 downto -4)` fixed-point types (requires VHDL-2008 compilation).
-   **dummy_accelerator.vhd & space_mri_dummy_top.vhd**  
    Legacy baseline modules implementing a +3 Caesar cipher on the 48-bit payload, retained for isolated UART and FSM regression testing.
-   **uart_tx.vhd**  
    The 8N2 transmitter module. Dynamically slices and transmits data using a strict 1 start bit, 8 data bits, and 2 stop bits protocol.
-   **space_mri_top.vhd**  
    The top-level structural wrapper (compiled with VHDL-2008) integrating the transceiver pipeline, host controller, and SORN accelerator. Dynamically slices incoming payload bytes into `sfixed(3 downto -4)` target coordinates, packs the six computed joint angles into the response frame, translates reset/error signals, and maps diagnostic flags to physical board LEDs.

### 2.2 Software (Python)
-   **host_test.py**  
    A `pyserial`-based hardware-in-the-loop simulator. Handles dynamic autobaud calibration (`0x55`), quantises and clamps input $(X, Y, Z)$ target coordinates (in metres) into 8-bit `sfixed(3 downto -4)` bytes, constructs 8-byte command frames, decodes the six returned joint angles (in radians), and performs local CRC-8-ATM verification with automated timeout recovery.

## 3. Technical Specifications

| Parameter | Specification |
| :--- | :--- |
| **Target Hardware** | Digilent Basys 3 (`xc7a35tcpg236-1`) |
| **System Clock** | 100 MHz |
| **HDL Standard** | VHDL-93 (Interface/UART) & VHDL-2008 (`space_mri_top` & SORN IP) |
| **Data Protocol** | 115200 Baud, 8N2 (8 Data, No Parity, 2 Stop) |
| **Packet Format** | 8-Byte Fixed (Byte 0: Header, Bytes 1–6: Payload, Byte 7: CRC) |
| **Byte Order** | Big-Endian (MSB First) |
| **Fixed-Point Format** | 8-bit Signed `sfixed(3 downto -4)` (1 Sign, 3 Integer, 4 Fractional) |
| **Supported Range & Step** | `[-8.0, +7.9375]` (Step size / 1 LSB = `0.0625` / $2^{-4}$) |
| **TX Payload Mapping** | Payload Bytes 0–2: Target $X, Y, Z$ (m) \| Payload Bytes 3–5: `0x00` Padding |
| **RX Payload Mapping** | Payload Bytes 0–5: Computed Joint Angles $J_0 \dots J_5$ (rad) |
| **CRC Algorithm** | CRC-8-ATM (Polynomial: `0x07` / $x^8 + x^2 + x + 1$) |
| **Synchronisation** | `0x55` or `0b01010101` (ASCII `'U'`) |
| **RX Watchdog Timeout** | 5 ms (500,000 clock cycles at 100 MHz) |
| **System Reset** | Active-low (Mapped to SW0: HIGH = Run, LOW = Reset) |

## 4. Command Protocol & Error Handling

Communications utilise a strict 8-byte frame. The 1-byte header is structured into two fields: a 5-bit Command Opcode (Bits 7:3) and a 3-bit Error Flag mask (Bits 2:0). 

### 4.1 Command Opcodes (Host to FPGA)
The lower 3 bits must be `0` when sending a valid command from the host.
-   **`0x08` (Accelerator Command):** Routes the quantised $(X, Y, Z)$ target coordinates in the upper 3 payload bytes to the SORN accelerator and returns the 6 computed joint angles.
-   **`0x10` (Housekeeping Command):** Triggers internal system status routines.

### 4.2 Hardware Diagnostic Flags (FPGA to Host)
If a packet fails integrity checks, contains an unrecognised header, or triggers an accelerator fault, the FPGA aborts the operation, zeroes out the payload, injects a diagnostic error flag into the lower 3 bits of the echoed header, recalculates the CRC, and bounces the 8-byte error frame back to the host.
-   **Bit 2 (`0x04`):** Invalid Command Opcode Received
-   **Bit 1 (`0x02`):** CRC Integrity Check Failed
-   **Bit 0 (`0x01`):** Hardware Accelerator Fault

## 5. Architectural Considerations

### 5.1 FSM Byte Misalignment & RX Watchdog
In asynchronous master-slave telemetry architectures, loss of framing (byte misalignment) can occur during system boot or EMI transients. If the FPGA autobaud estimator calculates its baud rate using a live data packet rather than a `0x55` sync byte, the UART receiver will miss the first several bytes of the transmission. 

Without protection, the `host_interface` FSM would capture the remaining bytes and hang indefinitely in the `GET_PACKET` state waiting for the rest of the frame, cannibalising subsequent retry packets and causing a total link deadlock. To prevent this, a hardware **RX Watchdog** enforces a 5 ms inter-byte timeout. If the host line goes silent mid-packet (e.g., during a host read timeout), the Watchdog trips, flushes the FSM registers, and resets the interface to `IDLE`, guaranteeing a clean slate for the host's automated sync and retry recovery sequence.

### 5.2 Host-Side Quantisation Contract
To minimise UART bandwidth overhead and eliminate floating-point conversion logic on the FPGA, the Data Processing Unit (DPU) or host simulator performs fixed-point quantisation prior to transmission. Continuous floating-point coordinates (in metres) are scaled by $2^4 = 16$, rounded to the nearest integer, and saturated to the signed 8-bit bounds (`-128` to `+127`, corresponding to `-8.0 m` to `+7.9375 m`) before packing into the Big-Endian payload.

## 6. Directory Structure

The repository is organised to separate synthesizable logic, external accelerator IP, simulation environments, physical hardware constraints, and host software.

```text
Space_MRI/
└── source_files/
    ├── hdl/                  
    │   ├── sorn_accelerator/
    │   │   ├── accelerator_pkg.vhd
    │   │   └── accelerator.vhd
    │   ├── space_mri_pkg.vhd
    │   ├── space_mri_top.vhd
    │   ├── host_interface.vhd
    │   ├── crc8_atm_core.vhd
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
```

 ## 7. Acknowledgements & Attributions

Developed with assistance from **Google Gemini** for VHDL implementation, scripting and documentation. 