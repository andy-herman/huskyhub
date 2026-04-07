# Week 2a Lab — Session Management

**Lecture:** Authentication vs. Session Management
**Type:** Extra Credit (Two Parts)

---

## Why This Lab Exists

Week 2 was designed to show you what happens when a web application transmits data in cleartext. You captured credentials in Wireshark, intercepted a session cookie, and impersonated a user. The intended takeaway was that encryption in transit — HTTPS — is non-negotiable.

But something else surfaced during the lab that was not in the original plan. When you looked at the cookies Wireshark captured from your lab partner, you found this:

```
authenticated=admin; role=admin; user_id=1
```

No session token. No cryptographic signature. Just three plain text values that any user can set in their browser's Developer Tools without intercepting anyone's traffic at all. You do not need to be on the same network. You do not need Wireshark. You do not even need a lab partner. You can open HuskyHub right now, edit your own cookies, and become an admin.

That is a different class of vulnerability from what Week 2 was teaching. Encryption in transit — the fix coming in Week 3 — would prevent an attacker on the network from reading those cookie values. But it does nothing to stop a logged-in user from simply changing their own cookies. HTTPS encrypts the channel. It does not protect against a client that lies about who it is.

This is the distinction between **transport security** and **session integrity**. This lab addresses session integrity in two parts. In Part 1 you will implement signed sessions and then demonstrate that signing alone is not enough. In Part 2 you will complete the lockdown and verify that both attacks are fully remediated.

---

## Prerequisites

- Week 2 lab completed
- HuskyHub running locally on `http://localhost`
- No new packages required

---

---

# Part 1 — Implement Signed Sessions

## What You Are Doing and Why

Right now HuskyHub stores your identity in three plain cookies. You are going to move that identity into Flask's signed session object instead. This means:

- A user who tries to **edit** their own cookies will be logged out — the signature will not match
- A user who **steals** a valid session cookie via Wireshark and replays it will still get in

That second point is the lesson of Part 1. Signing cookies makes them tamper-proof. It does not make them secret. Without HTTPS, the signed cookie still travels over the network in plaintext and can be intercepted and replayed. Part 2 addresses the remaining issues.

---

## Steps

### 1. Strengthen the Secret Key

The `.env` file in your project root already has:

```
FLASK_SECRET_KEY=dev-secret-huskyhub-2024
```

This value is publicly known. Generate a strong replacement by running this in your terminal:

```bash
python3 -c "import secrets; print(secrets.token_hex(32))"
```

Open `.env` and replace the existing line:

**Before:**
```
FLASK_SECRET_KEY=dev-secret-huskyhub-2024
```

**After:**
```
FLASK_SECRET_KEY=<paste your generated key here>
```

Rebuild:

```bash
docker compose up --build
```

---

### 2. Update `routes/auth.py`

Open `flask/app/routes/auth.py`.

#### 2a. Update the imports

**Before:**
```python
from flask import (
    Blueprint, request, redirect, url_for,
    render_template, make_response
)
```

**After:**
```python
from flask import (
    Blueprint, request, redirect, url_for,
    render_template, session
)
```

---

#### 2b. Update the login route

Find lines 32–38:

**Before:**
```python
if user:
    resp = make_response(redirect(url_for("home")))
    # Store identity in cookies so the app knows who is logged in
    resp.set_cookie("authenticated", username)
    resp.set_cookie("role", user["role"])
    resp.set_cookie("user_id", str(user["user_id"]))
    return resp
```

**After:**
```python
if user:
    session["authenticated"] = username
    session["role"] = user["role"]
    session["user_id"] = str(user["user_id"])
    return redirect(url_for("home"))
```

---

#### 2c. Update the logout route

**Before:**
```python
@auth_bp.route("/logout")
def logout():
    resp = make_response(redirect(url_for("auth.login")))
    resp.delete_cookie("authenticated")
    resp.delete_cookie("role")
    resp.delete_cookie("user_id")
    return resp
```

**After:**
```python
@auth_bp.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("auth.login"))
```

---

### 3. Update `app/__init__.py`

Open `flask/app/__init__.py`.

#### 3a. Update the imports

**Before:**
```python
from flask import Flask, render_template, request, redirect, url_for
```

**After:**
```python
from flask import Flask, render_template, request, redirect, url_for, session
```

---

#### 3b. Update the home route

**Before:**
```python
@app.route("/")
def home():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))
    role = request.cookies.get("role", "student")
    return render_template("home.html", username=username, role=role)
```

**After:**
```python
@app.route("/")
def home():
    username = session.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))
    role = session.get("role", "student")
    return render_template("home.html", username=username, role=role)
```

---

### 4. Rebuild

```bash
docker compose up --build
```

Log in and open Firefox Developer Tools → **Storage → Cookies → http://localhost**.

You should now see a single cookie named `session` with a long encoded value instead of the three separate `authenticated`, `role`, and `user_id` cookies.

**Confirm that cookie editing no longer works:**

1. Double-click the `session` cookie value and change any single character
2. Reload the page
3. You should be redirected to the login page

---

## Checkpoint 1 — Proof of Concept

Before continuing to Part 2, you need to demonstrate two things.

**Proof A: Cookie editing is blocked**

Take a screenshot showing:
- You are logged in as `jsmith`
- You attempted to edit the `session` cookie value in Developer Tools
- The page redirected you to login

**Proof B: Cookie theft still works**

Using your lab partner and the scapy script from Week 2, capture the admin session cookie from your partner's traffic while they are logged in as `admin`. Replay it in your own browser by replacing your `session` cookie value with theirs.

Take a screenshot showing:
- You are in your own browser
- You are now logged in as `admin` and can see the admin navigation links (Users, Pending)
- You can access `/admin/users` and see the full user list

