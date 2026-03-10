FROM python:3.11-slim

WORKDIR /app

COPY flask/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY flask/app ./app

RUN mkdir -p app/uploads && chmod 777 app/uploads

ENV FLASK_APP=app
ENV FLASK_RUN_HOST=0.0.0.0
ENV FLASK_RUN_PORT=5000

EXPOSE 5000

CMD ["flask", "run"]
