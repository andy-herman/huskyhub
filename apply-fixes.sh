#!/usr/bin/env bash
# =============================================================================
# HuskyHub Gap Analysis Fix Script
# Applies all Tier 1, 2, and 3 fixes from the March 10 2026 instructional
# review. Run this from the root of your local huskyhub clone on main branch.
# =============================================================================

set -e  # exit on any error

# ── Guard: must be inside the repo ──────────────────────────────────────────
if [ ! -f "docker-compose.yaml" ] || [ ! -d "flask" ]; then
  echo "ERROR: Run this script from the root of your huskyhub clone."
  echo "       cd path/to/huskyhub && bash apply-fixes.sh"
  exit 1
fi

echo "==> Starting HuskyHub gap-analysis fixes on main branch..."

# ============================================================================
# FIX 1.2 — Remove dead MYSQL_PORT variable from .env.example
#           and wire it properly into docker-compose.yaml
# ============================================================================
echo "--> Fix 1.2: Removing dead MYSQL_PORT from .env.example..."
# Remove the MYSQL_PORT line from .env.example
sed -i '' '/^MYSQL_PORT=/d' .env.example 2>/dev/null || sed -i '/^MYSQL_PORT=/d' .env.example

echo "--> Fix 1.2: Wiring \${MYSQL_PORT} into docker-compose.yaml..."
# Replace hardcoded 3306:3306 port with variable (default 3306)
# Also adds MYSQL_PORT back to .env.example properly
cat >> .env.example << 'EOF'
MYSQL_PORT=3306
EOF

# Replace docker-compose port mapping
python3 - << 'PYEOF'
import re

with open("docker-compose.yaml") as f:
    content = f.read()

# Replace hardcoded port with variable
content = content.replace('"3306:3306"', '"${MYSQL_PORT:-3306}:3306"')

with open("docker-compose.yaml", "w") as f:
    f.write(content)
print("    docker-compose.yaml updated.")
PYEOF

# ============================================================================
# FIX 1.2 (cont.) — Add healthchecks to Flask and nginx containers
#                   so Docker Desktop shows "healthy" for all three
# ============================================================================
echo "--> Fix 2.2: Adding healthchecks to Flask and nginx services..."
python3 - << 'PYEOF'
content = open("docker-compose.yaml").read()

# Add healthcheck to nginx service
if "huskyhub-nginx:" in content and "healthcheck" not in content.split("huskyhub-flask:")[0]:
    content = content.replace(
        "    depends_on:\n      - huskyhub-flask",
        """    healthcheck:
      test: ["CMD", "curl", "-sf", "http://localhost/login"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s
    depends_on:
      - huskyhub-flask"""
    )

# Add healthcheck to Flask service
if "huskyhub-flask:" in content:
    flask_block = "    depends_on:\n      huskyhub-db:\n        condition: service_healthy"
    if flask_block in content and "healthcheck" not in content.split("    extra_hosts:")[0].split("huskyhub-flask:")[1]:
        content = content.replace(
            flask_block,
            """    healthcheck:
      test: ["CMD", "python3", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:5000/')"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 15s
    depends_on:
      huskyhub-db:
        condition: service_healthy"""
        )

open("docker-compose.yaml", "w").write(content)
print("    Healthchecks added to Flask and nginx.")
PYEOF

# ============================================================================
# FIX 3.6 — Pull Flask SECRET_KEY from environment variable
# ============================================================================
echo "--> Fix 3.6: Moving Flask secret_key to environment variable..."
python3 - << 'PYEOF'
content = open("flask/app/__init__.py").read()
content = content.replace(
    '    app.secret_key = "dev-secret-huskyhub-2024"',
    '    import os\n    app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-huskyhub-2024")'
)
open("flask/app/__init__.py", "w").write(content)
print("    flask/app/__init__.py updated.")
PYEOF

