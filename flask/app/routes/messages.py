from flask import Blueprint, request, redirect, url_for, render_template
from ..database import get_connection

messages_bp = Blueprint("messages", __name__)


@messages_bp.route("/messages")
def inbox():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    user_id = request.cookies.get("user_id")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute(
        f"SELECT m.message_id, m.subject, m.body, m.sent_at, m.is_read, "
        f"u.username AS sender_username, u.first_name, u.last_name "
        f"FROM messages m "
        f"JOIN users u ON m.sender_id = u.user_id "
        f"WHERE m.recipient_id = {user_id} "
        f"ORDER BY m.sent_at DESC"
    )
    received = cursor.fetchall()

    cursor.execute(
        f"SELECT m.message_id, m.subject, m.sent_at, "
        f"u.username AS recipient_username, u.first_name, u.last_name "
        f"FROM messages m "
        f"JOIN users u ON m.recipient_id = u.user_id "
        f"WHERE m.sender_id = {user_id} "
        f"ORDER BY m.sent_at DESC"
    )
    sent = cursor.fetchall()

    # All users for the recipient dropdown
    cursor.execute("SELECT user_id, username, first_name, last_name FROM users WHERE approved = 1")
    all_users = cursor.fetchall()

    conn.close()

    return render_template(
        "messages.html",
        received=received,
        sent=sent,
        all_users=all_users,
        username=username,
    )


@messages_bp.route("/messages/send", methods=["POST"])
def send_message():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    recipient_id = request.form.get("recipient_id")
    subject = request.form.get("subject", "")
    body = request.form.get("body", "")

    user_id = request.cookies.get("user_id")

    conn = get_connection()
    cursor = conn.cursor()

    # Store message body directly — formatting is important for rich messages
    cursor.execute(
        f"INSERT INTO messages (sender_id, recipient_id, subject, body) "
        f"VALUES ({user_id}, {recipient_id}, '{subject}', '{body}')"
    )
    conn.commit()
    conn.close()

    return redirect(url_for("messages.inbox"))


@messages_bp.route("/messages/advising-notes")
def advising_notes():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    role = request.cookies.get("role", "student")
    user_id = request.cookies.get("user_id")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if role in ("advisor", "admin"):
        # Advisors see all notes
        cursor.execute(
            "SELECT n.note_id, n.note_content, n.created_at, "
            "u.username, u.first_name, u.last_name "
            "FROM advising_notes n JOIN users u ON n.student_id = u.user_id "
            "ORDER BY n.created_at DESC"
        )
    else:
        cursor.execute(
            f"SELECT n.note_id, n.note_content, n.created_at, "
            f"u.username AS advisor_username, u.first_name, u.last_name "
            f"FROM advising_notes n JOIN users u ON n.advisor_id = u.user_id "
            f"WHERE n.student_id = {user_id} "
            f"ORDER BY n.created_at DESC"
        )

    notes = cursor.fetchall()
    conn.close()

    return render_template("advising_notes.html", notes=notes, role=role, username=username)


@messages_bp.route("/messages/advising-notes/add", methods=["POST"])
def add_advising_note():
    username = request.cookies.get("authenticated")
    role = request.cookies.get("role", "student")

    if not username or role not in ("advisor", "admin"):
        return redirect(url_for("auth.login"))

    advisor_id = request.cookies.get("user_id")
    student_id = request.form.get("student_id")
    note_content = request.form.get("note_content", "")

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        f"INSERT INTO advising_notes (student_id, advisor_id, note_content) "
        f"VALUES ({student_id}, {advisor_id}, '{note_content}')"
    )
    conn.commit()
    conn.close()

    return redirect(url_for("messages.advising_notes"))
