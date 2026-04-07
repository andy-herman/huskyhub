"""
INFO 310 - Week 2 Lab: ARP Cache Restoration
This script is provided for educational use within the INFO 310 lab environment only.
Run this after stopping arpspoof.py to immediately repair the ARP caches of both
the victim and the gateway rather than waiting for TTL expiry.
"""

#!/usr/bin/env python3
# Usage: sudo python3 arprestore.py <interface> <target-ip> <real-ip>
#
# Sends a burst of legitimate ARP replies to <target-ip> advertising the correct
# MAC address for <real-ip>. Run once for each spoofed direction:
#
#   sudo python3 arprestore.py <iface> <victim-ip> <gateway-ip>
#   sudo python3 arprestore.py <iface> <gateway-ip> <victim-ip>

import sys
from scapy.all import ARP, Ether, sendp, getmacbyip


def restore(iface: str, target_ip: str, real_ip: str, count: int = 6) -> None:
    target_mac = getmacbyip(target_ip)
    real_mac = getmacbyip(real_ip)

    if not target_mac:
        print(f"[!] Could not resolve MAC address for {target_ip}.")
        sys.exit(1)
    if not real_mac:
        print(f"[!] Could not resolve MAC address for {real_ip}.")
        sys.exit(1)

    pkt = Ether(dst=target_mac) / ARP(
        op=2,
        pdst=target_ip,
        hwdst=target_mac,
        psrc=real_ip,
        hwsrc=real_mac,  # correct MAC for real_ip
    )

    sendp(pkt, iface=iface, count=count, inter=0.2, verbose=False)
    print(f"[*] Restored: sent {count} ARP replies to {target_ip} with correct MAC for {real_ip}.")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("Usage: sudo python3 arprestore.py <interface> <target-ip> <real-ip>")
        print("Example: sudo python3 arprestore.py en0 192.168.1.50 192.168.1.1")
        sys.exit(1)
    restore(sys.argv[1], sys.argv[2], sys.argv[3])