This is the key takeaway of Part 1: **signing the cookie made it tamper-proof but not secret**. The signed value can still be stolen and replayed because it travels over unencrypted HTTP. Without HTTPS, session signing alone is not a complete fix.

---

---

# Part 2 — Complete the Lockdown

## What You Are Doing and Why

Part 1 moved the login flow to signed sessions but left the rest of the application still reading from plain cookies. This means the remaining routes — grades, enrollment, messages, documents, admin, chatbot — still trust whatever values are in the old plain cookies. An attacker who intercepts traffic can still manipulate those values on routes that were not updated.

Part 2 completes the migration across the entire application and adds the `HttpOnly` flag to prevent JavaScript from reading the session cookie.

Note: the `Secure` flag, which prevents the cookie from being sent over plain HTTP, is not added here because the application does not yet have HTTPS. You will add it in Week 3 after HTTPS is configured.

---

## Steps

### 5. Update `routes/admin.py`

Open `flask/app/routes/admin.py`. This file has its own helper functions that read directly from cookies. If you skip this step the admin routes will remain bypassable.

#### 5a. Update the imports

**Before:**
```python
from flask import Blueprint, request, redirect, url_for, render_template
```

**After:**
```python
from flask import Blueprint, request, redirect, url_for, render_template, session
```

---

#### 5b. Update the helper functions

**Before:**
```python
def is_admin():
    return request.cookies.get("role") == "admin"

def is_advisor_or_admin():
    role = request.cookies.get("role", "student")
    return role in ("advisor", "admin")
```

**After:**
```python
def is_admin():
    return session.get("role") == "admin"

def is_advisor_or_admin():
    role = session.get("role", "student")
    return role in ("advisor", "admin")
```

---

### 6. Update All Remaining Route Files

Open each of the files below and make the same two changes in each.

- `flask/app/routes/grades.py`
- `flask/app/routes/enrollment.py`
- `flask/app/routes/messages.py`
- `flask/app/routes/documents.py`
- `flask/app/routes/chatbot.py`

**Change 1 — Add `session` to the import line in each file.**

Find the line that starts with `from flask import` and add `session` to it.

Example from `grades.py`:

**Before:**
```python
from flask import Blueprint, request, redirect, url_for, render_template
```

**After:**
```python
from flask import Blueprint, request, redirect, url_for, render_template, session
```

---

**Change 2 — Replace every cookie read with a session read.**

Use Find in Files (`Cmd+Shift+F` on macOS, `Ctrl+Shift+F` on Windows) to search for `request.cookies.get` across the whole project and make sure every result is updated.

| Find | Replace with |
|---|---|
| `request.cookies.get("authenticated")` | `session.get("authenticated")` |
| `request.cookies.get("role")` | `session.get("role")` |
| `request.cookies.get("role", "student")` | `session.get("role", "student")` |
| `request.cookies.get("user_id")` | `session.get("user_id")` |

Example from `grades.py`:

**Before:**
```python
username = request.cookies.get("authenticated")
if not username:
    return redirect(url_for("auth.login"))

student_id = request.args.get("student_id", request.cookies.get("user_id"))
```

**After:**
```python
username = session.get("authenticated")
if not username:
    return redirect(url_for("auth.login"))

student_id = request.args.get("student_id", session.get("user_id"))
```

---

### 7. Update `templates/base.html`

Open `flask/app/templates/base.html`. The navigation bar reads cookie values directly in the template and needs to be updated too.

Find this block in the navbar:

**Before:**
```html
{% if request.cookies.get('authenticated') %}
  <span class="nav-link text-light">
    Welcome, {{ request.cookies.get('authenticated') }}
    ({{ request.cookies.get('role', 'student') }})
  </span>
```

**After:**
```html
{% if session.get('authenticated') %}
  <span class="nav-link text-light">
    Welcome, {{ session.get('authenticated') }}
    ({{ session.get('role', 'student') }})
  </span>
```

Find the admin navigation check further down in the same file:

**Before:**
```html
{% if request.cookies.get('role') in ['admin'] %}
```

**After:**
```html
{% if session.get('role') in ['admin'] %}
```

---

### 8. Add the HttpOnly Flag

Open `flask/app/__init__.py`. Find the line where `app.secret_key` is set and add one line immediately after it:

**Before:**
```python
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-huskyhub-2024")

from .routes.auth import auth_bp
```

**After:**
```python
app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-huskyhub-2024")
app.config["SESSION_COOKIE_HTTPONLY"] = True

from .routes.auth import auth_bp
```

---

### 9. Rebuild and Verify

```bash
docker compose up --build
```

Log in as `jsmith` and confirm normal access works. Then confirm:

- Navigating to `/admin/users` redirects you away
- The session cookie in Developer Tools shows `HttpOnly: true`

---

## Checkpoint 2 — Proof of Concept

Take a screenshot showing each of the following.

**Proof A: Cookie theft no longer grants admin access**

Attempt to replay the admin session cookie from Checkpoint 1 into your browser. Take a screenshot showing that it no longer gives you admin access — you should be redirected to login or see a permission error. This works because the stolen cookie was issued before the migration and is no longer a valid session.

**Proof B: Cookie editing still fails**

Attempt to manually edit the `session` cookie value. Confirm you are still redirected to login.

**Proof C: HttpOnly is set**

Take a screenshot of the Developer Tools cookie panel showing the `session` cookie with `HttpOnly: true`.

**Proof D: Normal access still works**

Take a screenshot showing you are successfully logged in as `jsmith` and can access your grades.

---

## Extra Credit Submission

To get the full extra credit for this lab, you need to be able to attach all of your checkpoint screenshots appropriately labled and submitted with your lab report. 
