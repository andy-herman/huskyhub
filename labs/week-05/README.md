# Week 5 Lab — Authentication: Sessions, Cookies, and Brute Force

**Lecture:** Sessions and Authentication

---

## Overview

HuskyHub has three deliberate authentication failures: the session token is not rotated after login (session fixation), the authentication cookies contain plaintext identity values and are trusted server-side without cryptographic validation (cookie forgery), and there is no account lockout mechanism (brute force). This week you exploit each, then remediate each. The midterm is Thursday — the lab is scoped so exploitation can be completed in the lab session and remediation taken home.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser Developer Tools | Inspect and manually modify cookies |
| Python requests library | Script a brute force login attempt |
| Flask sessions and itsdangerous | Implement cryptographically signed sessions |
| Terminal | Run scripts |

---

## Steps

### 1. Inspect the Authentication Cookies

Log in as `jsmith`. Open Developer Tools → **Application → Cookies**. Record the name, value, and flags for every cookie.

Answer: does any cookie contain a value that directly identifies the user, their role, or their database ID in a readable format?

---

### 2. Attempt Cookie Forgery

Manually edit the `role` cookie value from `student` to `admin` in Developer Tools. Reload the page. Navigate to `/admin/users`.

Document:
- Whether the application accepted the forged cookie
- What you can now access
- What server-side check, if any, was performed

---

### 3. Attempt Cookie Forgery — User Impersonation

Look up another user's `user_id` from the grades page (`/grades?student_id=X`). Change your `user_id` cookie to that value. Navigate to `/grades`. Document what you see.

---

### 4. Test for Session Fixation

Record your session-related cookie values **before** logging in (they may be set on the login page itself). Log in. Record the same cookie values **after** login.

Did the session token change? If the same token is valid both before and after authentication, the application is vulnerable to session fixation. Document what you find.

---

### 5. Script a Brute Force Attack

Write a Python script using the `requests` library that:
1. Reads a wordlist of passwords (use `labs/week-05/wordlist.txt`)
2. POSTs to `/login` for the username `tbrown` with each password in the list
3. Checks the response for a successful login redirect
4. Stops and prints the password when found

```python
import requests

TARGET = "http://localhost/login"
USERNAME = "tbrown"

with open("labs/week-05/wordlist.txt") as f:
    for line in f:
        password = line.strip()
        r = requests.post(TARGET, data={"username": USERNAME, "password": password},
                          allow_redirects=False)
        if r.status_code == 302:
            print(f"[+] Found: {password}")
            break
```

Record: how many requests per second, how many attempts before finding the password, whether any lockout triggers.

---

### 6. Remediation — Cryptographically Signed Sessions

Replace the plaintext cookies with Flask's signed session mechanism. In `__init__.py`, set a strong secret key:

```python
import secrets
app.secret_key = secrets.token_hex(32)
```

In `auth.py`, replace `response.set_cookie(...)` with `session[...]` assignments:

```python
from flask import session
session['authenticated'] = username
session['role'] = user['role']
session['user_id'] = user['user_id']
```

Update all routes that read from `request.cookies.get(...)` to read from `session.get(...)` instead. Rebuild and verify the session cookie is now opaque.

---

### 7. Remediation — Session Rotation on Login

Ensure a new session is generated immediately after successful authentication. Add this line in the login route immediately before writing to the session:

```python
session.clear()
```

Log the session token value before and after login and confirm they differ.

---

### 8. Remediation — Account Lockout

Add a `failed_attempts` and `lockout_until` column to the `users` table:

```sql
ALTER TABLE users
  ADD COLUMN failed_attempts INT NOT NULL DEFAULT 0,
  ADD COLUMN lockout_until DATETIME NULL;
```

In the login route, add logic that:
- Increments `failed_attempts` on each failed login
- Sets `lockout_until = NOW() + INTERVAL 15 MINUTE` after 5 failures
- Checks `lockout_until` before attempting authentication
- Returns a generic error message that does not distinguish between a wrong password and a locked account

---

### 9. Verify All Remediations

Repeat Steps 2–5 against the hardened application. For each:
- Document what happens now
- Confirm the attack no longer succeeds
- Paste the HTTP response or terminal output

---

## Write-Up Questions

**Q1.** Describe the session fixation attack in your own words. What precondition must an attacker satisfy before the victim logs in, and what does session rotation prevent?

**Q2.** Paste your brute force script with comments. How many requests per second did it achieve? Calculate: how long would it take to brute force a 6-character lowercase alphabetic password at this rate?

**Q3.** What is the difference between a signed cookie (Flask session) and an encrypted cookie? What does signing protect against, and what does it not protect against?

**Q4.** Your account lockout returns the same error message whether the password is wrong or the account is locked. Why? What attack does this generic message prevent?

**Q5.** Multi-factor authentication (MFA) would have made your brute force attack ineffective. At exactly what point in the authentication flow does MFA intervene? Why does MFA not eliminate the need for strong password policies and account lockout?

---

## Hacker Mindset Prompt

Authentication is the front door, and attackers are patient. A committed attacker does not brute-force a live application in real time — they obtain a credential database, crack it offline, and then attempt credential stuffing across dozens of services where users likely reused the same password.

Reflect on:

- **Contrarian:** The application trusts a cookie value to determine who the user is and what they are allowed to do. What is the fundamental flaw in this trust model, and how does signing correct it?
- **Committed:** Combine bcrypt from Week 3 with account lockout this week. Describe how these two controls create a layered defense. What does each one stop that the other does not?
- **Creative:** What is credential stuffing and why does it succeed even against applications that have never been breached themselves? What control would you add to HuskyHub to detect and block a credential stuffing campaign?
