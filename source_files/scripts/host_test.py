"""
----------------------------------------------------------------------------------
-- Script Name:     host_test.py
-- Author:          Imran
-- Last Modified:   13 November 2026
--
-- Description:     Host PC Simulator for the Space MRI Hardware Accelerator.
--                  Interfaces with the FPGA via UART (115200 8N2) to send
--                  8-byte command frames (Header + 6 Payload + 1 CRC-8-ATM)
--                  and receives the processed 8-byte frame back from the FPGA.
--                  Encodes target (x, y, z) coordinates into sfixed(3 downto -4),
--                  decodes the 6 returned joint angles in radians, and handles
--                  mathematical FCS validation and automated timeout recovery.
----------------------------------------------------------------------------------
"""

import serial
import time
import sys

# System Configurations
COM_PORT     = 'COM5'      
BAUD_RATE    = 115200
READ_TIMEOUT = 2           # Serial read timeout in seconds for link failure detection
POLY         = 0x07        # CRC-8-ATM polynomial (x^8 + x^2 + x + 1)

# Fixed-Point Format: sfixed(3 downto -4) -> 4 fractional bits, range [-8.0, 7.9375]
FRAC_BITS    = 4
SCALE_FACTOR = 1 << FRAC_BITS

# Shifted Command Opcodes (Upper 5 Bits)
CMD_ACC   = 0x08
CMD_HK    = 0x10
CMD_UNK   = 0xF8        # Unknown header for diagnostic testing

# Error Flag Masks (Lower 3 Bits)
FLAG_ERR_CMD  = 0x04
FLAG_ERR_CRC  = 0x02
FLAG_ERR_ACC  = 0x01


def float_to_sfixed8(val: float) -> int:
    """Converts a float to an 8-bit two's complement sfixed(3 downto -4) byte."""
    scaled = round(val * SCALE_FACTOR)
    # Clamp to signed 8-bit limits (-128 to +127 -> -8.0 to +7.9375)
    clamped = max(-128, min(127, scaled))
    return clamped & 0xFF


def sfixed8_to_float(byte_val: int) -> float:
    """Converts an 8-bit two's complement sfixed(3 downto -4) byte to a float."""
    signed_val = byte_val - 256 if byte_val >= 128 else byte_val
    return signed_val / float(SCALE_FACTOR)


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
        ser = serial.Serial(port, baud, stopbits=serial.STOPBITS_TWO, timeout=READ_TIMEOUT)
        print(f"Successfully opened {port} at {baud} 8N2.")
        return ser
    except serial.SerialException:
        print(f"Error: Could not open {port}. Check Device Manager / /dev/ttyUSB*.")
        sys.exit(1)


def send_sync_byte(ser: serial.Serial) -> None:
    """Transmits the 0x55 sync byte to calibrate the FPGA autobaud estimator."""
    print("[System] Transmitting 0x55 sync byte...")
    ser.write(b'\x55')
    time.sleep(0.1) # Wait for WAIT_BUS_IDLE (1.5 baud periods) phase
    ser.reset_input_buffer() 
    print("[System] FPGA calibrated and locked. Ready for transmission.")


def create_packet(header: int, coords: tuple[float, float, float] = (0.0, 0.0, 0.0), force_bad_crc: bool = False) -> bytes:
    """Encodes (x, y, z) into the upper 3 payload bytes, pads with zeros, and appends the CRC."""
    x_byte = float_to_sfixed8(coords[0])
    y_byte = float_to_sfixed8(coords[1])
    z_byte = float_to_sfixed8(coords[2])
    
    # Upper 24 bits: target_x, target_y, target_z | Lower 24 bits: zero padding
    payload = bytes([x_byte, y_byte, z_byte, 0x00, 0x00, 0x00])
    frame_no_crc = bytes([header]) + payload
    
    crc_byte = calculate_crc8(frame_no_crc)
    
    if force_bad_crc:
        crc_byte ^= 0xFF  # Flip all bits to force a CRC mismatch at the receiver
        
    return frame_no_crc + bytes([crc_byte])


def parse_header_flags(header_byte: int) -> None:
    """Decodes and prints any active error flags injected by the FPGA."""
    if (header_byte & 0x07) == 0:
        print("Header Status  : OK (No Flags)")
    else:
        print("Header Status  : HARDWARE ERROR DETECTED")
        if header_byte & FLAG_ERR_CMD:
            print("  -> [FLAG] Invalid Command Opcode Received")
        if header_byte & FLAG_ERR_CRC:
            print("  -> [FLAG] CRC Integrity Check Failed")
        if header_byte & FLAG_ERR_ACC:
            print("  -> [FLAG] Hardware Accelerator Fault")


def print_tx_summary(tx_packet: bytes, coords: tuple[float, float, float] | None = None) -> None:
    """Prints a structured breakdown of the outgoing frame prior to transmission."""
    print("\n--- [ TX FRAME ] ---")
    if coords is not None:
        quantised = tuple(sfixed8_to_float(float_to_sfixed8(c)) for c in coords)
        print(f"Quantised TX   : X={quantised[0]:+.4f} m, Y={quantised[1]:+.4f} m, Z={quantised[2]:+.4f} m")
        print(f"Coordinates    : X=0x{tx_packet[1]:02X}, Y=0x{tx_packet[2]:02X}, Z=0x{tx_packet[3]:02X}")
    print(f"Header         : 0x{tx_packet[0]:02X}")
    print(f"Payload        : 0x{tx_packet[1:7].hex().upper()}")
    print(f"TX CRC         : 0x{tx_packet[7]:02X}")
    print(f"Full TX Frame  : 0x{tx_packet.hex().upper()}")


