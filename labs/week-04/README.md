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

**Install pip-audit:**
```bash
pip install pip-audit
```

---

## Steps

### 1. Trigger Verbose Errors

With the application running, navigate to each of the following malformed URLs and record the full response body for each:

```
http://localhost/grades?student_id='
http://localhost/grades?student_id=1 UNION SELECT 1,2,3--
http://localhost/nonexistent-page
http://localhost/documents/download?file=/etc/passwd
```

For each response, document:
- The HTTP status code
- Every internal detail exposed (stack traces, file paths, library versions, database errors, SQL queries)

---

### 2. Analyze What an Attacker Learns

For each error response, write a structured analysis: what was revealed, and how would an attacker use that specific piece of information in a subsequent attack? Be specific.

---

### 3. Implement a Global Error Handler

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

Run pip-audit against the application's requirements file:

```bash
pip-audit -r flask/requirements.txt
```

Record every finding: CVE identifier, affected package, installed version, fixed version, and a one-line description.

---

### 8. Research the Highest-Severity CVE

Select the highest-severity CVE from your audit. Look it up at [nvd.nist.gov](https://nvd.nist.gov). Document:
- CVSS score and vector string
- Attack vector (network / adjacent / local)
- Whether authentication is required to exploit it
- Whether a patched version exists
- The specific impact it would have on the HuskyHub application

---

### 9. Write a Dependency Management Policy

Write a short policy (3–5 sentences) for the HuskyHub development team covering: how often dependency audits should run, what the escalation path is for a critical CVE, and whether direct or transitive dependencies should be included.

---

## Write-Up Questions

**Q1.** List every piece of internal information exposed by the verbose errors you triggered in Step 1. For each item, explain specifically how an attacker would use it in a follow-on attack.

**Q2.** Paste one JSON log entry for each of your four log event types. Explain why each field in the structured format is useful for incident response.

**Q3.** What is the principle of least information in the context of error handling? How does your global error handler implement this principle, and why is this different from "security through obscurity"?

**Q4.** Present your pip-audit results as a table. For the highest-severity CVE you researched, describe the full attack chain: how an attacker discovers the vulnerable version, how they exploit it, and what they can achieve against HuskyHub.

**Q5.** The Thursday lecture covered third-party risk. What is a software supply chain attack? How does the SolarWinds breach illustrate that dependency risk extends beyond known CVEs in publicly listed packages?

---

## Hacker Mindset Prompt

Verbose error messages do reconnaissance for the attacker at zero cost. Every stack trace is a map of the application internals. Every database error message is a hint about the schema.

Reflect on:

- **Contrarian:** A developer adds verbose errors to help with debugging. How does the attacker benefit more from this decision than the developer does?
- **Committed:** An attacker who discovers a vulnerable dependency in a target application does not stop at reading the CVE. Describe the exact steps they would take from discovery to exploit in the HuskyHub context.
- **Creative:** Logging is a double-edged sword — it can also be used *against* an application. How could an attacker abuse a logging system itself as an attack vector? Research "Log4Shell" and explain how it fits this idea.
