"""Ironhaven private application — Flask, RDS and Secrets Manager."""

import json
import os
import sys

import boto3
import psycopg2
from flask import Flask, jsonify
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

AWS_REGION = os.environ["AWS_REGION"]
RDS_SECRET_ARN = os.environ["RDS_SECRET_ARN"]
DB_HOST = os.environ["DB_HOST"]
DB_NAME = os.environ["DB_NAME"]


def database_connection():
    """Retrieve credentials through the EC2 IAM role."""
    client = boto3.client("secretsmanager", region_name=AWS_REGION)

    response = client.get_secret_value(SecretId=RDS_SECRET_ARN)
    secret = json.loads(response["SecretString"])

    return psycopg2.connect(
        host=DB_HOST,
        port=5432,
        dbname=DB_NAME,
        user=secret["username"],
        password=secret["password"],
        sslmode="require",
        connect_timeout=10,
    )


@app.get("/")
def index():
    return jsonify({
        "project": "Ironhaven",
        "service": "Private Application API",
        "architecture": "Management -> Application -> RDS",
        "endpoints": ["/health", "/records"],
    })


@app.get("/health")
def health():
    try:
        with database_connection() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT current_database(), current_user"
                )
                db_name, db_user = cursor.fetchone()

        return jsonify({
            "status": "healthy",
            "service": "ironhaven-application",
            "database": db_name,
            "database_user": db_user,
            "postgresql": "connected",
        }), 200

    except Exception:
        app.logger.exception("Database health check failed")
        return jsonify({
            "status": "unhealthy",
            "postgresql": "unavailable",
        }), 503


@app.get("/records")
def records():
    try:
        with database_connection() as connection:
            with connection.cursor(
                cursor_factory=RealDictCursor
            ) as cursor:
                cursor.execute("""
                    SELECT id, component, tier, status
                    FROM ironhaven_components
                    ORDER BY id
                """)
                rows = cursor.fetchall()

        return jsonify({
            "project": "Ironhaven",
            "source": "Amazon RDS PostgreSQL",
            "count": len(rows),
            "records": [dict(row) for row in rows],
        }), 200

    except Exception:
        app.logger.exception("Database records query failed")
        return jsonify({
            "status": "error",
            "message": "Database query unavailable",
        }), 503


def initialize_database():
    """Create and populate an idempotent demonstration table."""
    with database_connection() as connection:
        with connection.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS ironhaven_components (
                    id INTEGER PRIMARY KEY,
                    component VARCHAR(100) NOT NULL,
                    tier VARCHAR(30) NOT NULL,
                    status VARCHAR(30) NOT NULL
                )
            """)

            cursor.executemany("""
                INSERT INTO ironhaven_components
                    (id, component, tier, status)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (id) DO NOTHING
            """, [
                (1, "Management EC2", "management", "operational"),
                (2, "Application EC2", "application", "operational"),
                (3, "RDS PostgreSQL", "data", "operational"),
            ])

    print("Database initialized successfully")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--init-db":
        initialize_database()
    else:
        raise SystemExit("Use Gunicorn to serve this application")