# Add FLASK_SECRET_KEY to .env.example
if ! grep -q "FLASK_SECRET_KEY" .env.example; then
  echo "FLASK_SECRET_KEY=dev-secret-huskyhub-2024" >> .env.example
fi

# Add FLASK_SECRET_KEY to docker-compose.yaml Flask environment block
python3 - << 'PYEOF'
content = open("docker-compose.yaml").read()
if "FLASK_SECRET_KEY" not in content:
    content = content.replace(
        "      FLASK_DEBUG: 1",
        "      FLASK_DEBUG: 1\n      FLASK_SECRET_KEY: ${FLASK_SECRET_KEY:-dev-secret-huskyhub-2024}"
    )
open("docker-compose.yaml", "w").write(content)
print("    docker-compose.yaml: FLASK_SECRET_KEY env var wired in.")
PYEOF

# ============================================================================
# FIX 3.3 — Update stale "Spring 2025" enrollment dates to Spring 2026
# ============================================================================
echo "--> Fix 3.3: Updating stale enrollment dates in init.sql..."
sed -i '' "s/'Spring 2025'/'Spring 2026'/g" database/init.sql 2>/dev/null || \
  sed -i "s/'Spring 2025'/'Spring 2026'/g" database/init.sql
echo "    init.sql enrollment dates updated."

# ============================================================================
# FIX 3.5 — Add a Makefile for common operations
# ============================================================================
echo "--> Fix 3.5: Creating Makefile..."
cat > Makefile << 'EOF'
# HuskyHub — Developer helpers
# Usage: make <target>
#
# Targets:
#   up        Start all containers (build if needed)
#   down      Stop containers, keep data volumes
#   reset     Wipe all volumes and rebuild from scratch
#   logs      Tail all container logs
#   ai-setup  Download the Ollama model required for Week 9
#   shell-db  Open a MySQL shell inside the database container

.PHONY: up down reset logs ai-setup shell-db

up:
	docker compose up --build

down:
	docker compose down

reset:
	@echo "WARNING: This deletes all database data and rebuilds from init.sql"
	docker compose down -v
	docker compose up --build

logs:
	docker compose logs -f

ai-setup:
	docker compose --profile ai up -d
	docker exec -it huskyhub-ollama ollama pull llama3.2
	docker compose restart huskyhub-flask
	@echo "Ollama model ready. Navigate to /chatbot to test."

shell-db:
	docker exec -it huskyhub-db mysql -u user -psupersecretpw huskyhub
EOF
echo "    Makefile created."

# ============================================================================
# FIX — Update labs/week-01/README.md
#   2.2  "healthy" → "Running"
#   2.3  Chatbot step: add note that AI is in baseline mode in Week 1
#   1.4  Windows PowerShell command fix
#   2.5  Add "check chatbot page source" hint
# ============================================================================
echo "--> Fixes 1.4, 2.2, 2.3, 2.5: Patching labs/week-01/README.md..."
python3 - << 'PYEOF'
with open("labs/week-01/README.md") as f:
    content = f.read()

# Fix 2.2: "healthy" language → "Running" (healthcheck only on db)
content = content.replace(
    'When all three show a green "running" status in Docker Desktop',
    'When all three show a "Running" status in Docker Desktop (the database container may take up to 60 seconds to initialize before Flask can connect)'
)
content = content.replace(
    "Confirm all three containers are running in Docker Desktop before proceeding.",
    'Confirm all three containers show **Running** status in Docker Desktop before proceeding. Note: only the database container shows a separate "healthy" indicator — this is expected. Flask and nginx will show "Running" without a health badge.'
)

