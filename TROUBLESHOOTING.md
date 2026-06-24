# HuskyHub — Setup & Troubleshooting Guide

**Read this if you have never used a terminal, or if something in a lab "just isn't working."**

This guide is split into three parts:

1. **[Part 0 — First-Time Setup](#part-0--first-time-setup)** — terminal basics and installing the core tools (Docker, Git, Python). Do this once, before Week 1.
2. **[Part 1 — Universal Problems](#part-1--universal-problems)** — the issues that show up in almost every week (Docker not running, ports in use, etc.).
3. **[Part 2 — Per-Week Problems](#part-2--per-week-problems)** — tool-specific setup and gotchas for each week's lab.

Each problem is written as **Symptom → Why → Fix**. Use `Ctrl+F` (Windows) / `Cmd+F` (Mac) to search this page for the exact error message you see.

> **Golden rule:** copy commands one line at a time, and read the output before running the next line. Most "it broke" moments are a typo or running a command in the wrong folder. Slow is smooth, smooth is fast.

---

# Part 0 — First-Time Setup

## What is a terminal, and how do I open one?

A **terminal** (also called a "shell," "command line," or "command prompt") is a window where you type commands instead of clicking buttons. You will use it in every lab.

### Windows

You have several terminals. For this class, **use Git Bash** — it understands the same commands (`cp`, `ls`, `cat`) used in every lab example, so you won't have to translate.

- **Install Git Bash:** download **Git for Windows** from [git-scm.com/download/win](https://git-scm.com/download/win) and run the installer. Accept all the defaults. This installs Git **and** Git Bash **and** a copy of OpenSSL you'll need in Week 3.
- **Open Git Bash:** click Start, type `Git Bash`, press Enter. You can also right-click inside any folder in File Explorer and choose **"Git Bash Here"** to open a terminal already pointed at that folder.
- **PowerShell** is also installed by default (Start → type `PowerShell`). A few lab steps specifically say "PowerShell as Administrator" — for those, right-click PowerShell and choose **Run as administrator**. Otherwise prefer Git Bash.

> **Avoid the old "Command Prompt" (`cmd.exe`)** for this class — its commands are different from the examples.

### Mac

- **Open Terminal:** press `Cmd + Space` to open Spotlight, type `Terminal`, press Enter. (It also lives in Applications → Utilities → Terminal.)
- Mac's Terminal already understands `cp`, `ls`, `cat`, `git`, and `python3`, so no extra shell to install.
- **Apple Silicon vs Intel:** if your Mac is from 2020 or later it is probably "Apple Silicon" (M1/M2/M3/M4). Some installers ask which to download — click the Apple menu → **About This Mac** to check the "Chip"/"Processor" line if you're unsure.

## Survival commands (the only ones you must know to start)

| Goal | Mac / Git Bash | What it does |
|------|----------------|--------------|
| Where am I? | `pwd` | Prints the current folder ("print working directory") |
| What's here? | `ls` | Lists files in the current folder |
| Go into a folder | `cd huskyhub` | "Change directory" into `huskyhub` |
| Go back up one folder | `cd ..` | The `..` means "the folder above this one" |
| Go to your home folder | `cd ~` | `~` is shorthand for your home folder |
| Stop a running program | press `Ctrl + C` | Stops the thing currently running (e.g. the server) |
| Clear the screen | `clear` | Tidies up; doesn't delete anything |

**Tips that save hours:**
- **Tab completion:** type the first few letters of a file or folder and press `Tab` — the terminal finishes it for you. Fewer typos.
- **Paste:** Mac = `Cmd + V`. Git Bash = right-click (or `Shift + Insert`). PowerShell = right-click.
- **"command not found"** almost always means either a tool isn't installed, or you need to open a **new** terminal window after installing it.
- **Closing the terminal window stops whatever was running in it.** If you close the window running `docker compose up`, the app stops.

## Install the core tools

You need three things before Week 1: **Docker Desktop**, **Git**, and **Python**.

### Docker Desktop (runs the whole app)

Download from [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/). You do **not** need a Docker account.

- **Windows:** run the installer and keep **"Use WSL 2"** selected (the default). After installing, **restart your computer**. Then open Docker Desktop from the Start menu and wait for the whale icon to stop animating.
  - If the installer says virtualization is disabled, you may need to enable it in your computer's BIOS/UEFI (search your laptop model + "enable virtualization"). This is a one-time change.
- **Mac:** open the `.dmg`, drag **Docker** into **Applications**, then launch Docker from Applications. Choose the **Apple Silicon** or **Intel** download to match your Mac (see above).

**You must launch Docker Desktop and wait for it to fully start every time you work on a lab.** If the whale/engine indicator isn't green, Docker commands will fail.

### Git (downloads the labs)

- **Windows:** already installed if you installed Git Bash above.
- **Mac:** type `git --version` in Terminal. If Git isn't installed, macOS will pop up a window offering to install the "Command Line Developer Tools" — click **Install** and wait.

### Python (used from Week 2 onward)

- **Windows:** download from [python.org/downloads](https://www.python.org/downloads/). **On the first installer screen, check the box "Add python.exe to PATH"** before clicking Install. This one checkbox prevents the most common Windows error in this class. On Windows the command is usually `python` (and `pip`).
- **Mac:** `python3` is usually already there. Confirm with `python3 --version`. If missing, install from [python.org/downloads](https://www.python.org/downloads/). On Mac the commands are `python3` and `pip3`.

### Verify everything (run these in a fresh terminal)

```bash
docker --version
docker compose version
git --version
python --version     # Windows
python3 --version    # Mac
```

Each should print a version number. If any says "command not found," re-check that tool's install and **open a new terminal window** (PATH changes only apply to terminals opened *after* the install).

## Getting the code

```bash
git clone https://github.com/andy-herman/huskyhub.git
cd huskyhub
cp .env.example .env          # Mac / Git Bash
# Copy-Item .env.example .env  # Windows PowerShell
docker compose up --build
```

Then open **http://localhost** in your browser.

> **Windows: don't make `.env` in Notepad.** Notepad secretly adds a `.txt` ending, so you get `.env.txt`, which Docker ignores. Always create it with the `cp .env.example .env` command above, which makes the file with the correct name.

---

# Part 1 — Universal Problems

These apply to most weeks. Skim them once; come back when something breaks.

### "Cannot connect to the Docker daemon" / "error during connect" / "pipe ... not found"
**Why:** Docker Desktop isn't running. The terminal is trying to talk to an engine that's asleep.
**Fix:** Open Docker Desktop, wait until the whale icon is steady (not animating) and the dashboard says "Engine running," then re-run your command. On Windows the very first start after a reboot can take a minute or two.

### `docker compose` is "not found," but `docker` works
**Why:** an older Docker install uses the hyphenated command.
**Fix:** use `docker-compose` (with a hyphen) everywhere these labs say `docker compose`. Better: update Docker Desktop to a current version, which includes `docker compose`.

### Port 80 is already in use → nginx won't start
**Symptom:** an error mentioning `0.0.0.0:80`, "port is already allocated," or the page won't load.
**Why:** another program is holding the web port (80).
**Fix — find and stop it:**
- **Windows (PowerShell as Admin):** `Get-Process -Id (Get-NetTCPConnection -LocalPort 80).OwningProcess`. Common culprits: **IIS / "World Wide Web Publishing Service"** (stop it in Services), or Skype. Stop that program, then `docker compose up` again.
- **Mac:** `sudo lsof -i :80`. Note the process in the `COMMAND` column and quit it.
> Note: the often-repeated "macOS AirPlay uses port 80" is a myth — **AirPlay Receiver actually uses ports 5000 and 7000**, which HuskyHub does not publish. So on a Mac, a port-80 clash is usually a local web server you started earlier.

### Port 3306 is already in use → the database won't start
**Why:** you already have MySQL installed and running locally on the standard database port.
**Fix:** open your `.env` file and change `MYSQL_PORT=3306` to an unused port like `MYSQL_PORT=3307`, then `docker compose down` and `docker compose up --build` again. (The app talks to the database *inside* Docker, so this only changes the port exposed to your laptop.)

### The Flask container starts then immediately exits / keeps restarting
**Why (most common):** the database wasn't ready yet on the very first launch.
**Fix:** run `docker compose up` again (without `--build`); the database is initialized now. To see the real error: `docker compose logs huskyhub-flask`.

### `docker exec ... no such container: huskyhub-db` (or `huskyhub-flask`)
**Why:** the containers aren't running, or you're on an **old copy** of the repo from before container names were fixed.
**Fix:** confirm what's running and its exact names with **`docker compose ps`**. If the names look like `huskyhub-huskyhub-db-1`, you have an old checkout — `git pull` the latest. With the current repo the names are exactly `huskyhub-db`, `huskyhub-flask`, `huskyhub-nginx`, `huskyhub-ollama`.

### Git Bash: `the input device is not a TTY` when running `docker exec -it`
**Why:** Git Bash on Windows doesn't provide the interactive terminal that `-it` wants.
**Fix:** prefix the command with **`winpty`**, e.g. `winpty docker exec -it huskyhub-db mysql -u user -psupersecretpw huskyhub`. Or run that one command in **PowerShell** instead of Git Bash.

### The page won't load / I changed code but nothing changed
**Fix checklist:**
1. Did you **rebuild**? Code and dependency changes only take effect after `docker compose up --build`.
2. **Hard refresh** the browser: `Ctrl + Shift + R` (Windows) / `Cmd + Shift + R` (Mac) to bypass the cache.
3. Check the logs: `docker compose logs huskyhub-flask`.

### I think I broke the database (especially after Week 7 SQL injection)
**Fix — wipe and rebuild from the seed data:**
```bash
docker compose down -v        # deletes the database volume
docker compose up --build
```
Or the shortcut: `make reset`. **Warning:** `-v` permanently erases everything you created during labs. This is the intended way to recover from a broken state.

### Where do I create new files (like `utils.py`), and what should I edit them with?
**Fix:** install **Visual Studio Code** ([code.visualstudio.com](https://code.visualstudio.com/)), then `File → Open Folder → huskyhub`. Create and edit files there. Paths in the labs are relative to the `huskyhub` folder (e.g. `flask/app/utils.py` means: the `flask` folder, then `app`, then a file named `utils.py`).

### Windows line-ending warnings ("LF will be replaced by CRLF")
**Why:** Windows and Mac mark the end of a line differently; Git is just noting it.
**Fix:** ignore the warning — it does not break anything in this class.

### Everything was working yesterday, now nothing does
99% of the time: **Docker Desktop isn't running.** Open it, wait for green, try again.

---

# Part 2 — Per-Week Problems

> Each week assumes Docker Desktop is **running** and you are in the `huskyhub` folder (`cd huskyhub`). Many later labs build on earlier fixes, so keep **one working copy** and carry your changes forward (see the README's "Weekly Lab Branch Workflow").

## Week 1 — Reconnaissance

Mostly clicking around the browser; the main hurdle is getting Docker running (see Part 0 / Part 1).

- **Symptom: I can't log in with `jsmith` / `password123`.** → Check Caps Lock; type the password manually rather than copy-pasting (copied text sometimes includes a trailing space). The page is `http://localhost` (not `https`).
- **Symptom: the AI Advisor chat returns an error.** → **This is expected in Week 1.** The AI model isn't installed until the Week 9 pre-lab. Document the error and move on — that's part of the exercise.
- **Symptom: I can't find the cookies / headers in my browser.** → Open Developer Tools with `F12` (Windows) or `Cmd + Option + I` (Mac). Cookies live under **Application → Storage → Cookies** in Chrome/Edge, or **Storage → Cookies** in Firefox. Headers are under the **Network** tab (reload the page first, then click the top request).
- **Symptom: "View Page Source" looks different from the rendered page.** → That's the point. Use `Ctrl + U` (Windows) / `Cmd + Option + U` (Mac).

## Week 2 — Wireshark & ARP Spoofing

**Installing Wireshark**
- **Mac:** install from the `.dmg` at [wireshark.org/download](https://www.wireshark.org/download.html) (pick Apple Silicon or Intel). On first launch macOS may block packet capture — go to **System Settings → Privacy & Security**, allow Wireshark / the "ChmodBPF" helper, and **relaunch**.
- **Windows:** run the installer and **accept the Npcap install** when prompted — Wireshark and Scapy both need it. On the Npcap screen, **tick "Support loopback traffic"** so you can capture `localhost`.

**The #1 Week-2 gotcha — you see no packets in Steps 2–5**
- **Why:** HuskyHub runs on `localhost`, and `localhost` traffic travels over the **loopback** interface, *not* your Wi-Fi/Ethernet adapter.
- **Fix:** in Wireshark, select the loopback interface: **macOS** = `lo0`, **Windows** = `Npcap Loopback Adapter`. (Your real Wi-Fi interface is only used later, for the partner MITM capture.)

**Scapy / the ARP scripts**
- Install Scapy: `pip3 install scapy` (Mac) / `pip install scapy` (Windows).
- **Symptom: "Could not resolve MAC address for ..." when running `arpspoof.py`.** → The target hasn't appeared on the network yet. Have your partner load HuskyHub in their browser, run `arp -a` until you see their IP, then re-run the script.
- **Running the scripts — permissions:**
  - **Mac:** prefix with `sudo`, e.g. `sudo python3 labs/week-02/scripts/arpspoof.py en0 <victim> <gateway>`. It will ask for your Mac password.
  - **Windows:** there is **no `sudo`**. Open **PowerShell as Administrator** and run `python labs\week-02\scripts\arpspoof.py "Wi-Fi" <victim> <gateway>` (use `python`, not `python3`).
- **Symptom: "PermissionError" / "Operation not permitted."** → You forgot `sudo` (Mac) or didn't open PowerShell **as Administrator** (Windows).
- **Safety reminder:** only do the ARP portion (Steps 6–11) on an **isolated network** (personal phone hotspot or home router) — never on campus Wi-Fi.

## Week 3 — Password Hashing & HTTPS

- **Symptom: `docker exec ... huskyhub-db ...` errors or hangs in Git Bash.** → Use `winpty docker exec -it huskyhub-db mysql -u user -psupersecretpw huskyhub`, or run it in PowerShell. (Note: `-psupersecretpw` has **no space** after `-p` — that's how the MySQL client takes a password.)
- **Symptom: `python migrate_passwords.py` says "No such file or directory."** → The script you wrote on your laptop isn't inside the container until you copy it in. Follow the lab exactly: rebuild first, then `docker cp flask/migrate_passwords.py huskyhub-flask:/app/migrate_passwords.py`, then `docker exec`.
- **OpenSSL not found:**
  - **Windows:** use **Git Bash** (it ships with OpenSSL). The certificate command's odd-looking subject (`//C=US\ST=...`) is correct for Git Bash — the double slash is required there.
  - **Mac:** OpenSSL is preinstalled; verify with `openssl version`.
- **Symptom: browser shows "Your connection is not private" on `https://localhost`.** → **Expected** for a self-signed certificate. Click **Advanced → Proceed to localhost**. (In Chrome you can also click the page and type `thisisunsafe`.)
- **Symptom: nginx won't start after the HTTPS change.** → Usually a wrong certificate path or the cert files weren't generated. Check `docker compose logs huskyhub-nginx`, confirm `nginx/cert.pem` and `nginx/key.pem` exist, and that the compose file mounts them.

## Week 4 — Logging, Errors, and Dependency Audit

- **Symptom: `pip-audit: command not found`.** → Install it: `pip3 install pip-audit` (Mac) / `pip install pip-audit` (Windows), then **open a new terminal**. On Windows, if it's still not found, your Python "Scripts" folder isn't on PATH — try `python -m pip_audit -r flask/requirements.txt`. The command is `pip-audit` (with a hyphen), **not** `pip audit`.
- **Symptom: pip-audit hangs or errors fetching data.** → It needs internet to reach the vulnerability database; a campus/corporate proxy can block it. Try a different network or a phone hotspot.
- **Symptom: the "malformed URL" steps don't show an error page.** → Make sure you are **logged in** first (the grades route redirects you to the login page otherwise).
- **Symptom: the log file is empty or "No such file."** → The logging code must create the `/var/log/huskyhub/` directory (or you must mount it) before writing. Confirm the file path and that you rebuilt after editing.

## Week 5 — Sessions, Cookies, Brute Force

- **Symptom: `python brute.py` says it can't find the wordlist.** → Run it from the **repo root** (`huskyhub` folder), because the path `labs/week-05/wordlist.txt` is relative to there. Check with `pwd`.
- **Symptom: the script never finds the password / always prints nothing.** → Confirm the app is up at `http://localhost`, and that you're checking for an HTTP **302** redirect on success. `python` vs `python3`: use `python` on Windows, `python3` on Mac.
- **After remediation:** generate your secret key **once** and put it in `.env` as `FLASK_SECRET_KEY` — don't regenerate it on every start, or every restart logs everyone out. Remember to also add the new `failed_attempts` / `lockout_until` columns to `database/init.sql`, or a `docker compose down -v` reset will undo them.

## Week 6 — Authorization, IDOR, Burp Suite

- **Burp install:** download Community Edition from [portswigger.net/burp/communitydownload](https://portswigger.net/burp/communitydownload). Java is bundled — no separate install.
- **Easiest setup:** use Burp's **built-in browser** (Proxy → Intercept → **Open Browser**). It's pre-configured to go through Burp, so you skip all manual proxy settings.
- **#1 Burp gotcha: after the lab, normal browsing is broken.** → You left your system proxy pointed at Burp. Turn it off: **Windows** Settings → Network → Proxy → turn **Manual proxy setup** Off; **Mac** System Settings → Network → your connection → Details → Proxies → turn the web proxies off. (Using Burp's built-in browser avoids this entirely.)
- **Windows `curl` surprise:** in **PowerShell**, `curl` is a disguised alias for a different tool and won't behave like the examples. Use **Git Bash**, or call `curl.exe` explicitly.
- **Symptom: Intruder is extremely slow.** → Expected. Burp **Community** throttles Intruder on purpose; let it finish.

## Week 7 — SQL Injection & sqlmap

- **sqlmap install:** `pip3 install sqlmap` (Mac) / `pip install sqlmap` (Windows). If `sqlmap` isn't found on Windows, run it as `python -m sqlmap ...` or use Git Bash.
- **Symptom: my login-bypass payload doesn't work.** → Use the `#` comment versions from the lab (`admin'#`, `' OR '1'='1' #`). The older `--` style needs a trailing space that's easy to lose; `#` is reliable in MySQL.
- **Symptom: sqlmap immediately gets redirected / finds nothing.** → You need a valid session cookie. Use the `--cookie="authenticated=jsmith; role=student; user_id=3"` argument exactly as shown, and keep `--batch`.
- **PowerShell quoting:** if a sqlmap command misbehaves in PowerShell, run it in **Git Bash**, where the quoting matches the examples.
- **Made a mess of the data?** `docker compose down -v && docker compose up --build` to reset.

## Week 8 — XSS, OWASP ZAP, Automated Tests

- **ZAP install:** [zaproxy.org/download](https://www.zaproxy.org/download/). It needs Java, bundled with the installer.
  - **Mac:** if ZAP won't open ("unidentified developer"), **right-click the app → Open → Open**.
  - **Windows:** launch from the Start menu; accept the Java prompt if it appears.
- **Testing stored XSS needs two users at once.** → Don't log out and back in repeatedly. Open a **second browser** or a **private/incognito window** and log in as the other account there, so you can be `jsmith` in one and the recipient in the other.
- **Symptom: ZAP scan finds nothing / can't reach the site.** → Point the scan at `http://localhost` (or `https://localhost` if you completed Week 3's HTTPS). 
- **Symptom: pytest can't connect, or complains about certificates.** → If you're on HTTPS with a self-signed cert, the tests must pass `verify=False` (the lab shows this). Install test tools with `pip install pytest requests` and run `python -m pytest flask/tests/test_xss.py -v`.

## Week 9 — AI Security (Ollama)

- **Pre-lab is mandatory and slow — do it before class.** The model is ~2 GB:
  ```bash
  docker compose --profile ai up -d
  docker exec -it huskyhub-ollama ollama pull llama3.2
  docker compose restart huskyhub-flask
  ```
  (Git Bash: prefix the middle command with `winpty` if it hangs.)
- **Symptom: the pull fails or is very slow.** → It needs a stable internet connection and ~5 GB free disk. Check **Docker Desktop → Settings → Resources → disk usage**. Re-run the `ollama pull` command; it resumes.
- **Symptom: the chatbot says "Academic Advisor is currently unavailable."** → Ollama isn't ready. Confirm the model finished downloading, then restart Flask (`docker compose restart huskyhub-flask`). Diagnose with `docker logs huskyhub-ollama`.
- **Symptom: replies take forever or Docker freezes.** → The model needs memory. In **Docker Desktop → Settings → Resources**, give Docker more RAM (8 GB if you can), then restart Docker. Low-RAM laptops will be slow — be patient and keep prompts short.
- **Symptom: my prompt-injection attempt gets refused.** → AI responses vary run to run; reword and try again. That variability is itself part of the lesson — document what worked and what didn't.

---

## Still stuck?

1. Re-read the exact **Symptom** lines above and `Ctrl/Cmd + F` for your error text.
2. Capture the real error: `docker compose logs huskyhub-flask` (or `huskyhub-nginx`, `huskyhub-db`, `huskyhub-ollama`).
3. Bring that log output to the teaching team on Discord or the Live Lab Help Form — "it doesn't work" is hard to help with; the log message is easy.
