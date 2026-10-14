# Ironhaven — Private Application and PostgreSQL Validation

Date: 2026-10-14
Region: eu-west-3 (Paris)
Status: PASSED

## Objective

Validate secure communication between a private EC2 application
server and an Amazon RDS PostgreSQL database using AWS IAM,
Secrets Manager and Systems Manager.

## Infrastructure

| Component | Configuration |
|---|---|
| Management EC2 | 10.42.10.21 |
| Application EC2 | 10.42.20.104 |
| Application subnet | 10.42.20.0/24 |
| Application public IP | None |
| PostgreSQL RDS | 10.42.30.44 |
| Database | ironhaven |
| PostgreSQL port | 5432 |
| AWS Region | eu-west-3 |

## Security Controls

- Application EC2 deployed without a public IPv4 address.
- Administration performed through AWS Systems Manager.
- Dedicated application IAM role.
- RDS master credentials managed by AWS Secrets Manager.
- Secrets retrieved using temporary EC2 role credentials.
- No database password stored in Terraform configuration.
- PostgreSQL connectivity restricted by Security Groups.
- TLS requested for the validated PostgreSQL connection.

## Validation Results

### 1. Systems Manager

Both EC2 instances reported Online.

Result: PASS

### 2. IAM Role

The application EC2 successfully assumed:

ironhaven-application-role

Result: PASS

### 3. DNS Resolution

RDS hostname resolved to:

10.42.30.44

Result: PASS

### 4. TCP Connectivity

Connection to PostgreSQL TCP port 5432 succeeded.

Result: PASS

### 5. Secrets Manager

The application retrieved its database credentials
using its IAM instance role.

The password was not printed in the terminal.

Result: PASS

### 6. PostgreSQL Authentication

A real PostgreSQL connection was established with
sslmode=require.

The following SQL query executed successfully:

SELECT current_database(), current_user,
       inet_server_addr(), now();

Validated results:

- Database: ironhaven
- User: ironhaven_admin
- Server address: 10.42.30.44

Result: PASS

## Security Considerations

The initial validation uses the RDS master account.

A dedicated database user with restricted privileges
should replace this account for production workloads.

TLS encryption was requested through sslmode=require.
Server certificate verification remains a recommended
hardening improvement.

## Conclusion

The complete communication path was successfully validated:

Private EC2 -> IAM Role -> Secrets Manager -> PostgreSQL RDS

This confirms the application tier can securely retrieve
database credentials and authenticate to the private data tier.

Application deployment and HTTP integration remain pending.
