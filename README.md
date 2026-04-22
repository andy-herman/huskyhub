# Week 4 Lab — Logging, Error Handling, and Third-Party Risk

**Lecture:** Application Layer, HTTP, Architecture, and Logging; Application Frontend, Backend, and 3rd Parties

---

## Overview

This week you address two problems: verbose error messages that hand attackers a map of the application's internals, and the complete absence of security-relevant logging. You will trigger error conditions deliberately, document what leaks, harden error responses, implement structured logging, and audit the application's dependencies for known CVEs.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser | Trigger error conditions and observe responses |
| Browser Developer Tools | Inspect error response bodies and headers |
| Python logging module | Implement structured logging |
| pip-audit | Scan dependencies for known CVEs |
| Terminal | Read log output |

### Installing pip-audit by Platform

**macOS / Linux:**
```bash
pip3 install pip-audit
```

**Windows (PowerShell or Git Bash):**
```powershell
pip install pip-audit
```

> If `pip` is not found, install Python from [python.org/downloads](https://www.python.org/downloads/) and ensure **Add Python to PATH** is checked during installation. Then reopen your terminal.

> **macOS note:** If you get a permissions error, use `pip3 install --user pip-audit` or install via `brew install pip-audit`.

---

## Steps

### 1. Trigger Verbose Errors

**Why Flask shows verbose errors by default — and what they expose:**
In development mode, Flask catches unhandled exceptions and returns an HTML page containing the full Python stack trace, the source file paths, the exact line of code that failed, and the values of local variables at the time of the error. This is extremely useful for a developer debugging on their own machine. It is equally useful for an attacker: a stack trace reveals the server's directory structure, the framework version, the names of database tables referenced in the failing query, and sometimes the contents of SQL queries — all without having to find a single vulnerability in the application logic itself. The URLs below intentionally trigger these conditions.

With the application running, navigate to each of the following malformed URLs and record the full response body for each:

```
http://localhost/grades?student_id='
http://localhost/grades?student_id=1 UNION SELECT 1,2,3--
http://localhost/nonexistent-page
http://localhost/documents/download?file=/etc/passwd
```

For the first response, document:
- The HTTP status code
- Every internal detail exposed (stack traces, file paths, library versions, database errors, SQL queries)
- Ensure that you still take a note of the other 3 pages, you will review them again later.
---

### 2. Analyze What an Attacker Learns

For the first error response, write a structured analysis: what was revealed, and how would an attacker use that specific piece of information in a subsequent attack? Be specific — "file paths were revealed" is not sufficient; "the path `/app/routes/grades.py` was revealed, telling the attacker the Flask routes are organized in an `app/routes/` directory which matches standard Flask project structure" is.

---

### 3. Implement a Global Error Handler

**What a global error handler does and what "least information" means:**
Flask's `@app.errorhandler` decorator registers a function to be called whenever an exception of a given type propagates to the application level unhandled. By registering a handler for the base `Exception` class, you catch everything. The key principle here is *least information*: return only what the client needs to know (that an error occurred), and log everything else server-side where only authorized personnel can read it. `exc_info=True` in the log call tells the Python logging system to capture and include the full stack trace in the log entry — so you do not lose diagnostic information, you just stop broadcasting it to anonymous users.

In `flask/app/__init__.py`, replace the current error handler with one that returns a generic response:

```python
@app.errorhandler(Exception)
def handle_error(e):
    app.logger.error(f"Unhandled exception: {str(e)}", exc_info=True)
    return {"error": "An unexpected error occurred."}, 500

@app.errorhandler(404)
def not_found(e):
    return {"error": "Not found."}, 404
```

Rebuild and re-trigger the URLs from Step 1. Confirm no internal details are disclosed.

---

### 4. Configure Structured Logging

**Why structured (JSON) logs are superior to plain text logs:**
A plain text log entry like `ERROR 2025-01-15 login failed for jsmith` is readable by a human but difficult to query programmatically. When you have millions of log entries and need to find all failed logins by a specific user within a time window, plain text requires fragile string parsing. JSON-formatted logs can be indexed and queried by any log aggregation system (Splunk, Elasticsearch, CloudWatch) without custom parsing. The `LogRecord` object that Python passes to the `format()` method contains all available information about the log event — the `hasattr` checks allow you to include optional context fields (like `user` and `endpoint`) only when the code that generated the log event explicitly attached them.

Create `flask/app/logging_config.py`:

```python
import logging
import json
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": datetime.utcnow().isoformat(),
            "level": record.levelname,
            "message": record.getMessage(),
            "module": record.module,
        }
        if hasattr(record, "user"):
            log_entry["user"] = record.user
        if hasattr(record, "endpoint"):
            log_entry["endpoint"] = record.endpoint
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry)
```

Configure Flask to use this formatter and write logs to `/var/log/huskyhub/app.log` inside the container. Mount a local log directory in `docker-compose.yaml`.

---

### 5. Add Security-Relevant Log Events

**What makes a log event "security-relevant" and why log levels matter:**
Security-relevant events are those that indicate something worth investigating: a successful authentication (establishes a timeline of who logged in and when), a failed authentication (establishes whether a brute force attempt is in progress), and an authorization denial (establishes whether a user is attempting to access resources beyond their permissions). Log levels — DEBUG, INFO, WARNING, ERROR — are not just labels; monitoring systems are typically configured to alert on WARNING and above. Using WARNING for failed logins means a spike in warnings can trigger an automatic alert before a human notices.

Add log statements to the following locations in the codebase:

| Event | Level | Location |
|-------|-------|----------|
| Successful login | INFO | `auth.py` login route |
| Failed login attempt | WARNING | `auth.py` login route — include the username attempted |
| Access to a resource without authorization | WARNING | Any route that checks the role cookie |
| Unhandled exception | ERROR | Global error handler (already done in Step 3) |

---

### 6. Verify Log Output

Trigger each of the four log events. Then read the log file:

```bash
docker exec -it huskyhub-flask cat /var/log/huskyhub/app.log
```

Paste at least one log entry per event type in your report. Confirm the JSON structure includes timestamp, level, user, and endpoint fields.

---

### 7. Audit Dependencies

**What a CVE is and what pip-audit checks:**
A CVE (Common Vulnerabilities and Exposures) is a standardized identifier for a publicly disclosed security vulnerability in a software component. The National Vulnerability Database (NVD) maintains a searchable registry of CVEs with severity scores (CVSS) and descriptions. `pip-audit` compares the versions of packages listed in your requirements file against the NVD and the Python Packaging Advisory Database (PyPA). It does not analyze your code — it only checks whether the versions you have installed are known to be vulnerable. A clean audit result does not mean your code is secure; it means your dependencies have no *known published* vulnerabilities at this version.

Run pip-audit against the application's requirements file:

**macOS / Linux:**
```bash
pip3 audit -r flask/requirements.txt
# or
pip-audit -r flask/requirements.txt
```

**Windows:**
```powershell
pip-audit -r flask/requirements.txt
```

Record every finding: CVE identifier, affected package, installed version, fixed version, and a one-line description.

---

### 8. Research the Highest-Severity CVE

**What a CVSS score measures:**
The Common Vulnerability Scoring System (CVSS) assigns each vulnerability a score from 0 to 10 based on a standardized vector that captures the attack vector (network vs. local), the complexity of the attack, whether authentication is required, and the impact on confidentiality, integrity, and availability. A score above 9.0 is Critical — it typically means the vulnerability can be exploited remotely, without authentication, and results in full system compromise. Understanding the CVSS vector string (e.g., `AV:N/AC:L/PR:N/UI:N/S:U/C:H/I:H/A:H`) lets you reason about exploitability without reading the full advisory.

Select the highest-severity CVE from your audit. Look it up at [nvd.nist.gov](https://nvd.nist.gov). Document:
- CVSS score and vector string
- Attack vector (network / adjacent / local)
- Whether authentication is required to exploit it
- Whether a patched version exists
- The specific impact it would have on the HuskyHub application

---

## Write-Up Questions

**Q1.** What is the principle of least information in the context of error handling? How does your global error handler implement this principle, and why is this different from "security through obscurity"?

**Q2.** Present your pip-audit results as a table. For the highest-severity CVE you researched, describe the full attack chain: how an attacker discovers the vulnerable version, how they exploit it, and what they can achieve against HuskyHub.

**Q3.** The Thursday lecture covered third-party risk. What is a software supply chain attack? How does the SolarWinds breach illustrate that dependency risk extends beyond known CVEs in publicly listed packages?

---

## Hacker Mindset Prompt

Verbose error messages do reconnaissance for the attacker at zero cost. Every stack trace is a map of the application internals. Every database error message is a hint about the schema.

Reflect on:

- **Contrarian:** A developer adds verbose errors to help with debugging. How does the attacker benefit more from this decision than the developer does?
- **Committed:** An attacker who discovers a vulnerable dependency in a target application does not stop at reading the CVE. Describe the exact steps they would take from discovery to exploit in the HuskyHub context.
- **Creative:** Logging is a double-edged sword — it can also be used *against* an application. How could an attacker abuse a logging system itself as an attack vector? Research "Log4Shell" and explain how it fits this idea.