# Fix 1.4: Windows PowerShell — copy command only works in CMD, not PowerShell
content = content.replace(
    "**Windows (Git Bash or PowerShell):**\n```powershell\ngit clone https://github.com/andy-herman/huskyhub.git\ncd huskyhub\ncopy .env.example .env\ndocker compose up --build\n```",
    "**Windows (Git Bash — recommended):**\n```bash\ngit clone https://github.com/andy-herman/huskyhub.git\ncd huskyhub\ncp .env.example .env\ndocker compose up --build\n```\n\n**Windows (PowerShell):**\n```powershell\ngit clone https://github.com/andy-herman/huskyhub.git\ncd huskyhub\nCopy-Item .env.example .env\ndocker compose up --build\n```\n\n> **Recommendation:** Git Bash is the most consistent shell for this course on Windows. It uses Unix-style commands (`cp`, `grep`, `cat`) that match all lab examples. If you are not sure which to use, install and use Git Bash."
)

# Fix 2.3: Add note before chatbot step about baseline mode
chatbot_step_old = "### 7. Interact with the AI Chatbot\n\n**Why AI systems create a different kind of attack surface:**"
chatbot_step_new = """### 7. Interact with the AI Chatbot

> **Note:** The AI model (Ollama/llama3.2) is not downloaded until the Week 9 pre-lab setup. In Week 1, the chatbot page will load but submitting a message will return an error or placeholder response. **This is expected and intentional.** Your goal this week is to observe how the page is structured, what the interface reveals, and document whatever responses you receive — even error messages. You will return to these notes in Week 9 when the AI is fully operational.

**Why AI systems create a different kind of attack surface:**"""
content = content.replace(chatbot_step_old, chatbot_step_new)

# Fix 2.5: Add hint in page source section to check chatbot page
old_hint = "View the source of the login page"
if old_hint in content:
    pass  # already exists variant
# Add general hint about chatbot page source after the page source step
content = content.replace(
    "Do not attempt to exploit anything yet. Just observe and document.",
    "Do not attempt to exploit anything yet. Just observe and document.\n\n> **Page source tip:** Before leaving the chatbot route, view the page source (`Cmd+Option+U` / `Ctrl+U`). Not all sensitive information is visible in the rendered page — some may be present in the HTML that is sent to the browser. Record anything you find that a normal user would not be expected to see."
)

with open("labs/week-01/README.md", "w") as f:
    f.write(content)

print("    labs/week-01/README.md updated.")
PYEOF

# ============================================================================
# FIX — Update root README.md on main branch
#   1.1  Canonicalize setup instructions (cp .env.example, not manual paste)
#   1.3  Add Common Issues / Troubleshooting section
#   2.1  Complete user account table (add missing 5 users + pending1 note)
#   2.7  Add database reset instructions
#   2.8  Add docker compose / docker-compose note
#   3.2  Add branch workflow guidance
#   3.4  Add note about making repo public
# ============================================================================
echo "--> Fixes 1.1, 1.3, 2.1, 2.7, 2.8, 3.2, 3.4: Patching root README.md..."
python3 - << 'PYEOF'
with open("README.md") as f:
    content = f.read()

# ── Fix 2.1: Expand user table if incomplete ──────────────────────────────
old_table = """| Username | Role | Password |
|----------|------|----------|
| `admin` | Admin | `admin` |
| `mwilson` | Advisor | `advisor123` |
| `jsmith` | Student | `password123` |
| `alee` | Student | `alexpass` |
| `pchen` | Student | `priya2024` |
| `tbrown` | Student | `tyler99` |
| `sgarcia` | Student | `sofia!123` |"""

new_table = """| Username | Role | Password | Notes |
|----------|------|----------|-------|
| `admin` | Admin | `admin` | Full admin access |
| `mwilson` | Advisor | `advisor123` | Advisor; can view all students |
| `jsmith` | Student | `password123` | Primary lab account |
| `alee` | Student | `alexpass` | |
| `pchen` | Student | `priya2024` | |
| `tbrown` | Student | `tyler99` | |
| `sgarcia` | Student | `sofia!123` | |
| `dkim` | Student | `dkim2025` | |
| `rnguyen` | Student | `rachel456` | |
| `cmartinez` | Student | `carlos789` | |
| `lthompson` | Student | `lauren!pass` | |
| `pending1` | Student | `newuser` | **Unapproved account** — cannot log in until approved by admin |

> Additional accounts may be discoverable through the application itself — finding them is part of the reconnaissance exercise in Week 1."""

