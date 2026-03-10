# Week 6 Lab — Authorization, IDOR, and Offensive Tools

**Lecture:** Authorization and Permissions; Hackers, Offensive Techniques, and Malware

---

## Overview

This week the focus shifts from who you are (authentication) to what you are allowed to do (authorization). HuskyHub has broken access controls at multiple points: students can view other students' grades by changing a URL parameter, advisor-only routes have no server-side role check, and the admin routes trust a cookie value rather than verifying role server-side. You will exploit these manually, then use Burp Suite to automate your findings.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser Developer Tools | Manually manipulate URL parameters |
| Burp Suite Community Edition | Intercept, modify, and replay HTTP requests |
| curl | Test authorization checks from the command line |
| Python requests | Automate IDOR enumeration |

**Download Burp Suite Community:** [portswigger.net/burp/communitydownload](https://portswigger.net/burp/communitydownload)

---

## Steps

### 1. Map Authorization-Sensitive Endpoints

Log in as `jsmith`. Compile a list of every URL containing an ID parameter: `student_id`, `user_id`, `doc_id`, `enrollment_id`, etc. This is your IDOR candidate list.

---

### 2. Exploit IDOR on Grades

Navigate to your own grades:
```
http://localhost/grades?student_id=3
```

Now change the `student_id` to each value from 3 to 11. For each, record:
- Whether the request succeeds
- Whose record was returned
- What grade data is exposed

Document whether any server-side check is performed to verify the requesting user owns the record.

---

### 3. Exploit Broken Access Control on Admin Routes

While logged in as `jsmith` (a student), directly navigate to:
```
http://localhost/admin/users
http://localhost/admin/grades
http://localhost/admin/pending
```

For each route, document whether access is granted and what data or actions are exposed.

---

### 4. Set Up Burp Suite

Configure your browser to proxy through Burp Suite:
1. Open Burp Suite → **Proxy → Intercept → Open Browser**
2. Navigate to `http://localhost/grades?student_id=3`
3. In Burp, find the request in **Proxy → HTTP History**
4. Right-click → **Send to Repeater**

---

### 5. Automate IDOR Enumeration with Burp Repeater

In Burp Repeater, systematically change the `student_id` value from 1 to 15 and send each request. Record every student ID that returns a valid grade record with a name attached.

Then use **Intruder** to automate this:
1. Right-click the request in Repeater → **Send to Intruder**
2. Highlight the `student_id` value → **Add §**
3. Under **Payloads**, select **Numbers** from 1 to 20
4. Start the attack and review results

---

### 6. Find a Second IDOR Endpoint

Using Burp's history or by manually browsing, identify at least one additional endpoint vulnerable to IDOR beyond `/grades`. Candidates include `/documents/download`, `/enrollment`, and the message endpoint.

Document: the endpoint, the vulnerable parameter, and what data or action is exposed.

---

### 7. Remediation — Server-Side Authorization Decorator

Create a reusable authorization decorator in `flask/app/auth_utils.py`:

```python
from functools import wraps
from flask import request, redirect, url_for, abort, session

def require_role(*roles):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            role = session.get('role', 'student')
            if role not in roles:
                abort(403)
            return f(*args, **kwargs)
        return decorated
    return decorator

def require_own_resource(student_id_param='student_id'):
    def decorator(f):
        @wraps(f)
        def decorated(*args, **kwargs):
            requested_id = request.args.get(student_id_param) or kwargs.get(student_id_param)
            current_user_id = str(session.get('user_id'))
            role = session.get('role', 'student')
            if role not in ('advisor', 'admin') and str(requested_id) != current_user_id:
                abort(403)
            return f(*args, **kwargs)
        return decorated
    return decorator
```

---

### 8. Apply the Decorators

Apply `@require_own_resource()` to the `/grades` route. Apply `@require_role('admin')` to all `/admin/*` routes. Apply `@require_role('advisor', 'admin')` to `/admin/grades`.

Rebuild and test.

---

### 9. Verify Remediation

Repeat Steps 2 and 3 against the hardened application. Confirm:
- Accessing another student's grades returns HTTP 403
- Accessing admin routes as a student returns HTTP 403
- Legitimate access still works for advisors and admins

Paste the HTTP responses in your report.

---

## Write-Up Questions

**Q1.** Define Insecure Direct Object Reference (IDOR) in your own words. Why does hiding the edit button in the UI fail to prevent IDOR? What is the only reliable place to enforce access control?

**Q2.** Present all IDOR and broken access control findings as a table with columns: Endpoint, HTTP Method, Vulnerable Parameter, Data/Action Exposed, Severity.

**Q3.** Explain the difference between role-based access control (RBAC) and attribute-based access control (ABAC). Which model does your remediation implement? What scenario would require ABAC instead?

**Q4.** Before your remediation, the admin routes checked `request.cookies.get('role')`. After, they check `session.get('role')`. Why is the session-based check more trustworthy than the cookie-based check, even after the Week 5 session signing fix?

**Q5.** Burp Intruder enumerated student IDs 1–20 in seconds. What would a script that automated this against a production application need to do to avoid triggering detection? What defenses would slow it down?

---

## Hacker Mindset Prompt

IDOR is the simplest class of vulnerability to exploit — change a number, get someone else's data — yet it appears in major production systems continuously. Meta's 2021 data scraping incident, exposing 533 million records, was rooted in an access control failure exploitable through API enumeration.

Reflect on:

- **Contrarian:** The application showed the correct data to the correct user in the UI. A student who only uses the UI would never notice this vulnerability. What does this say about the gap between "works correctly" and "is secure"?
- **Committed:** A committed attacker who discovers an IDOR vulnerability does not stop at one record. Write a Python script (pseudocode is fine) that would exfiltrate the complete grade database using the IDOR you found.
- **Creative:** IDOR becomes significantly harder to exploit if object IDs are not sequential integers. What alternative ID scheme would make enumeration impractical, and what are the tradeoffs?
