# Week 8 Lab — XSS, Bug Bounty, and Automated Testing

**Lecture:** XSS and Testing Web Services with SAST and DAST; Manual Testing and Hardening

---

> **New to the terminal, or stuck on setup?** See the **[Setup & Troubleshooting Guide](TROUBLESHOOTING.md)** for terminal basics and per-week Windows/Mac fixes.

## Overview

Stored XSS is present in two places: the messaging system renders message bodies with `| safe`, and advising notes do the same. This week you exploit both, run OWASP ZAP against the full application, and compare automated tool findings against everything you have found manually across all eight weeks. You will then remediate XSS through output encoding and implement a Content Security Policy.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser + Developer Tools | Exploit and observe XSS payloads |
| OWASP ZAP | Automated DAST scanning |
| pytest | Write automated regression tests for XSS |

**Download OWASP ZAP:** [zaproxy.org/download](https://www.zaproxy.org/download/)

ZAP is available for macOS, Windows, and Linux. Download the installer for your platform.

### Platform Notes

> **macOS note:** If ZAP does not open after installation, right-click the `.app` file → Open → confirm you want to open it (macOS Gatekeeper restriction on unsigned applications).

> **Windows note:** Launch ZAP from the Start menu or desktop shortcut. Accept the JRE prompt if it appears — ZAP requires Java, which the installer bundles.

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

### 3. Run OWASP ZAP Active Scan

**What the difference is between DAST and manual testing:**
Dynamic Application Security Testing (DAST) tools like ZAP interact with a running application from the outside — the same way an attacker would. ZAP sends a large library of known-bad inputs to every form and URL it discovers, then analyzes the responses for patterns that indicate vulnerabilities. It does not read your source code (that is SAST — Static Application Security Testing). ZAP's value is breadth: it can test hundreds of inputs per minute across every endpoint it finds, systematically. Its limitation is that it operates without understanding application logic — it cannot reason about multi-step flows, session context, or vulnerabilities that only appear under specific conditions. You will compare its findings to yours after the scan.

Open ZAP. In the **Quick Start** tab, set the URL to `http://localhost` and click **Automated Scan**. Let it complete fully.

Export the report: **Report → Generate Report → HTML**.

---

### 4. Compare ZAP Findings to Manual Findings

Create a table with three columns:

| Finding | Found by ZAP | Found Manually (which week) |
|---------|-------------|------------------------------|
| SQL Injection (grades search) | ... | ... |
| Stored XSS (messages) | ... | ... |
| ... | ... | ... |

For findings in only one column, explain why the other method missed it. This comparison is the point of the exercise — neither method alone is sufficient.

---

### 5. Bug Bounty Exercise

**What a bug bounty program is and how responsible disclosure works:**
A bug bounty program is a formal agreement where an organization offers payment or recognition to security researchers who discover and responsibly disclose vulnerabilities. "Responsible disclosure" means reporting the vulnerability privately to the organization and giving them time to fix it before publishing details publicly. The research you have been doing in this course — methodical, documented, proof-of-concept — is exactly the format a real bug report requires. Today you apply that process to HuskyHub with no specific assignment: find something that was not in the lab instructions.

Spend 20 minutes looking for any vulnerability not formally assigned in any prior week. This is deliberately open-ended. Document each finding with: endpoint, vulnerability type, proof-of-concept, and a severity rating with justification.

---

### 6. Remediation — Output Encoding

**What removing `| safe` accomplishes and why Jinja2's default is safe:**
Jinja2 was designed with auto-escaping enabled as the default for HTML templates. When `| safe` is removed, Jinja2's template renderer intercepts the variable value before writing it to the output stream and replaces `<` with `&lt;`, `>` with `&gt;`, `"` with `&quot;`, and `&` with `&amp;`. These are HTML entities — the browser renders them as the visible characters `< > " &` but does not interpret them as HTML syntax. A `<script>` tag stored in the database becomes `&lt;script&gt;` in the HTML — the browser displays it as text, not code. No JavaScript executes. The key insight is that this is output encoding happening at render time, not input sanitization happening at storage time — the raw payload can stay in the database without issue as long as it is never rendered as raw HTML.

In Jinja2, remove every instance of `| safe` from templates where user-supplied content is rendered. Specifically:

- `messages.html` — the `{{ m.body | safe }}` line
- `advising_notes.html` — the `{{ n.note_content | safe }}` line

Jinja2's auto-escaping will now encode `<script>` as `&lt;script&gt;` before rendering.

Rebuild and verify that Step 1's payload is rendered as escaped text rather than executed.

---

### 7. Implement a Content Security Policy

**What CSP does at the browser level and what `default-src 'self'` means:**
A Content Security Policy is an HTTP response header that tells the browser which sources it is allowed to load content from and execute scripts from. `default-src 'self'` establishes the baseline: all content must come from the same origin as the page. `script-src 'self'` specifically restricts JavaScript execution to scripts loaded from the same origin — inline scripts (those written directly in the HTML, including injected `<script>` tags) are blocked unless explicitly permitted. This means even if an attacker successfully injects a `<script>` tag into the page, the browser will refuse to execute it if CSP is present. CSP is a defense-in-depth layer: it does not fix the XSS vulnerability, but it limits the damage if the vulnerability exists or is reintroduced.

HuskyHub loads Bootstrap from `cdn.jsdelivr.net`, so the CSP must explicitly allow that external source for scripts and styles — otherwise the site will lose all styling. Add the following header in `nginx/default.conf` inside the HTTPS server block:

> **Builds on Week 3.** This goes in the HTTPS (port 443) `server` block you created in Week 3. If you have not enabled HTTPS yet, add the line to your port-80 `server` block instead.

```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self' https://cdn.jsdelivr.net; style-src 'self' https://cdn.jsdelivr.net" always;
```

Reload nginx:

```bash
docker exec huskyhub-nginx nginx -s reload
```

In Developer Tools → **Network**, click any request and verify the `Content-Security-Policy` header is present in the response headers.

Then confirm the policy actually blocks an injected script. Re-open the stored message from Step 1 (whose body is `<script>alert(document.cookie)</script>`). With CSP active, the browser refuses to run the inline script, and the **Console** tab shows a violation similar to:

```
Refused to execute inline script because it violates the following Content Security Policy directive: "script-src 'self' https://cdn.jsdelivr.net".
```

Before you added the CSP, that script executed and popped an alert; now it is blocked. That is the defense-in-depth payoff — the `| safe` XSS is still present in the markup, but the policy stops it from executing.

---

### 8. Write Automated XSS Regression Tests

**What regression tests are for and what these tests specifically assert:**
A regression test verifies that a bug that was fixed does not get reintroduced. Without automated tests, every code change requires a manual re-verification of every previously fixed vulnerability — which never happens in practice. These pytest tests automate that check: on every build, they send known XSS payloads to the vulnerable endpoints and assert that the raw `<script>` tag is not present in the response HTML. The assertion checks for the *escaped* form (`&lt;script&gt;`) rather than simply for absence of the tag, because a blank response or an error would also pass an absence check — you want to confirm the content is present and escaped, not just that it is absent for some other reason.

Create `flask/tests/test_xss.py` using pytest. The app runs on HTTPS with a self-signed certificate, so pass `verify=False` on all requests and suppress the resulting warning with `urllib3.disable_warnings()`:

```python
import pytest
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

BASE = "https://localhost"
PAYLOADS = [
    "<script>alert(1)</script>",
    "<img src=x onerror=alert(1)>",
    "javascript:alert(1)",
]

def login(username, password):
    s = requests.Session()
    s.post(f"{BASE}/login", data={"username": username, "password": password},
           verify=False, allow_redirects=True)
    return s

def test_message_body_not_executed():
    ...

def test_advising_note_not_executed():
    ...

def test_reflected_search_not_executed():
    ...
```

Write three test cases: one for message body XSS, one for advising notes XSS, and one for a URL-reflected parameter (e.g. the `/grades` `search` field — note this parameter is already auto-escaped because it is rendered without `| safe`, so this test confirms a non-vulnerable parameter stays safe rather than fixing a live bug). Each test must assert that the raw `<script>` tag is present as escaped HTML entities, not as an executable tag.

Run the tests:

**macOS / Linux:**
```bash
pip3 install pytest requests
python3 -m pytest flask/tests/test_xss.py -v
```

**Windows:**
```powershell
pip install pytest requests
python -m pytest flask/tests/test_xss.py -v
```

---

## Write-Up Questions

**Q1.** Explain the difference between stored XSS, reflected XSS, and DOM-based XSS. Which type did you exploit in Steps 1 and 2? Why is stored XSS considered more severe?

**Q2.** Explain how Content Security Policy prevents the execution of injected scripts. What is the limitation of CSP as the sole XSS defense?

**Q3.** Document your bug bounty findings. For your most interesting finding, write a formal vulnerability report including: title, severity (with CVSS score justification), affected component, description, steps to reproduce, impact, and recommended remediation.

---

## Hacker Mindset Prompt

XSS is often dismissed as a minor client-side issue. This is a serious underestimation. A committed attacker with arbitrary JavaScript execution in a victim's browser can steal sessions, log keystrokes, capture form submissions, pivot to the local network, and perform any action the victim can perform — silently.

Reflect on:

- **Contrarian:** The developer added `| safe` to the message template to "support rich formatting." What assumption did they make about who would be sending messages, and how did that assumption fail?
- **Committed:** The bug bounty model pays researchers to find vulnerabilities before attackers do. What distinguishes authorized security research from unauthorized access, legally and ethically?
- **Creative:** Even after removing `| safe` and adding a CSP, are there any remaining ways an attacker could abuse the messaging system? What would a defense-in-depth strategy look like beyond what you implemented?