if old_table in content:
    content = content.replace(old_table, new_table)

# ── Fix 1.1: Canonicalize .env setup — ensure cp approach is used ────────
# If there's a manual "create a .env file and paste" section, replace it
content = content.replace(
    "Create a `.env` file in the project root and paste in the following:",
    "Copy the example environment file:"
)
# Make sure the canonical command is present
if "cp .env.example .env" not in content and "copy .env.example" not in content:
    content = content.replace(
        "docker compose up --build",
        "cp .env.example .env       # macOS / Linux / Git Bash\n# Copy-Item .env.example .env  # Windows PowerShell\ndocker compose up --build",
        1  # only replace first occurrence
    )

# ── Fix 2.8: docker compose note ─────────────────────────────────────────
if "docker-compose" not in content.lower():
    content = content.replace(
        "docker compose up --build",
        "docker compose up --build\n\n> **Note:** On older Docker installations the command may be `docker-compose` (with a hyphen). If `docker compose` is not recognized, try `docker-compose up --build`.",
        1
    )

# ── Fix 3.4: Repo access note ────────────────────────────────────────────
if "public" not in content.lower() and "collaborator" not in content.lower():
    content = content.replace(
        "git clone https://github.com/andy-herman/huskyhub.git",
        "git clone https://github.com/andy-herman/huskyhub.git\n\n> **Repository access:** This repository must be public (or you must be added as a collaborator) before students can clone it. To make it public: GitHub → Settings → scroll to bottom → Change visibility → Public."
    )

# ── Fix 2.7: Database reset instructions ─────────────────────────────────
reset_section = """
---

## Resetting the Application

If the database gets corrupted (for example, through SQL injection during Week 7 exercises), you can wipe all data and rebuild from the initial seed data:

```bash
# Stop containers and delete all volumes (all database data will be erased)
docker compose down -v

# Rebuild and restart fresh
docker compose up --build
```

Or with the Makefile shortcut:

```bash
make reset
```

> **Warning:** `docker compose down -v` permanently deletes the `mysqldata` volume. All records created during labs will be lost. This is the intended way to recover from a broken state.
"""

if "Resetting the Application" not in content:
    # Append before the last section or at end
    content = content.rstrip() + "\n" + reset_section

# ── Fix 1.3: Common Issues / Troubleshooting section ─────────────────────
troubleshoot_section = """
---

## Common Issues

### "Cannot connect to the Docker daemon"
Docker Desktop is not running. Open Docker Desktop and wait for the engine status indicator to turn green before retrying.

### Port 80 already in use
Another process is using port 80. On macOS, AirPlay Receiver commonly binds port 80 — disable it in System Preferences → General → AirDrop & Handoff. On Windows, IIS may be running — stop it in Services. To identify what is using the port:
```bash
# macOS / Linux
sudo lsof -i :80

# Windows (PowerShell as Administrator)
netstat -ano | findstr :80
```

### Port 3306 already in use
A local MySQL installation is running on port 3306. Either stop it (`brew services stop mysql` on macOS, or via Services on Windows), or change `MYSQL_PORT` in your `.env` file to an unused port like `3307`.

### `docker compose` not found
Your Docker installation uses the older V1 syntax. Try `docker-compose up --build` (with a hyphen) instead.

### WSL 2 issues on Windows
If Docker prompts you to install WSL 2 and the installer fails, see the official Microsoft guide: https://learn.microsoft.com/en-us/windows/wsl/install. Ensure you restart your machine after installation.

### The Flask container exits immediately
Run `docker compose logs huskyhub-flask` to see the error. The most common cause is the database not being ready yet — wait 30 seconds and try `docker compose up` again without `--build`.
"""

