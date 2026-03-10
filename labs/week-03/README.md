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

---

## Steps

### 1. Observe Plaintext Passwords in the Database

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

In `flask/app/routes/auth.py`, modify the login query to retrieve the user by username only (no longer include the password in the SQL query), then use `check_password()` to verify the submitted password against the stored hash.

Test that existing accounts can still log in after the migration.

---

### 6. Update the Registration Endpoint

In `flask/app/routes/auth.py`, modify the registration route to call `hash_password()` before inserting the new user's password into the database.

Create a new test account and verify the stored value is a bcrypt hash.

---

### 7. Generate a Self-Signed TLS Certificate

Run the following command in the `nginx/` directory:

```bash
openssl req -x509 -newkey rsa:4096 \
  -keyout nginx/key.pem \
  -out nginx/cert.pem \
  -days 365 -nodes \
  -subj "/C=US/ST=Washington/O=UW/CN=localhost"
```

This generates a private key and a self-signed certificate.

---

### 8. Configure nginx for HTTPS

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

Rebuild and navigate to `https://localhost`. Accept the browser certificate warning.

---

### 9. Re-run the Week 2 Wireshark Capture

With Wireshark capturing, log in over `https://localhost`. Apply the same POST filter from Week 2. Document what you see in the packet payload instead of plaintext credentials.

---

### 10. Verify the Database Remediation

Run the same MySQL query from Step 1:
```sql
SELECT username, password FROM users;
```

Screenshot the output. All values should now be bcrypt hashes.

---

## Write-Up Questions

**Q1.** Explain the difference between encryption and hashing. Why is hashing the correct approach for password storage rather than symmetric encryption?

**Q2.** What is a salt in the context of bcrypt? Paste one hash from your database and identify which part of the string is the salt. Why does bcrypt embed the salt in the hash output rather than storing it separately?

**Q3.** Paste the Wireshark capture output from re-running the Week 2 login over HTTPS. What does the payload look like now? What protocol layer handled the encryption?

**Q4.** Your certificate is self-signed. What is the difference between a self-signed certificate and one signed by a Certificate Authority? What specific attack does a CA signature protect against that your certificate does not?

**Q5.** In Week 2, ARP spoofing allowed an attacker to steal a session cookie, not just credentials. Does HTTPS fully protect against session cookie theft via MITM? If not, what additional remediation is required?

---

## Hacker Mindset Prompt

Cryptography is frequently implemented incorrectly not because developers are ignorant of it, but because they make wrong assumptions about what it guarantees. MD5 and SHA-1 are cryptographic hash functions and yet they are completely inappropriate for password storage.

Reflect on:

- **Contrarian:** Why is a fast hash function (like SHA-256) *worse* for passwords than a slow one (like bcrypt)? What attacker behavior does this speed difference enable?
- **Committed:** If an attacker obtained a database full of bcrypt hashes, describe the exact process they would use to attempt to crack them. What resources would they need?
- **Creative:** bcrypt was designed in 1999. What properties would you want in a password hashing algorithm designed today, and does bcrypt still meet them?
