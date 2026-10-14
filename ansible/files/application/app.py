"""Ironhaven private API — IAM authentication and verified RDS TLS."""

import os

import boto3
import psycopg2
from flask import Flask, jsonify
from psycopg2.extras import RealDictCursor

app = Flask(__name__)

AWS_REGION = os.environ["AWS_REGION"]
DB_HOST = os.environ["DB_HOST"]
DB_NAME = os.environ["DB_NAME"]

DB_USER = "ironhaven_reader"
RDS_CA_BUNDLE = "/etc/pki/tls/certs/rds-global-bundle.pem"


def database_connection():
    """Connect with a temporary IAM token and verified TLS."""
    token = boto3.client(
        "rds",
        region_name=AWS_REGION,
    ).generate_db_auth_token(
        DBHostname=DB_HOST,
        Port=5432,
        DBUsername=DB_USER,
        Region=AWS_REGION,
    )

    return psycopg2.connect(
        host=DB_HOST,
        port=5432,
        dbname=DB_NAME,
        user=DB_USER,
        password=token,
        sslmode="verify-full",
        sslrootcert=RDS_CA_BUNDLE,
        connect_timeout=15,
    )


@app.get("/")
def index():
    return jsonify({
        "project": "Ironhaven",
        "service": "Private Application API",
        "authentication": "AWS IAM",
        "database_security": "TLS verify-full",
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
            "authentication": "iam",
            "tls": "verify-full",
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
                    FROM public.ironhaven_components
                    ORDER BY id
                """)
                rows = cursor.fetchall()

        return jsonify({
            "project": "Ironhaven",
            "source": "Amazon RDS PostgreSQL",
            "database_user": DB_USER,
            "authentication": "iam",
            "tls": "verify-full",
            "count": len(rows),
            "records": [dict(row) for row in rows],
        }), 200

    except Exception:
        app.logger.exception("Database records query failed")
        return jsonify({
            "status": "error",
            "message": "Database query unavailable",
        }), 503
