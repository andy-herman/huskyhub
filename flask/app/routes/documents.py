import os
from flask import (
    Blueprint, request, redirect, url_for,
    render_template, send_file
)
from ..database import get_connection

documents_bp = Blueprint("documents", __name__)

UPLOAD_DIR = os.path.join(os.path.dirname(__file__), "..", "uploads")


@documents_bp.route("/documents")
def documents():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    user_id = request.cookies.get("user_id")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        f"SELECT * FROM documents WHERE user_id = {user_id} ORDER BY uploaded_at DESC"
    )
    docs = cursor.fetchall()
    conn.close()

    return render_template("documents.html", documents=docs, username=username)


@documents_bp.route("/documents/upload", methods=["POST"])
def upload():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    user_id = request.cookies.get("user_id")
    doc_type = request.form.get("doc_type", "general")

    if "file" not in request.files:
        return redirect(url_for("documents.documents"))

    file = request.files["file"]
    if file.filename == "":
        return redirect(url_for("documents.documents"))

    # Save file using the original filename
    save_path = os.path.join(UPLOAD_DIR, file.filename)
    file.save(save_path)

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        f"INSERT INTO documents (user_id, filename, file_path, doc_type) "
        f"VALUES ({user_id}, '{file.filename}', '{save_path}', '{doc_type}')"
    )
    conn.commit()
    conn.close()

    return redirect(url_for("documents.documents"))


@documents_bp.route("/documents/download")
def download():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    # Serve the file at the path provided in the query string
    file_path = request.args.get("file")

    if not file_path:
        return "No file specified.", 400

    if os.path.exists(file_path):
        return send_file(file_path, as_attachment=True)
    else:
        return f"File not found: {file_path}", 404


@documents_bp.route("/documents/delete", methods=["POST"])
def delete_document():
    username = request.cookies.get("authenticated")
    if not username:
        return redirect(url_for("auth.login"))

    doc_id = request.form.get("doc_id")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(f"SELECT file_path FROM documents WHERE doc_id = {doc_id}")
    doc = cursor.fetchone()

    if doc and os.path.exists(doc["file_path"]):
        os.remove(doc["file_path"])

    cursor.execute(f"DELETE FROM documents WHERE doc_id = {doc_id}")
    conn.commit()
    conn.close()

    return redirect(url_for("documents.documents"))
