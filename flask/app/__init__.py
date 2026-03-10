from flask import Flask, render_template, request, redirect, url_for


def create_app():
    app = Flask(__name__)

    # Secret key used for flash messages
    import os
    app.secret_key = os.environ.get("FLASK_SECRET_KEY", "dev-secret-huskyhub-2024")

    from .routes.auth import auth_bp
    from .routes.grades import grades_bp
    from .routes.enrollment import enrollment_bp
    from .routes.messages import messages_bp
    from .routes.documents import documents_bp
    from .routes.admin import admin_bp
    from .routes.chatbot import chatbot_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(grades_bp)
    app.register_blueprint(enrollment_bp)
    app.register_blueprint(messages_bp)
    app.register_blueprint(documents_bp)
    app.register_blueprint(admin_bp)
    app.register_blueprint(chatbot_bp)

    @app.route("/")
    def home():
        username = request.cookies.get("authenticated")
        if not username:
            return redirect(url_for("auth.login"))
        role = request.cookies.get("role", "student")
        return render_template("home.html", username=username, role=role)

    @app.errorhandler(Exception)
    def handle_error(e):
        # Show full traceback to help with debugging during development
        import traceback
        return (
            f"<pre>An error occurred:\n\n{traceback.format_exc()}</pre>",
            500,
        )

    return app
