"""Validate RDS IAM authentication, TLS and read-only access."""

import os

import boto3
import psycopg2
from psycopg2 import errors

region = os.environ["AWS_REGION"]
host = os.environ["DB_HOST"]
database = os.environ["DB_NAME"]
username = "ironhaven_reader"
certificate = "/etc/pki/tls/certs/rds-global-bundle.pem"

token = boto3.client(
    "rds", region_name=region
).generate_db_auth_token(
    DBHostname=host,
    Port=5432,
    DBUsername=username,
    Region=region,
)

connection = psycopg2.connect(
    host=host,
    port=5432,
    dbname=database,
    user=username,
    password=token,
    sslmode="verify-full",
    sslrootcert=certificate,
    connect_timeout=15,
)

try:
    with connection.cursor() as cursor:
        cursor.execute("""
            SELECT current_user, current_database()
        """)
        user, db = cursor.fetchone()

        assert user == username
        assert db == database

        cursor.execute("""
            SELECT component, tier, status
            FROM public.ironhaven_components
            ORDER BY id
        """)
        records = cursor.fetchall()
        assert len(records) >= 3

        cursor.execute("""
            SELECT ssl, version, cipher
            FROM pg_stat_ssl
            WHERE pid = pg_backend_pid()
        """)
        ssl_enabled, tls_version, cipher = cursor.fetchone()
        assert ssl_enabled

    connection.rollback()

    # Try an actual write without ever committing it.
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                INSERT INTO public.ironhaven_components
                    (id, component, tier, status)
                VALUES
                    (999999, 'unauthorized', 'test', 'blocked')
            """)
    except (
        errors.InsufficientPrivilege,
        errors.ReadOnlySqlTransaction,
    ):
        print("WRITE TEST: DENIED")
    else:
        raise RuntimeError(
            "SECURITY FAILURE: reader unexpectedly allowed INSERT"
        )
    finally:
        connection.rollback()

    print("IAM AUTHENTICATION: SUCCESS")
    print("TLS CERTIFICATE VERIFICATION: SUCCESS")
    print(f"TLS VERSION: {tls_version}")
    print(f"POSTGRESQL USER: {user}")
    print(f"DATABASE: {db}")
    print(f"READ TEST: SUCCESS ({len(records)} records)")
    print("RESULT: PASS")

finally:
    connection.close()
