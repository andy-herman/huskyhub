from flask import (
    Blueprint, request, redirect, url_for,
    render_template, make_response
)
from ..database import get_connection

auth_bp = Blueprint("auth", __name__)


@auth_bp.route("/login", methods=["GET", "POST"])
def login():
    error = None

    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")

        conn = get_connection()
        cursor = conn.cursor(dictionary=True)

        # Build the query using the submitted credentials
        query = (
            f"SELECT * FROM users "
            f"WHERE username = '{username}' "
            f"AND password = '{password}' "
            f"AND approved = 1"
        )
        cursor.execute(query)
        user = cursor.fetchone()
        conn.close()

        if user:
            resp = make_response(redirect(url_for("home")))
            # Store identity in cookies so the app knows who is logged in
            resp.set_cookie("authenticated", username)
            resp.set_cookie("role", user["role"])
            resp.set_cookie("user_id", str(user["user_id"]))
            return resp
        else:
            error = "Invalid username or password."

    return render_template("login.html", error=error)


@auth_bp.route("/logout")
def logout():
    resp = make_response(redirect(url_for("auth.login")))
    resp.delete_cookie("authenticated")
    resp.delete_cookie("role")
    resp.delete_cookie("user_id")
    return resp


@auth_bp.route("/register", methods=["GET", "POST"])
def register():
    error = None

    if request.method == "POST":
        username = request.form.get("username", "")
        password = request.form.get("password", "")
        first_name = request.form.get("first_name", "")
        last_name = request.form.get("last_name", "")
        email = request.form.get("email", "")

        conn = get_connection()
        cursor = conn.cursor()

        query = (
            f"INSERT INTO users "
            f"(username, first_name, last_name, email, password, role, approved) "
            f"VALUES ('{username}', '{first_name}', '{last_name}', "
            f"'{email}', '{password}', 'student', 0)"
        )

        try:
            cursor.execute(query)
            conn.commit()
            return redirect(url_for("auth.login"))
        except Exception as e:
            error = f"Registration error: {str(e)}"
        finally:
            conn.close()

    return render_template("register.html", error=error)
