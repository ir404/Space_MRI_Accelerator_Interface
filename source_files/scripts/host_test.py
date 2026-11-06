"""
----------------------------------------------------------------------------------
-- Script Name:     host_test.py
-- Author:          Imran
-- Last Modified:   06 November 2026
--
-- Description:     Host PC Simulator for the Space MRI Hardware Accelerator.
--                  Interfaces with the FPGA via UART (115200 8N2) to send
--                  8-byte command frames (Header + 6 Payload + 1 CRC-8-ATM)
--                  and receives the processed 8-byte frame back from the FPGA.
--                  Includes mathematical FCS validation of the returned packet,
--                  sync byte calibration, and unknown header routing tests.
----------------------------------------------------------------------------------
"""

import serial
import time
import sys

# System Configurations
COM_PORT  = 'COM5'      
BAUD_RATE = 115200
CMD_ACC   = 0xA5
CMD_HK    = 0x5A
CMD_UNK   = 0xAA        # Unknown header for diagnostic testing
POLY      = 0x07        # CRC-8-ATM polynomial (x^8 + x^2 + x + 1)


def calculate_crc8(data: bytes) -> int:
    """Calculates the CRC-8-ATM checksum over the given byte array."""
    crc = 0x00
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 0x80:
                crc = ((crc << 1) ^ POLY) & 0xFF
            else:
                crc = (crc << 1) & 0xFF
    return crc


def init_serial_port(port: str, baud: int) -> serial.Serial:
    """Initialises and returns the serial port connection."""
    try:
        # stopbits=2 matches the UART_STOP_BITS package constant
        ser = serial.Serial(port, baud, stopbits=serial.STOPBITS_TWO, timeout=2)
        print(f"Successfully opened {port} at {baud} 8N2.")
        return ser
    except serial.SerialException:
        print(f"Error: Could not open {port}. Check Device Manager / /dev/ttyUSB*.")
        sys.exit(1)


def send_sync_byte(ser: serial.Serial) -> None:
    """Transmits the 0x55 sync byte to calibrate the FPGA autobaud estimator."""
    print("\n[System] Transmitting 0x55 sync byte...")
    ser.write(b'\x55')
    time.sleep(0.1) # Wait for WAIT_BUS_IDLE (1.5 baud periods) phase
    ser.reset_input_buffer() 
    print("[System] FPGA calibrated and locked. Ready for transmission.")


def create_packet(header: int, text: str) -> bytes:
    """Pads the text to 6 bytes, assembles the frame, and appends the CRC."""
    payload = text.encode('utf-8').ljust(6, b'\x00')[:6]
    frame_no_crc = bytes([header]) + payload
    crc_byte = calculate_crc8(frame_no_crc)
    return frame_no_crc + bytes([crc_byte])


def process_packet(ser: serial.Serial, tx_packet: bytes) -> None:
    """Transmits the packet to the FPGA and processes the 8-byte response."""
    print(f"TX Packet (Hex): {tx_packet.hex().upper()}")
    ser.write(tx_packet)
    
    # Read the full 8-byte response (Header + 6 Result + 1 CRC)
    rx_packet = ser.read(8)
    
    if len(rx_packet) == 8:
        print(f"\n--- Hardware Response ---")
        print(f"Full RX Frame  : {rx_packet.hex().upper()}")
        
        # Split the packet to perform validation
        rx_data_no_crc = rx_packet[:7]
        rx_crc_received = rx_packet[7]
        
        # Validate the hardware's appended FCS against our mathematical expectation
        rx_crc_calculated = calculate_crc8(rx_data_no_crc)
        
        if rx_crc_received == rx_crc_calculated:
            print(f"CRC Check      : VALID (0x{rx_crc_received:02X})")
            
            # Extract only the 6 payload result bytes
            result_bytes = rx_packet[1:7]
            print(f"Result Bytes   : {result_bytes.hex().upper()}")
            
            # Null padding (0x00) is shifted by the cipher to 0x03. Strip it for display.
            decoded_str = result_bytes.replace(b'\x03', b'').replace(b'\x00', b'').decode('utf-8', errors='ignore')
            print(f"Cipher Result  : {decoded_str}\n")
        else:
            print(f"CRC Check      : FAILED (Expected 0x{rx_crc_calculated:02X}, got 0x{rx_crc_received:02X})\n")
    else:
        print(f"Error: FPGA did not return the expected 8 bytes. Actual: {len(rx_packet)}.")
        print("Check FPGA diagnostic LEDs for frame, header, or CRC errors.\n")


def main():
    print("--- Space MRI Host PC Simulator ---")
    ser = init_serial_port(COM_PORT, BAUD_RATE)
    send_sync_byte(ser)
    
    menu_prompt = (
        "Options:\n"
        "  [text]  : Enter up to 6 characters to encode\n"
        "  !sync   : Send sync byte (use if FPGA SW0 was toggled)\n"
        "  !err    : Send packet with an unknown header (0xAA)\n"
        "  q       : Quit\n"
        "> "
    )

    while True:
        user_input = input(menu_prompt).strip()
        
        if user_input.lower() == 'q':
            break
        elif user_input.lower() == '!sync':
            send_sync_byte(ser)
        elif user_input.lower() == '!err':
            print("Sending invalid header to trigger LED13 (Header Error)...")
            tx_packet = create_packet(CMD_UNK, "TEST")
            process_packet(ser, tx_packet)
        elif user_input != "":
            tx_packet = create_packet(CMD_ACC, user_input)
            process_packet(ser, tx_packet)

    ser.close()
    print("Disconnected.")


if __name__ == "__main__":
    main()