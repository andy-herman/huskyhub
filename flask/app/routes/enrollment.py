from flask import Blueprint, request, redirect, url_for, render_template
from ..database import get_connection

enrollment_bp = Blueprint("enrollment", __name__)


@enrollment_bp.route("/enrollment")
def enrollment():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    user_id = request.cookies.get("user_id")
    search = request.args.get("search", "")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    if search:
        query = (
            f"SELECT e.enrollment_id, e.quarter, e.status, "
            f"c.course_name, c.course_code, c.credits, c.instructor "
            f"FROM enrollments e "
            f"JOIN courses c ON e.course_id = c.course_id "
            f"WHERE e.student_id = {user_id} "
            f"AND c.course_name LIKE '%{search}%'"
        )
    else:
        query = (
            f"SELECT e.enrollment_id, e.quarter, e.status, "
            f"c.course_name, c.course_code, c.credits, c.instructor "
            f"FROM enrollments e "
            f"JOIN courses c ON e.course_id = c.course_id "
            f"WHERE e.student_id = {user_id}"
        )

    cursor.execute(query)
    enrollments = cursor.fetchall()

    # Courses available to enroll in
    cursor.execute("SELECT * FROM courses")
    all_courses = cursor.fetchall()

    conn.close()

    return render_template(
        "enrollment.html",
        enrollments=enrollments,
        all_courses=all_courses,
        username=username,
        search=search,
    )


@enrollment_bp.route("/enrollment/add", methods=["POST"])
def add_enrollment():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    user_id = request.cookies.get("user_id")
    course_id = request.form.get("course_id")
    quarter = request.form.get("quarter", "Spring 2025")

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        f"INSERT INTO enrollments (student_id, course_id, quarter, status) "
        f"VALUES ({user_id}, {course_id}, '{quarter}', 'enrolled')"
    )
    conn.commit()
    conn.close()

    return redirect(url_for("enrollment.enrollment"))


@enrollment_bp.route("/enrollment/drop", methods=["POST"])
def drop_enrollment():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    enrollment_id = request.form.get("enrollment_id")

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(f"DELETE FROM enrollments WHERE enrollment_id = {enrollment_id}")
    conn.commit()
    conn.close()

    return redirect(url_for("enrollment.enrollment"))
