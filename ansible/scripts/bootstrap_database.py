#!/usr/bin/env python3
"""Bootstrap private RDS through SSM, without application admin rights."""

import json
import os
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

import psycopg2
from psycopg2 import sql

ROOT = Path(__file__).resolve().parents[2]
PROFILE = os.environ.get("AWS_PROFILE", "ironhaven")
REGION = "eu-west-3"
LOCAL_PORT = 15432

def command(*args):
    return subprocess.check_output(
        list(args), text=True, stderr=subprocess.PIPE
    ).strip()

def aws(*args):
    return command(
        "aws", "--profile", PROFILE,
        "--region", REGION, *args
    )

metadata = json.loads(command(
    "terraform", f"-chdir={ROOT / 'terraform'}",
    "output", "-json", "database"
))
instance_id = command(
    "terraform", f"-chdir={ROOT / 'terraform'}",
    "output", "-raw", "application_instance_id"
)
secret_arn = command(
    "terraform", f"-chdir={ROOT / 'terraform'}",
    "output", "-raw", "database_master_secret_arn"
)

secret = json.loads(json.loads(aws(
    "secretsmanager", "get-secret-value",
    "--secret-id", secret_arn,
    "--output", "json"
))["SecretString"])

ca_file = Path.home() / ".cache/ironhaven/rds-global-bundle.pem"
ca_file.parent.mkdir(parents=True, exist_ok=True)
if not ca_file.exists():
    urllib.request.urlretrieve(
        "https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem",
        ca_file
    )
ca_file.chmod(0o600)

parameters = json.dumps({
    "host": [metadata["address"]],
    "portNumber": ["5432"],
    "localPortNumber": [str(LOCAL_PORT)]
})

print("IRONHAVEN | PRIVATE DATABASE BOOTSTRAP", flush=True)
print("Starting SSM tunnel to private RDS...", flush=True)

tunnel = subprocess.Popen(
    [
        "aws", "--profile", PROFILE, "--region", REGION,
        "ssm", "start-session",
        "--target", instance_id,
        "--document-name", "AWS-StartPortForwardingSessionToRemoteHost",
        "--parameters", parameters
    ],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    start_new_session=True
)

try:
    for _ in range(40):
        if tunnel.poll() is not None:
            raise RuntimeError("SSM tunnel could not start")
        try:
            with socket.create_connection(("127.0.0.1", LOCAL_PORT), 1):
                break
        except OSError:
            time.sleep(1)
    else:
        raise RuntimeError("SSM tunnel timeout")

    connection = psycopg2.connect(
        host=metadata["address"],
        hostaddr="127.0.0.1",
        port=LOCAL_PORT,
        dbname=metadata["name"],
        user=secret["username"],
        password=secret["password"],
        sslmode="verify-full",
        sslrootcert=str(ca_file),
        connect_timeout=10
    )

    try:
        with connection:
            with connection.cursor() as cursor:
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS public.ironhaven_components (
                        id INTEGER PRIMARY KEY,
                        component TEXT NOT NULL,
                        tier TEXT NOT NULL,
                        status TEXT NOT NULL
                    )
                """)

                cursor.executemany("""
                    INSERT INTO public.ironhaven_components
                        (id, component, tier, status)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT (id) DO NOTHING
                """, [
                    (1, "Management EC2", "management", "operational"),
                    (2, "Application EC2", "application", "operational"),
                    (3, "RDS PostgreSQL", "data", "operational"),
                ])

                cursor.execute("""
                    DO $$
                    BEGIN
                        IF NOT EXISTS (
                            SELECT FROM pg_roles
                            WHERE rolname = 'ironhaven_reader'
                        ) THEN
                            CREATE ROLE ironhaven_reader
                                LOGIN NOSUPERUSER NOCREATEDB
                                NOCREATEROLE NOREPLICATION;
                        END IF;
                    END
                    $$;
                """)

                cursor.execute("""
                    GRANT rds_iam TO ironhaven_reader;
                    GRANT CONNECT ON DATABASE ironhaven TO ironhaven_reader;
                    GRANT USAGE ON SCHEMA public TO ironhaven_reader;
                    GRANT SELECT ON public.ironhaven_components
                        TO ironhaven_reader;
                    ALTER ROLE ironhaven_reader
                        SET default_transaction_read_only = on;
                """)

                cursor.execute("""
                    SELECT
                      has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components', 'SELECT'
                      ),
                      has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components', 'INSERT'
                      ),
                      has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components', 'UPDATE'
                      ),
                      has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components', 'DELETE'
                      )
                """)
                rights = cursor.fetchone()
                if rights != (True, False, False, False):
                    raise RuntimeError("Reader permissions are not restricted")

                cursor.execute(
                    "SELECT COUNT(*) FROM public.ironhaven_components"
                )
                count = cursor.fetchone()[0]

        print("SSM TUNNEL: SUCCESS")
        print("RDS TLS CERTIFICATE: VERIFIED")
        print("DATABASE SCHEMA: READY")
        print(f"DEMONSTRATION RECORDS: {count}")
        print("READER: ironhaven_reader")
        print("SELECT: ALLOWED")
        print("INSERT/UPDATE/DELETE: DENIED")
        print("ADMIN SECRET ON APPLICATION: NOT REQUIRED")
        print("RESULT: PASS")
    finally:
        connection.close()
finally:
    import signal
    try:
        os.killpg(tunnel.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass
    try:
        tunnel.wait(timeout=3)
    except subprocess.TimeoutExpired:
        os.killpg(tunnel.pid, signal.SIGKILL)
        tunnel.wait(timeout=3)
