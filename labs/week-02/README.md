# Week 2 Lab — Networking, Packet Capture, and Man-in-the-Middle

**Lecture:** Intro to Networking, OSI Model, and MITM Attacks

---

## Overview

HuskyHub transmits all data over plain HTTP. This week you will use Wireshark to capture your own login traffic and see your credentials in cleartext. You will then perform an ARP spoofing attack against a lab partner to intercept their session cookie and impersonate them without knowing their password.

No remediation this week. The goal is to viscerally understand why encryption in transit matters before you implement it in Week 3.

---

## Tools

| Tool | Purpose |
|------|---------|
| Wireshark | Packet capture and traffic analysis |
| arpspoof (dsniff package) | ARP spoofing to position yourself as a MITM |
| Terminal | Execute commands |
| ip / ifconfig | Identify network interfaces and IP addresses |
| Browser Developer Tools | Manually set cookies |

**Installing dsniff:**
```bash
# Linux
sudo apt install dsniff

# macOS
brew install dsniff
```

---

## Steps

### 1. Identify Your Network Interface

```bash
ip addr      # Linux
ifconfig     # macOS
ipconfig     # Windows
```

Record your IP address and the name of the active interface (e.g., `eth0`, `en0`, `wlan0`).

---

### 2. Start a Wireshark Capture

Open Wireshark. Select your active network interface. Start capturing (the blue shark fin button) **before** you log in.

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

Pair with a lab partner. Designate one person as the **victim** (logged into HuskyHub on their machine) and one as the **attacker**. Both machines must be on the same local network.

Record the victim's IP address and the network gateway IP:
```bash
ip route    # Linux — look for "default via <gateway>"
netstat -rn # macOS
```

---

### 7. Enable IP Forwarding on the Attacker Machine

This ensures traffic continues to flow so the victim does not lose connectivity during the attack:

```bash
# Linux
sudo sysctl -w net.ipv4.ip_forward=1

# macOS
sudo sysctl -w net.inet.ip.forwarding=1
```

---

### 8. Execute the ARP Spoofing Attack

Open two terminals on the attacker machine and run both commands simultaneously:

```bash
# Terminal 1: Tell the victim that you are the gateway
sudo arpspoof -i <interface> -t <victim-ip> <gateway-ip>

# Terminal 2: Tell the gateway that you are the victim
sudo arpspoof -i <interface> -t <gateway-ip> <victim-ip>
```

---

### 9. Capture the Victim's Session Cookie

While both arpspoof processes are running, start a Wireshark capture on the attacker machine filtered to the victim's IP:
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
