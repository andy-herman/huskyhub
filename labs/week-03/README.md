# Week 3 Lab — Cryptography: Hashing Passwords and Enforcing HTTPS

**Lecture:** Introduction to Cryptography; Public Key Cryptography and PKI

---

## Overview

In Week 2 you captured credentials in cleartext and stole a session cookie over an unencrypted connection. This week you fix both of those problems. You will replace plaintext password storage with bcrypt hashing, configure HTTPS using a self-signed certificate, and verify each remediation by re-running the Week 2 attacks and documenting the difference in outcome.

---

## Tools

| Tool | Purpose |
|------|---------|
| bcrypt (Python library) | Hash and verify passwords |
| OpenSSL | Generate a self-signed TLS certificate |
| Wireshark | Verify HTTPS traffic is no longer readable |
| MySQL CLI | Inspect the database before and after hashing |
| nginx config files | Enable HTTPS on the web server |
| Docker Compose | Rebuild and redeploy |

### Platform Notes

**OpenSSL:**
- **macOS:** Pre-installed. Verify with `openssl version` in Terminal.
- **Linux:** Pre-installed on most distributions. Install with `sudo apt install openssl` if missing.
- **Windows:** OpenSSL is included with **Git for Windows**. Open Git Bash and verify with `openssl version`. If not present, download the installer from [slproweb.com/products/Win32OpenSSL.html](https://slproweb.com/products/Win32OpenSSL.html).

**MySQL CLI:**
- The MySQL client runs inside the Docker container — no local installation is needed. All MySQL commands in this lab use `docker exec` to connect to the container.

**Docker commands** work identically across all platforms in Terminal (macOS/Linux) or Git Bash / PowerShell (Windows).

---

## Steps

### 1. Observe Plaintext Passwords in the Database

**What `docker exec` does and why we use it here:**
`docker exec` runs a command inside an already-running container. The `-it` flags combine `-i` (keep stdin open) and `-t` (allocate a terminal), which together give you an interactive shell session inside the container. We use this because the MySQL server is running inside the Docker container's isolated network — there is no direct way to connect to it from your laptop without going through Docker. The command `mysql -u user -psupersecretpw huskyhub` connects to MySQL as the `user` account and immediately selects the `huskyhub` database.

Connect to the running MySQL container:

```bash
docker exec -it huskyhub-db mysql -u user -psupersecretpw huskyhub
```

Run:
```sql
SELECT username, password FROM users;
```

Screenshot the output. This is the before state.

---

### 2. Add bcrypt to the Application

**Why a dedicated password hashing library and not a general-purpose hash:**
General-purpose hash functions like SHA-256 or MD5 are designed to be fast — they can compute billions of hashes per second on commodity hardware. This is exactly wrong for passwords: a fast hash makes it trivial to try every word in a dictionary or every possible 8-character combination (a brute force attack) in hours. bcrypt is designed to be deliberately slow and to allow its cost factor to be increased as hardware gets faster. It also automatically generates a unique random salt for each password, which means two users with the same password will have completely different hash outputs — a precomputed table of hashes (a rainbow table) is therefore useless against a properly bcrypt-hashed database.

In `flask/requirements.txt`, add:
```
bcrypt==4.1.2
```

Rebuild to confirm it installs:
```bash
docker compose up --build
```

---

### 3. Write a Password Hashing Utility

**What each function call in this utility does:**
`plaintext.encode()` converts the Python string to bytes, because bcrypt operates on raw bytes rather than text strings. `bcrypt.gensalt()` generates a cryptographically random salt value — by default this encodes a cost factor of 12, meaning the hash computation iterates 2^12 = 4096 times. `bcrypt.hashpw(plaintext, salt)` runs the bcrypt algorithm and returns a single string that contains the salt, the cost factor, and the resulting hash all concatenated together. This is why bcrypt does not need a separate salt column in the database — the salt is embedded in the hash itself. `checkpw` performs the same computation on the plaintext and compares — it never stores or returns the plaintext.

Create a new file `flask/app/utils.py`:

```python
import bcrypt

def hash_password(plaintext: str) -> str:
    return bcrypt.hashpw(plaintext.encode(), bcrypt.gensalt()).decode()

def check_password(plaintext: str, hashed: str) -> bool:
    return bcrypt.checkpw(plaintext.encode(), hashed.encode())
```

---

### 4. Write a Migration Script

**What a migration script is and why you cannot simply re-hash in place:**
A migration script is a one-time program that transforms existing data from one format to another. You cannot simply overwrite passwords with their hashes in a single SQL UPDATE because you need to read each plaintext value, compute its hash, and write the result back — a row-by-row operation. After this script runs, the plaintext values no longer exist in the database. The script should be idempotent where possible (safe to run more than once), and after running it you should immediately verify the output before proceeding — a migration error that silently corrupts passwords would lock every user out of their account.

Create `flask/migrate_passwords.py`. This script should:
1. Connect to the database
2. Read every user record
3. Hash each plaintext password using your utility function
4. Update the record with the hash

Run it against the live database:
```bash
docker exec -it huskyhub-flask python migrate_passwords.py
```

Verify in MySQL that no plaintext passwords remain.

---

### 5. Update the Login Endpoint

**Why the SQL query must change — not just the comparison:**
Before this change, the login query looked something like `WHERE username = ? AND password = ?`. This passed the plaintext password directly to the database for comparison. After hashing, the database contains bcrypt strings like `$2b$12$...`, not plaintext. You cannot compare a plaintext password to a bcrypt hash in SQL — the comparison must happen in Python using `bcrypt.checkpw`. This means the new query retrieves the user *by username only*, then passes the retrieved hash and the submitted password to `check_password()`. Never pass a password hash back into a SQL query to compare it — always verify in application code.

In `flask/app/routes/auth.py`, modify the login query to retrieve the user by username only (no longer include the password in the SQL query), then use `check_password()` to verify the submitted password against the stored hash.

Test that existing accounts can still log in after the migration.

---

### 6. Update the Registration Endpoint

In `flask/app/routes/auth.py`, modify the registration route to call `hash_password()` before inserting the new user's password into the database.

Create a new test account and verify the stored value is a bcrypt hash — it should begin with `$2b$12$`.

---

### 7. Generate a Self-Signed TLS Certificate

**What each flag in the OpenSSL command does:**
`req -x509` generates a self-signed certificate (skipping the Certificate Signing Request step normally used when a CA is involved). `-newkey rsa:4096` creates a new RSA private key with a 4096-bit key length at the same time. `-keyout` and `-out` specify where to save the private key and certificate respectively. `-days 365` sets the certificate to expire in one year. `-nodes` (from "no DES") means the private key is saved without password encryption — necessary because nginx needs to read it automatically at startup without prompting. `-subj` provides the certificate's subject fields inline so OpenSSL does not prompt interactively; `CN=localhost` sets the Common Name, which browsers check against the hostname they are connecting to.

**macOS / Linux:**
```bash
openssl req -x509 -newkey rsa:4096 \
  -keyout nginx/key.pem \
  -out nginx/cert.pem \
  -days 365 -nodes \
  -subj "/C=US/ST=Washington/O=UW/CN=localhost"
```

**Windows (Git Bash):**
```bash
openssl req -x509 -newkey rsa:4096 \
  -keyout nginx/key.pem \
  -out nginx/cert.pem \
  -days 365 -nodes \
  -subj "//C=US\ST=Washington\O=UW\CN=localhost"
```

> **Windows note:** The subject string uses a double leading slash and backslashes in Git Bash due to path parsing differences. If you encounter errors, try running the command in WSL instead.

This generates a private key and a self-signed certificate in the `nginx/` directory.

---

### 8. Configure nginx for HTTPS

**What the nginx configuration changes accomplish at the network level:**
The first server block listens on port 80 (HTTP) and immediately issues an HTTP 301 redirect to the HTTPS version of the same URL. This means any client that connects over plain HTTP is immediately instructed to reconnect over HTTPS — the unencrypted connection never carries any application data. The second block listens on port 443 (HTTPS), loads the certificate and private key, and proxies requests to the Flask container. `ssl_certificate` contains the public certificate sent to clients; `ssl_certificate_key` contains the private key used to decrypt the session. The private key never leaves the server. `proxy_set_header X-Real-IP` passes the client's original IP address to Flask, which nginx would otherwise mask behind its own internal IP.

Update `nginx/default.conf` to add an SSL server block on port 443 and redirect port 80 traffic to it:

```nginx
server {
    listen 80;
    server_name localhost;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name localhost;

    ssl_certificate     /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key.pem;

    location / {
        proxy_pass http://huskyhub-flask:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

Update `docker-compose.yaml` to mount the certs and expose port 443:
```yaml
huskyhub-nginx:
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
    - ./nginx/cert.pem:/etc/nginx/certs/cert.pem
    - ./nginx/key.pem:/etc/nginx/certs/key.pem
```

Rebuild and navigate to `https://localhost`. Accept the browser certificate warning (this is expected for self-signed certificates — your browser has not been configured to trust a Certificate Authority that signed this certificate).

---

### 9. Re-run the Week 2 Wireshark Capture

**What TLS does to the packet contents Wireshark sees:**
TLS (Transport Layer Security) encrypts the entire HTTP payload between the client and the server using a symmetric key negotiated during the TLS handshake. Wireshark can still capture the packets, but it sees only the encrypted ciphertext — it cannot recover the HTTP headers, the POST body, or the session cookies from those packets without the server's private key. This is what "encryption in transit" means: the data is present on the wire, but it is computationally infeasible to read without the key.

With Wireshark capturing, log in over `https://localhost`. Apply the same POST filter from Week 2. Document what you see in the packet payload instead of plaintext credentials.

> **macOS note:** To capture `localhost` HTTPS traffic in Wireshark, select the **Loopback (lo0)** interface.

> **Windows note:** Select the **Npcap Loopback Adapter** interface.

---

### 10. Verify the Database Remediation

Run the same MySQL query from Step 1:
```sql
SELECT username, password FROM users;
```

Screenshot the output. All values should now be bcrypt hashes beginning with `$2b$12$`.

---

## Write-Up Questions

**Q1.** Explain the difference between encryption and hashing. Why is hashing the correct approach for password storage rather than symmetric encryption?

**Q2.** What is a salt in the context of bcrypt? Paste one hash from your database and identify which part of the string is the salt. Why does bcrypt embed the salt in the hash output rather than storing it separately?

**Q3.** Your certificate is self-signed. What is the difference between a self-signed certificate and one signed by a Certificate Authority? What specific attack does a CA signature protect against that your certificate does not?

---

## Hacker Mindset Prompt

Cryptography is frequently implemented incorrectly not because developers are ignorant of it, but because they make wrong assumptions about what it guarantees. MD5 and SHA-1 are cryptographic hash functions and yet they are completely inappropriate for password storage.

Reflect on:

- **Committed:** If an attacker obtained a database full of bcrypt hashes, describe the exact process they would use to attempt to crack them. What resources would they need?
- **Creative:** bcrypt was designed in 1999. What properties would you want in a password hashing algorithm designed today, and does bcrypt still meet them?
