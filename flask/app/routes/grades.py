from flask import Blueprint, request, redirect, url_for, render_template
from ..database import get_connection

grades_bp = Blueprint("grades", __name__)


@grades_bp.route("/grades")
def grades():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    # Use the student_id from the query string if provided,
    # otherwise fall back to the logged-in user's own ID
    student_id = request.args.get("student_id", request.cookies.get("user_id"))

    search = request.args.get("search", "")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if search:
        query = (
            f"SELECT g.grade_id, g.grade, g.gpa_points, g.quarter, "
            f"c.course_name, c.course_code, c.credits "
            f"FROM grades g "
            f"JOIN courses c ON g.course_id = c.course_id "
            f"WHERE g.student_id = {student_id} "
            f"AND (c.course_name LIKE '%{search}%' OR c.course_code LIKE '%{search}%')"
        )
    else:
        query = (
            f"SELECT g.grade_id, g.grade, g.gpa_points, g.quarter, "
            f"c.course_name, c.course_code, c.credits "
            f"FROM grades g "
            f"JOIN courses c ON g.course_id = c.course_id "
            f"WHERE g.student_id = {student_id}"
        )

    cursor.execute(query)
    grade_records = cursor.fetchall()

    cursor.execute(f"SELECT * FROM users WHERE user_id = {student_id}")
    student = cursor.fetchone()

    conn.close()

    return render_template(
        "grades.html",
        grades=grade_records,
        student=student,
        student_id=student_id,
        search=search,
        current_user=username,
    )