def process_packet(ser: serial.Serial, tx_packet: bytes, coords: tuple[float, float, float] | None = None) -> bool:
    """Transmits the packet, processes the response, and returns True on success."""
    print_tx_summary(tx_packet, coords)
    ser.write(tx_packet)
    
    # Read the full 8-byte response (Header + 6 Result + 1 CRC)
    rx_packet = ser.read(8)
    
    if len(rx_packet) == 0:
        print("\nError: Read timeout. No response from FPGA.")
        return False
        
    elif len(rx_packet) == 8:
        rx_header       = rx_packet[0]
        result_bytes    = rx_packet[1:7]
        rx_crc_received = rx_packet[7]
        rx_data_no_crc  = rx_packet[:7]
        
        print("\n--- [ RX FRAME ] ---")
        print(f"Full RX Frame  : 0x{rx_packet.hex().upper()}")
        print(f"Header         : 0x{rx_header:02X}")
        print(f"Payload        : 0x{result_bytes.hex().upper()}")
        print(f"RX CRC         : 0x{rx_crc_received:02X}")
        
        # Validate the hardware's appended FCS against our mathematical expectation
        rx_crc_calculated = calculate_crc8(rx_data_no_crc)
        
        if rx_crc_received == rx_crc_calculated:
            print(f"CRC Check      : VALID (0x{rx_crc_received:02X})")
            parse_header_flags(rx_header)
            
            # Decode the 6 sfixed(3 downto -4) joint angles if no error flags are active
            if (rx_header & 0x07) == 0:
                joints = [sfixed8_to_float(b) for b in result_bytes]
                joint_str = ", ".join([f"J{i}: {val:+.4f} rad" for i, val in enumerate(joints)])
                print(f"Joint Angles   : {joint_str}\n")
            else:
                print("Joint Angles   : [ABORTED DUE TO HARDWARE ERROR]\n")
        else:
            print(f"CRC Check      : FAILED (Expected 0x{rx_crc_calculated:02X}, got 0x{rx_crc_received:02X})\n")
        return True
        
    else:
        print(f"\nError: FPGA did not return the expected 8 bytes. Actual: {len(rx_packet)}.")
        print("Check FPGA diagnostic LEDs for fatal link errors.\n")
        return True # Return true here so it doesn't trigger a sync retry on a partial packet


def execute_with_retry(ser: serial.Serial, tx_packet: bytes, coords: tuple[float, float, float] | None = None) -> None:
    """Attempts to process a packet, automatically recovering if a timeout occurs."""
    success = process_packet(ser, tx_packet, coords)
    if not success:
        print("\n[System] Link timeout. FPGA may have lost baud lock or restarted.")
        send_sync_byte(ser)
        print("\n[System] Retrying command transmission...")
        final_attempt = process_packet(ser, tx_packet, coords)
        if not final_attempt:
            print("\n[System] FATAL: Board is unresponsive. Check physical connections and power or if disabled via the switch.")


def main():
    print("--- Space MRI Host PC Simulator ---")
    ser = init_serial_port(COM_PORT, BAUD_RATE)
    
    print("[System] Ready. Awaiting user commands.")
    
    menu_prompt = (
        "\nOptions:\n"
        "  x y z   : Enter 3 target coordinates in metres (e.g. 1.25 -0.5 2.0)\n"
        "  !sync   : Force send sync byte (0x55)\n"
        f"  !err_h  : Send packet with an unknown header (0x{CMD_UNK:02X})\n"
        "  !err_c  : Send valid ACC packet but force a BAD CRC\n"
        "  q       : Quit\n"
        "> "
    )

    while True:
        user_input = input(menu_prompt).strip()
        
        if user_input.lower() == 'q':
            break
        elif user_input.lower() == '!sync':
            send_sync_byte(ser)
        elif user_input.lower() == '!err_h':
            print("\nSending invalid header to trigger FLAG_ERR_CMD bounceback...")
            tx_packet = create_packet(CMD_UNK)
            execute_with_retry(ser, tx_packet)
        elif user_input.lower() == '!err_c':
            print("\nSending valid ACC command with corrupted FCS to trigger FLAG_ERR_CRC bounceback...")
            tx_packet = create_packet(CMD_ACC, (1.0, 1.0, 1.0), force_bad_crc=True)
            execute_with_retry(ser, tx_packet, (1.0, 1.0, 1.0))
        elif user_input != "":
            parts = user_input.replace(',', ' ').split()
            if len(parts) == 3:
                try:
                    coords = (float(parts[0]), float(parts[1]), float(parts[2]))
                    tx_packet = create_packet(CMD_ACC, coords)
                    execute_with_retry(ser, tx_packet, coords)
                except ValueError:
                    print("Invalid input. Please enter 3 valid floating-point numbers (e.g. 0.5 -1.25 3.0).")
            else:
                print("Invalid format. Enter exactly 3 coordinates separated by spaces (e.g. 0.5 -1.25 3.0).")

    ser.close()
    print("Disconnected.")


if __name__ == "__main__":
    main()