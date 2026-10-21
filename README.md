# Space MRI - Hardware Acceleration Interface

## 1. SYSTEM DESCRIPTION
The Space_MRI repository contains the VHDL hardware design files and Python simulation software for a high-reliability hardware-in-the-loop (HIL) acceleration interface. Designed for the Space MRI project, the architecture features a robust UART transceiver pipeline (8N2 configuration), a dynamic autobaud estimator, and a strict Host Interface Controller. The system enforces an 8-byte fixed-length packet protocol with hardware-accelerated CRC-8-ATM validation, ensuring secure data routing to internal processing modules like the upcoming SORN-based Hardware Acceleration Unit.

## 2. COMPONENT OVERVIEW

### Hardware (VHDL)
*   **space_mri_pkg.vhd**
    Centralises global system constants including baud rate, frame sizing, CRC polynomials, and command codes to ensure dynamic, single-source-of-truth instantiation across all modules.
*   **autobaud_estimator.vhd**
    Measures the initial synchronisation byte (`0x55`) to calculate the operational baud period. Monitors for timeouts and framing errors to dynamically drop locks and self-heal the communication line.
*   **uart_rx.vhd & uart_rx_top.vhd**
    The 8N2 receiver subsystem. Utilises a bus-idle gatekeeper (waiting 1.5 baud periods) and the estimator's dynamic baud period to safely convert serial input into parallel payloads.
*   **host_interface.vhd**
    The main packet parser and controller. Enforces a strict 8-byte Big-Endian frame. It shifts data into a 48-bit payload register, verifies packet integrity via a 64-bit LFSR for CRC-8-ATM, decodes headers, triggers the hardware accelerator, and serialises the result for transmission.
*   **dummy_accelerator.vhd**
    A temporary placeholder processing unit implementing a +3 Caesar cipher on the 48-bit payload to verify FSM handshaking and data routing prior to SORN integration.
*   **uart_tx.vhd**
    The 8N2 transmitter module. Dynamically slices and transmits data using a strict 1 start bit, 8 data bits, and 2 stop bits protocol.
*   **space_mri_top.vhd**
    The top-level structural wrapper integrating the transceiver pipeline, host controller, and accelerator, mapping internal diagnostic flags to physical board LEDs.

### Software (Python)
*   **host_test.py**
    A pyserial-based hardware-in-the-loop simulator. Handles autobaud calibration (`0x55`), constructs mathematically perfect 8-byte command frames (calculating the CRC-8-ATM dynamically), and processes the FPGA's asynchronous returns.

## 3. TECHNICAL SPECIFICATIONS

| Parameter | Specification |
| :--- | :--- |
| **Target Hardware** | Digilent Basys 3 (xc7a35tcpg236-1) |
| **System Clock** | 100 MHz |
| **Data Protocol** | 115200 Baud, 8N2 (8 Data, No Parity, 2 Stop) |
| **Packet Format** | 8-Byte Fixed (1B Header, 6B Payload, 1B CRC) |
| **Byte Order** | Big-Endian (MSB First) |
| **CRC Algorithm** | CRC-8-ATM (Polynomial: `0x07` / `x^8 + x^2 + x + 1`) |
| **Synchronisation** | `0x55` or `0b01010101` (ASCII 'U') |
| **System Reset** | Active-low (Mapped to SW0: HIGH = Run, LOW = Reset) |

## 4. COMMAND PROTOCOL

All communications utilise a strict 8-byte frame. If a packet fails the CRC check or contains an unrecognised header, it is silently dropped by the hardware logic, and the respective error LED is triggered.

*   **`0xA5` (Accelerator Command):** Routes the 6-byte payload to the hardware accelerator. Returns the processed 6-byte payload.
*   **`0x5A` (Housekeeping Command):** Triggers internal system status routines (Payload bytes act as padding/dummy data).

## 5. DIRECTORY STRUCTURE

The repository is organised to separate synthesiseable logic, simulation environments, physical hardware constraints, and host software.

```text
Space_MRI/
└── source_files/
    ├── hdl/                  
    │   ├── space_mri_pkg.vhd
    │   ├── space_mri_top.vhd
    │   ├── host_interface.vhd
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