if "Common Issues" not in content:
    content = content.rstrip() + "\n" + troubleshoot_section

# ── Fix 3.2: Branch workflow guidance ────────────────────────────────────
branch_section = """
---

## Weekly Lab Branch Workflow

Each week's lab instructions are in the corresponding branch (`week-02`, `week-03`, etc.). To switch to a new week's branch without losing your work:

```bash
# Save any local changes before switching branches
git add -A
git commit -m "Week N: my lab work"

# Switch to the next week's branch
git fetch origin
git checkout week-02   # replace with the target week number
```

> **Important:** If you have modified application files (which you will from Week 3 onward), switching branches may produce merge conflicts. Commit your changes to a personal branch first, or use `git stash` to temporarily set them aside:
> ```bash
> git stash          # save changes temporarily
> git checkout week-02
> git stash pop      # restore your changes on the new branch
> ```
"""

if "Weekly Lab Branch Workflow" not in content:
    content = content.rstrip() + "\n" + branch_section

with open("README.md", "w") as f:
    f.write(content)

print("    README.md updated.")
PYEOF

# ============================================================================
# FIX — Propagate week-01 lab fixes to all branches that include it
# ============================================================================
echo "--> Propagating week-01 fixes to all weekly branches..."

for branch in week-02 week-03 week-04 week-05 week-06 week-07 week-08; do
  if git show-ref --verify --quiet refs/heads/$branch 2>/dev/null || \
     git ls-remote --heads origin $branch 2>/dev/null | grep -q $branch; then
    echo "    Updating $branch..."
    git checkout $branch
    # Sync week-01 lab from main
    git checkout main -- labs/week-01/README.md
    # Sync infrastructure fixes
    git checkout main -- docker-compose.yaml .env.example flask/app/__init__.py database/init.sql Makefile
    # Update branch root README to point to this week's lab
    WEEK_NUM=$(echo $branch | sed 's/week-0*//')
    PADDED=$(printf "%02d" $WEEK_NUM)
    cp labs/week-$PADDED/README.md README.md 2>/dev/null || true
    git add -A
    git diff --cached --quiet || git commit -m "$branch: apply gap-analysis fixes (healthchecks, date updates, Windows fixes, chatbot baseline note, Makefile)"
  fi
done

git checkout main

# ============================================================================
# Final commit on main
# ============================================================================
echo "--> Committing all fixes on main..."
git add -A
git diff --cached --quiet || git commit -m "Apply gap-analysis fixes: all tiers

Tier 1 (blocking):
- README.md: canonicalize setup to cp .env.example approach
- .env.example + docker-compose.yaml: wire MYSQL_PORT properly
- README.md: add Common Issues / Troubleshooting section
- week-01: fix Windows PowerShell command (copy → cp / Copy-Item)

Tier 2 (instructional):
- README.md: complete user account table (all 12 accounts, pending1 note)
- docker-compose.yaml: add healthchecks to Flask and nginx
- week-01: clarify Running vs healthy container status
- week-01: add baseline note to chatbot step (AI not active until Week 9)
- week-01: add page source hint for chatbot page
- README.md: add database reset instructions
- README.md: add docker compose / docker-compose compatibility note

Tier 3 (improvements):
- README.md: add branch workflow guidance with git stash instructions
- README.md: add repo visibility note
- database/init.sql: update stale Spring 2025 dates to Spring 2026
- Makefile: add up/down/reset/logs/ai-setup/shell-db targets
- flask/app/__init__.py: pull SECRET_KEY from FLASK_SECRET_KEY env var"

echo ""
echo "==> All fixes applied. Pushing to GitHub..."
git push origin main
for branch in week-02 week-03 week-04 week-05 week-06 week-07 week-08; do
  if git show-ref --verify --quiet refs/heads/$branch; then
    git push origin $branch
  fi
done

echo ""
echo "Done! All changes pushed to GitHub."
