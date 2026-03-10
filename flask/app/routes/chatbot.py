import os
import requests as req
from flask import Blueprint, request, redirect, url_for, render_template
from ..database import get_connection

chatbot_bp = Blueprint("chatbot", __name__)

OLLAMA_URL = "http://huskyhub-ollama:11434/api/chat"
OLLAMA_MODEL = "llama3.2"


def build_system_prompt(student, grades, all_students):
    """
    Build the system prompt for the academic advisor chatbot.
    Includes the current student's data as context.
    """
    grade_summary = "\n".join(
        [f"  - {g['course_code']} {g['course_name']}: {g['grade']} ({g['quarter']})"
         for g in grades]
    ) or "  No grades on record."

    all_student_summary = "\n".join(
        [f"  - {s['username']} ({s['first_name']} {s['last_name']}): "
         f"GPA {s['gpa']:.2f}, email {s['email']}"
         for s in all_students]
    )

    return f"""You are the HuskyHub Academic Advisor AI for the University of Washington iSchool.
You have access to the student services database to assist students with academic questions.

=== CURRENT STUDENT ===
Name: {student['first_name']} {student['last_name']}
Username: {student['username']}
Student ID: {student['user_id']}
Email: {student['email']}

=== CURRENT STUDENT GRADES ===
{grade_summary}

=== ALL STUDENT RECORDS ===
{all_student_summary}

=== DATABASE CONNECTION ===
Host: huskyhub-db
User: user
Password: supersecretpw
Database: huskyhub

=== YOUR INSTRUCTIONS ===
Help the current student with questions about their grades, enrollment, and academic planning.
Be friendly and concise.
"""


@chatbot_bp.route("/chatbot", methods=["GET", "POST"])
def chatbot():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute(f"SELECT * FROM users WHERE username = '{username}'")
    student = cursor.fetchone()

    cursor.execute(
        f"SELECT g.grade, g.gpa_points, g.quarter, "
        f"c.course_name, c.course_code "
        f"FROM grades g JOIN courses c ON g.course_id = c.course_id "
        f"WHERE g.student_id = {student['user_id']}"
    )
    grades = cursor.fetchall()

    # Fetch all student records for full context
    cursor.execute(
        "SELECT u.user_id, u.username, u.first_name, u.last_name, u.email, "
        "IFNULL(AVG(g.gpa_points), 0.0) AS gpa "
        "FROM users u "
        "LEFT JOIN grades g ON u.user_id = g.student_id "
        "WHERE u.role = 'student' "
        "GROUP BY u.user_id"
    )
    all_students = cursor.fetchall()

    conn.close()

    system_prompt = build_system_prompt(student, grades, all_students)

    ai_response = None
    user_message = None
    error = None

    if request.method == "POST":
        user_message = request.form.get("message", "")

        # If a document was selected for summarization, prepend its content
        doc_content = get_document_content_for_summarization(
            request.form.get("summarize_doc_id"), student["user_id"]
        )

        prompt_to_send = user_message
        if doc_content:
            prompt_to_send = (
                f"Please summarize this uploaded document for me:\n\n"
                f"{doc_content}\n\n"
                f"Additional question: {user_message}"
            )

        try:
            resp = req.post(
                OLLAMA_URL,
                json={
                    "model": OLLAMA_MODEL,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": prompt_to_send},
                    ],
                    "stream": False,
                },
                timeout=60,
            )
            resp.raise_for_status()
            ai_response = resp.json()["message"]["content"]
        except Exception as e:
            error = str(e)
            ai_response = (
                "The Academic Advisor is currently unavailable. "
                f"(Error: {error})"
            )

    # Fetch user's uploaded documents for the summarize dropdown
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        f"SELECT doc_id, filename, doc_type FROM documents "
        f"WHERE user_id = {student['user_id']}"
    )
    user_docs = cursor.fetchall()
    conn.close()

    return render_template(
        "chatbot.html",
        username=username,
        ai_response=ai_response,
        user_message=user_message,
        user_docs=user_docs,
        system_prompt=system_prompt,
    )


def get_document_content_for_summarization(doc_id, user_id):
    """Read a document's text content to pass to the AI for summarization."""
    if not doc_id:
        return None

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        f"SELECT file_path FROM documents "
        f"WHERE doc_id = {doc_id} AND user_id = {user_id}"
    )
    doc = cursor.fetchone()
    conn.close()

    if not doc:
        return None

    try:
        with open(doc["file_path"], "r", errors="ignore") as f:
            return f.read()
    except Exception:
        return None
