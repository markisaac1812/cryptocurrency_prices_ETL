Project 2: Detailed Plan
What You're Building
A daily pipeline that:

Pulls cryptocurrency prices from CoinGecko API (free, no auth needed)
Stores raw data in S3
Transforms it into a star schema (fact table + dimension tables) using dbt
Runs in Redshift
Orchestrated by Airflow
All infrastructure created with Terraform


Architecture
CoinGecko API 
    ↓
Airflow (extracts daily at 9 AM)
    ↓
S3 (raw JSON files: /raw/crypto/2025-01-15.json)
    ↓
Load to Redshift staging table (raw data)
    ↓
dbt transforms:
    - staging: clean/type the data
    - dim_coins: coin metadata (id, name, symbol)
    - fact_daily_prices: price, volume, market cap per coin per day
    ↓
Redshift (analytics-ready tables)

Week-by-Week Plan
Week 1: Local Setup (No AWS Yet)
Day 1-2: Extract + Load Locally

Write Python script to fetch data from CoinGecko API

Endpoint: https://api.coingecko.com/api/v3/coins/markets
Get top 50 coins: price, volume, market cap


Save to local PostgreSQL (not S3 yet)
Test: Can you query the raw data?

Day 3-4: dbt Transformation (Local Postgres)

Install dbt-postgres
Create dbt project structure:

models/staging/stg_crypto_raw.sql - clean raw data
models/marts/dim_coins.sql - unique coins (id, name, symbol)
models/marts/fact_daily_prices.sql - prices per coin per day


Run dbt run - verify star schema created

Day 5: Airflow Orchestration (Docker)

Docker Compose with Airflow + Postgres
Create DAG:

Task 1: Run Python extraction script
Task 2: Trigger dbt run


Test: Does it run end-to-end daily?

Goal: Working pipeline on your laptop (Airflow → Postgres → dbt)

Week 2: Move to AWS
Day 6-7: Terraform AWS Infrastructure

Create main.tf to provision:

S3 bucket (for raw JSON)
Redshift cluster (dc2.large, 1 node is fine)
IAM role (Redshift access to S3)
VPC/Security groups (Redshift accessible from your IP)


Run terraform apply
Test: Can you connect to Redshift from DBeaver/psql?

Day 8-9: Migrate Pipeline to AWS

Update Python script:

Save extracted JSON to S3 (not local files)
Use boto3 to upload


Create Redshift staging table: raw_crypto_data
Load S3 JSON → Redshift using COPY command
Update dbt profiles.yml to connect to Redshift (not local Postgres)
Run dbt against Redshift

Day 10: Deploy Airflow on EC2

Launch EC2 instance (t3.medium)
Install Docker + Docker Compose
Copy Airflow setup to EC2
Update DAG to use AWS credentials (IAM role or secrets)
Test: Airflow on EC2 runs the full pipeline

Goal: Pipeline running fully in AWS

Week 3: Polish + Documentation
Day 11-12: Add Features

Backfill historical data (last 30 days)
Add data quality checks in dbt (test for nulls, duplicates)
Add simple SQL query examples (top 10 coins by volume)

Day 13-14: Documentation

GitHub README with:

Architecture diagram (draw.io or Excalidraw)
Setup instructions (Terraform commands, Airflow setup)
Sample queries
Screenshots (Airflow DAG, dbt lineage, Redshift tables)


Clean up code (comments, formatting)


File Structure
crypto-pipeline/
├── terraform/
│   ├── main.tf          # S3, Redshift, IAM
│   ├── variables.tf
│   └── outputs.tf
├── airflow/
│   ├── dags/
│   │   └── crypto_etl.py
│   ├── docker-compose.yml
│   └── requirements.txt
├── dbt/
│   ├── models/
│   │   ├── staging/
│   │   │   └── stg_crypto_raw.sql
│   │   └── marts/
│   │       ├── dim_coins.sql
│   │       └── fact_daily_prices.sql
│   ├── dbt_project.yml
│   └── profiles.yml
├── scripts/
│   └── extract_crypto.py
└── README.md

Star Schema Design
dim_coins (dimension table)

coin_id (PK)
name
symbol
first_seen_date

fact_daily_prices (fact table)

price_id (PK)
coin_id (FK)
date
price_usd
volume_24h
market_cap


Key Commands You'll Use
bash# Terraform
terraform init
terraform plan
terraform apply
terraform destroy

# dbt
dbt run
dbt test
dbt docs generate

# Airflow
docker-compose up -d
docker-compose logs -f

# AWS CLI
aws s3 ls s3://your-bucket/
aws s3 cp data.json s3://your-bucket/raw/