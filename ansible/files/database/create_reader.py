"""Idempotent PostgreSQL IAM reader provisioning."""

import json
import os

import boto3
import psycopg2

client = boto3.client(
    "secretsmanager",
    region_name=os.environ["AWS_REGION"],
)

secret = json.loads(
    client.get_secret_value(
        SecretId=os.environ["RDS_SECRET_ARN"]
    )["SecretString"]
)

connection = psycopg2.connect(
    host=os.environ["DB_HOST"],
    port=5432,
    dbname=os.environ["DB_NAME"],
    user=secret["username"],
    password=secret["password"],
    sslmode="require",
    connect_timeout=10,
)

try:
    with connection:
        with connection.cursor() as cursor:
            cursor.execute("""
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM pg_roles
                        WHERE rolname = 'ironhaven_reader'
                    ) THEN
                        CREATE ROLE ironhaven_reader
                            LOGIN
                            NOSUPERUSER
                            NOCREATEDB
                            NOCREATEROLE
                            NOREPLICATION;
                    END IF;
                END
                $$;
            """)

            cursor.execute("""
                GRANT rds_iam TO ironhaven_reader;
                GRANT CONNECT ON DATABASE ironhaven
                    TO ironhaven_reader;
                GRANT USAGE ON SCHEMA public
                    TO ironhaven_reader;
                GRANT SELECT ON TABLE public.ironhaven_components
                    TO ironhaven_reader;

                ALTER ROLE ironhaven_reader
                    SET default_transaction_read_only = on;
            """)

            cursor.execute("""
                SELECT
                    has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components',
                        'SELECT'
                    ),
                    has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components',
                        'INSERT'
                    ),
                    has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components',
                        'UPDATE'
                    ),
                    has_table_privilege(
                        'ironhaven_reader',
                        'public.ironhaven_components',
                        'DELETE'
                    );
            """)

            can_read, can_insert, can_update, can_delete = (
                cursor.fetchone()
            )

            assert can_read
            assert not any([can_insert, can_update, can_delete])

    print("SUCCESS: ironhaven_reader created/configured")
    print("SELECT=YES INSERT=NO UPDATE=NO DELETE=NO")
    print("IAM database authentication role granted")

finally:
    connection.close()
