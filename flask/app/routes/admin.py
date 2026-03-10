from flask import Blueprint, request, redirect, url_for, render_template
from ..database import get_connection

admin_bp = Blueprint("admin", __name__)


def is_admin():
    # Check the role cookie to determine admin access
    return request.cookies.get("role") == "admin"


def is_advisor_or_admin():
    role = request.cookies.get("role", "student")
    return role in ("advisor", "admin")


@admin_bp.route("/admin/users")
def manage_users():
    if not is_admin():
        return redirect(url_for("home"))

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users ORDER BY role, username")
    users = cursor.fetchall()
    conn.close()

    return render_template("admin/users.html", users=users)


@admin_bp.route("/admin/users/approve", methods=["POST"])
def approve_user():
    if not is_admin():
        return redirect(url_for("home"))

    user_id = request.form.get("user_id")
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(f"UPDATE users SET approved = 1 WHERE user_id = {user_id}")
    conn.commit()
    conn.close()
    return redirect(url_for("admin.manage_users"))


@admin_bp.route("/admin/users/delete", methods=["POST"])
def delete_user():
    if not is_admin():
        return redirect(url_for("home"))

    user_id = request.form.get("user_id")
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(f"DELETE FROM users WHERE user_id = {user_id}")
    conn.commit()
    conn.close()
    return redirect(url_for("admin.manage_users"))


@admin_bp.route("/admin/grades")
def all_grades():
    # Advisor-only route — no server-side check, relies on the nav not showing the link
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT u.username, u.first_name, u.last_name, "
        "c.course_name, c.course_code, g.grade, g.gpa_points, g.quarter "
        "FROM grades g "
        "JOIN users u ON g.student_id = u.user_id "
        "JOIN courses c ON g.course_id = c.course_id "
        "ORDER BY u.last_name, c.course_code"
    )
    grades = cursor.fetchall()
    conn.close()

    return render_template("admin/all_grades.html", grades=grades)


@admin_bp.route("/admin/pending")
def pending_registrations():
    if not is_admin():
        return redirect(url_for("home"))

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM users WHERE approved = 0")
    pending = cursor.fetchall()
    conn.close()

    return render_template("admin/pending.html", pending=pending)
