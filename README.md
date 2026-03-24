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

**macOS (Intel):**
```bash
brew install wireshark dsniff
```

**macOS (Apple Silicon — M1/M2/M3):**

`dsniff` does not always build cleanly on Apple Silicon via Homebrew. Use the following approach instead:

```bash
# Install Wireshark (use the native ARM .dmg from wireshark.org, not brew)
# Download from: https://www.wireshark.org/download.html
# Select "macOS Arm Disk Image"

# Install dsniff via Rosetta-enabled Homebrew as a fallback
arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
arch -x86_64 /usr/local/bin/brew install dsniff
```

If the Rosetta Homebrew approach is too cumbersome, use `scapy` as a drop-in replacement for `arpspoof` (see the **Apple Silicon Alternative** box in Step 8 below).

> If `brew` is not installed at all, run the one-liner at [brew.sh](https://brew.sh) first.

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

On macOS, look for the interface that has an `inet` address in the `192.168.x.x` or `10.x.x.x` range and shows `status: active`. This is your active interface.

**Apple Silicon (M1/M2/M3) — more reliable method:**
```bash
# Shows only the active interface name and IP in one line
route get default | grep interface
ipconfig getifaddr en0    # try en0 first
ipconfig getifaddr en1    # try en1 if en0 returns nothing
```

Common interface names on M2 Macs:
- `en0` — Wi-Fi (most common)
- `en1` — USB-C to Ethernet adapter or secondary Wi-Fi
- `bridge100` — appears when Personal Hotspot sharing is active on your Mac (not what you want — use the upstream interface instead)

If you are connected to a **phone hotspot** (your phone sharing its data to your Mac), the Mac side will show `en0` as the active interface receiving the hotspot connection.

**Windows (PowerShell):**
```powershell
ipconfig
```

**Windows (WSL):**
```bash
ip addr
```

Record your IP address and the name of the active interface.

---

### 2. Start a Wireshark Capture

**What Wireshark does and what "capturing on an interface" means:**
Wireshark is a packet analyzer. It places your network interface into "promiscuous mode," which instructs the network adapter to pass every packet it sees to the operating system rather than only packets addressed to your machine. Wireshark then records those packets — including the full contents of each one — to a capture buffer. Every HTTP request your browser sends and every response the server returns passes through your network interface as raw bytes. On an unencrypted HTTP connection, those bytes include plaintext headers, form data, cookies, and response bodies. The filter `http.request.method == "POST"` narrows the display to only packets containing an HTTP POST request — the type your browser sends when you submit a login form.

Open Wireshark. Select your active network interface. Start capturing (the blue shark fin button) **before** you log in.

> **macOS note:** If no interfaces appear, open System Preferences → Privacy & Security → and grant Wireshark permission to capture packets, then relaunch.

> **Windows note:** Select the interface named **Loopback: lo** or **Npcap Loopback Adapter** to capture localhost traffic.

---

### 3. Log In to HuskyHub

**What happens at the network layer when you submit a login form:**
When you click the login button, your browser encodes the form fields — username and password — as a URL-encoded body string in the format `username=jsmith&password=password123`. This string is placed in the body of an HTTP POST request and sent to the server. Because HuskyHub uses plain HTTP (not HTTPS), this entire request — headers, cookies, and body including the plaintext password — travels across the network as readable text. There is no encryption. Any device on the same network that is listening to the wire will see exactly what you typed.

With the capture running, navigate to `http://localhost:80/login` and submit your credentials. Stop the capture as soon as you are redirected to the home page.

---

### 4. Find Your Credentials in the Capture

**What the Wireshark filter expression matches and how packet layers work:**
`http.request.method == "POST"` is a display filter that tells Wireshark to show only packets where the HTTP layer identifies the request method as POST. Wireshark reassembles raw TCP segments into HTTP messages and then lets you filter on fields within those messages. When you expand the **HTML Form URL Encoded** section in the packet detail pane, you are looking at the decoded form body — Wireshark has already URL-decoded the `%40` and `+` characters back to readable text. What you see there is exactly what traveled over the network.

In the Wireshark filter bar, enter:
```
http.request.method == "POST"
```

Locate the login POST request. Click it and expand the **HTML Form URL Encoded** section in the packet detail pane. Record exactly what you see. Screenshot this.

---

### 5. Find Your Session Cookie

**What a session cookie is replacing and why stealing it is sufficient for impersonation:**
HTTP is a stateless protocol — the server has no memory of previous requests. To maintain the concept of a "logged in user," the server issues a token (the session cookie) after a successful login and tells the browser to send that token on every future request. When the server receives a request containing a valid session cookie, it treats the sender as the authenticated user associated with that token. The session cookie is therefore a reusable proof of authentication — it is equivalent to a physical key card. Anyone who possesses the cookie value can authenticate as that user, regardless of whether they know the password. This is why cookie theft is a serious post-authentication attack: bypassing the login entirely.

Change the Wireshark filter to:
```
http.cookie
```

Locate a request that contains your session cookie. Record the full cookie name and value. Note that this value alone is sufficient to impersonate your authenticated session.

---

### 6. Partner Setup (MITM Exercise)

> **Reminder:** Both machines must be on an isolated personal network — not school wifi. See the warning at the top of this lab.

Pair with a lab partner. Designate one person as the **victim** (logged into HuskyHub on their machine) and one as the **attacker**. Connect both machines to the same personal hotspot or home router.

You need three values before proceeding:
1. Your own IP address (attacker)
2. The victim's IP address
3. The gateway IP address

---

#### Step 6a. Find your own IP and the gateway

**macOS (all hardware including M1/M2/M3):**
```bash
# Your IP on the active interface
ipconfig getifaddr en0

# Gateway IP
netstat -rn | grep default | awk '{print $2}' | head -1
```

**Linux:**
```bash
ip addr show        # find your IP
ip route            # look for "default via <gateway>"
```

**Windows (PowerShell):**
```powershell
ipconfig
Get-NetRoute -DestinationPrefix "0.0.0.0/0"
```

> **iPhone hotspot note:** iPhones assign addresses in the `172.20.10.x` range, not `192.168.x.x`. Your IP will look like `172.20.10.2` through `172.20.10.14`, and the gateway will be `172.20.10.1`. Android hotspots typically use `192.168.43.x` with gateway `192.168.43.1`. If your IP looks unusual, this is why.

---

#### Step 6b. Find the victim's IP address

The most reliable method on all platforms — including Apple Silicon Macs — is to read the ARP cache after both machines have exchanged any network traffic (such as loading HuskyHub):

**macOS / Linux (attacker machine):**
```bash
arp -a
```

This lists every device the attacker machine has recently talked to on the local network. Look for an entry whose IP is in the same subnet as yours but is not your own IP and not the gateway. That is the victim.

**If the victim does not appear in `arp -a` yet:**
Have the victim load HuskyHub in their browser (`http://localhost:80`). Any network activity will populate the ARP cache. Run `arp -a` again on the attacker machine.

**Alternative — nmap ping sweep (use only if `arp -a` fails):**

First, determine your subnet. If your IP is `172.20.10.3`, your subnet is `172.20.10.0/28`. If your IP is `192.168.43.5`, your subnet is `192.168.43.0/24`.

```bash
# macOS / Linux
sudo nmap -sn <your-subnet>
# Example for iPhone hotspot:
sudo nmap -sn 172.20.10.0/28
# Example for Android hotspot or home router:
sudo nmap -sn 192.168.43.0/24
```

> **Why not `arp-scan` on Apple Silicon?** The `arp-scan` tool frequently fails to build or run correctly on M1/M2/M3 Macs via Homebrew and is not recommended for this lab. The `arp -a` approach above does not require any additional tools and is equally effective for this exercise.

---

Record all three values before continuing:
- Attacker IP: `_______________`
- Victim IP: `_______________`
- Gateway IP: `_______________`

---

### 7. Enable IP Forwarding on the Attacker Machine

**What IP forwarding does and why disabling it would break the attack:**
Normally, an operating system discards IP packets addressed to other machines — it is not a router, so forwarding them is not its job. When you run `arpspoof`, the victim's traffic starts arriving at *your* machine because you have told the network you are the gateway. If IP forwarding is disabled, your machine receives those packets and drops them — the victim loses internet connectivity, which is immediately noticeable and alerts them something is wrong. Enabling IP forwarding tells the kernel to forward those packets onward to the real gateway, so traffic continues flowing transparently. From the victim's perspective, everything appears normal. `sysctl` is the Linux/macOS tool for reading and writing kernel parameters at runtime; `net.inet.ip.forwarding=1` (macOS) and `net.ipv4.ip_forward=1` (Linux) are the specific parameters that control IP forwarding.

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

**What ARP is, what spoofing it accomplishes, and why two terminals are required:**
ARP (Address Resolution Protocol) is how devices on a local network discover each other's MAC addresses. When your laptop wants to send a packet to the gateway (e.g., `192.168.1.1`), it broadcasts an ARP request: "Who has IP 192.168.1.1? Tell me your MAC address." The gateway responds with its MAC, and your laptop caches that mapping. `arpspoof` exploits the fact that ARP has no authentication — any device can send an ARP reply claiming any IP-to-MAC mapping, and other devices will update their cache. By sending forged ARP replies to both the victim and the gateway, you insert your MAC into both their caches: the victim thinks you are the gateway (sends you their outbound traffic), and the gateway thinks you are the victim (sends you traffic destined for the victim). Two terminals are required because both spoofing directions must run simultaneously — stopping either one causes the respective device to correct its ARP cache.

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

**Why the session cookie is the target and what it grants the attacker:**
HTTP is a stateless protocol — the server has no built-in memory of who you are between requests. Session cookies solve this by storing a token that identifies your authenticated session. When the victim's browser sends any request to HuskyHub, it attaches this cookie automatically. Because you are now a man-in-the-middle receiving all their traffic, Wireshark can read the cookie value from the unencrypted HTTP stream. The Wireshark filter `ip.addr == <victim-ip> && http.cookie` narrows the capture to HTTP requests from the victim's IP that contain cookie headers. Once you have the cookie value, you do not need the victim's password — you can impersonate their authenticated session directly.

While both arpspoof processes are running, start a Wireshark capture on the **attacker machine** (using the native Wireshark application on macOS or Windows) filtered to the victim's IP:
```
ip.addr == <victim-ip> && http.cookie
```

Ask your partner to navigate to any page in HuskyHub. Locate their session cookie in the capture. Record the full value.

---

### 10. Impersonate the Victim

**Why manually setting a cookie is equivalent to stealing credentials:**
Cookies are stored by the browser and sent automatically on every request to the matching domain. The browser has no mechanism to verify that a cookie was legitimately issued by the server — it stores and transmits whatever value is present. When you open Developer Tools and manually change the `authenticated` cookie to match the victim's value, your browser will send that value on your next request to `localhost`. The server reads the cookie, recognizes it as a valid session token it previously issued, and responds as if it is talking to the victim. There is no second factor, no IP address check, no re-verification — the cookie alone is the authentication proof. This is the exact attack model that motivates the `HttpOnly` and `Secure` cookie flags you observed in Week 1: `HttpOnly` prevents JavaScript from reading the cookie (blocking XSS-based theft), and `Secure` prevents it from being sent over plain HTTP (blocking this exact interception).

In your browser, open Developer Tools → **Application → Cookies → localhost**.

Manually set the `authenticated` cookie to the value you captured. Set the `role` and `user_id` cookies to match what you observed.

Reload `http://localhost`. Document what you can now access.

---

### 11. Restore the Network

**What happens to ARP caches when the attack stops and why restoration matters:**
ARP cache entries have a time-to-live. When `arpspoof` stops sending its false replies, the victim and gateway will eventually receive legitimate ARP responses from the real owners of each IP address, and their caches will self-correct. However, "eventually" may take 60 seconds or more — the victim's traffic continues routing through your machine until the cache expires. Explicitly disabling IP forwarding after stopping `arpspoof` cuts off this residual forwarding immediately. This step is also an ethical obligation: you obtained consent from a lab partner on an isolated network, and cleanly restoring the network to its pre-attack state is part of responsible security research practice. Leaving a poisoned ARP cache and active IP forwarding running after the exercise introduces real latency and potential data exposure for your partner.

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
