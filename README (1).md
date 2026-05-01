# 📊 Crypto Market Data Pipeline

> **End-to-end cloud-native ETL pipeline** for automated cryptocurrency market data collection, transformation, and analytics. Built with Python, Apache Airflow, dbt, and AWS.

[![Python](https://img.shields.io/badge/Python-3.11-blue.svg)](https://www.python.org/)
[![Airflow](https://img.shields.io/badge/Apache%20Airflow-2.9-red.svg)](https://airflow.apache.org/)
[![dbt](https://img.shields.io/badge/dbt-1.11-orange.svg)](https://www.getdbt.com/)
[![AWS](https://img.shields.io/badge/AWS-RDS%20%7C%20S3%20%7C%20EC2-yellow.svg)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/Terraform-1.5-purple.svg)](https://www.terraform.io/)

---

## 🎯 Project Overview

An **automated data pipeline** that extracts real-time cryptocurrency market data from the CoinGecko API, transforms it into a clean dimensional model, and loads it into a cloud data warehouse for analytics. The entire infrastructure is provisioned as code and orchestrated with Apache Airflow running on AWS.

### Key Features

✅ **Fully Automated**: Scheduled daily execution with zero manual intervention  
✅ **Cloud-Native**: Deployed entirely on AWS (RDS, S3, EC2)  
✅ **Infrastructure as Code**: Complete Terraform setup for reproducible deployments  
✅ **Data Quality**: 19 automated dbt tests ensuring data integrity  
✅ **Scalable Architecture**: Easily extensible to 100+ cryptocurrencies  
✅ **Production-Ready**: Error handling, retries, and monitoring included  

---

## 🏗️ Architecture

```
┌─────────────────┐
│  CoinGecko API  │
└────────┬────────┘
         │ Extract (Python)
         ▼
┌─────────────────┐      ┌──────────────┐
│   Amazon S3     │◄─────┤  Raw JSON    │
│  (Raw Storage)  │      │   Backup     │
└─────────────────┘      └──────────────┘
         │
         │ Load
         ▼
┌─────────────────┐
│   Amazon RDS    │
│  (PostgreSQL)   │
│  Raw Data Table │
└────────┬────────┘
         │ Transform (dbt)
         ▼
┌─────────────────────────┐
│    Star Schema          │
├─────────────────────────┤
│ • dim_coins             │
│ • fact_daily_prices     │
└─────────────────────────┘
         │
         │ Orchestrated by
         ▼
┌─────────────────┐
│ Apache Airflow  │
│   (AWS EC2)     │
│  - Scheduler    │
│  - Workers      │
│  - Web UI       │
└─────────────────┘
```

### Data Flow

1. **Extract**: Python script fetches 50 top cryptocurrencies from CoinGecko API
2. **Backup**: Raw JSON stored in S3 for audit trail
3. **Load**: Data inserted into RDS PostgreSQL staging table
4. **Transform**: dbt models create star schema (staging → dimensions → facts)
5. **Orchestrate**: Airflow DAG runs daily at 9 PM Cairo time

---

## 🛠️ Tech Stack

| Layer | Technology |
|-------|-----------|
| **Orchestration** | Apache Airflow 2.9 (CeleryExecutor) |
| **Data Transformation** | dbt 1.11 |
| **Data Warehouse** | AWS RDS PostgreSQL 16 |
| **Object Storage** | Amazon S3 |
| **Compute** | AWS EC2 (t3.medium) |
| **Infrastructure** | Terraform 1.5 |
| **Containerization** | Docker, Docker Compose |
| **Language** | Python 3.11 |
| **Networking** | AWS VPC, Security Groups, IAM |

---

## 📂 Project Structure

```
crypto_pipeline/
├── airflow/
│   ├── dags/
│   │   └── crypto_etl.py              # Main Airflow DAG
│   ├── docker-compose.yml             # Airflow services
│   └── .env                           # Environment variables
├── dbt_crypto/
│   ├── models/
│   │   ├── staging/
│   │   │   ├── stg_crypto_raw.sql     # Staging model
│   │   │   └── schema.yml             # Source definitions
│   │   └── marts/
│   │       ├── dim_coins.sql          # Dimension table
│   │       ├── fact_daily_prices.sql  # Fact table
│   │       └── schema.yml             # Tests & docs
│   ├── dbt_project.yml
│   └── profiles.yml
├── scripts/
│   └── extract_crypto.py              # ETL script
├── terraform/
│   ├── main.tf                        # AWS resources
│   ├── variables.tf                   # Input variables
│   ├── outputs.tf                     # Output values
│   └── terraform.tfvars               # Variable values
├── ec2_deploy/
│   ├── setup.sh                       # EC2 deployment script
│   └── .env                           # Production config
├── .env                               # Local development config
├── requirements.txt                   # Python dependencies
└── README.md
```

---

## 🚀 Quick Start

### Prerequisites

- **AWS Account** with ~$200 credits (or free tier eligible)
- **Python 3.11+**
- **Terraform 1.5+**
- **Docker & Docker Compose**
- **Git**
- **psql** (PostgreSQL client)

### 1. Clone Repository

```bash
git clone https://github.com/yourusername/crypto-pipeline.git
cd crypto-pipeline
```

### 2. Install Dependencies

```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

### 3. Configure AWS Credentials

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: eu-central-1
```

### 4. Create SSH Key for EC2

```bash
# In AWS Console: EC2 → Key Pairs → Create key pair
# Name: crypto-pipeline-key
# Download the .pem file
chmod 400 crypto-pipeline-key.pem
```

### 5. Deploy Infrastructure

```bash
cd terraform

# Update terraform.tfvars with your values
nano terraform.tfvars

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Deploy (takes ~10 minutes)
terraform apply

# Save outputs
terraform output > ../outputs.txt
```

### 6. Deploy Airflow to EC2

```bash
cd ..
./deploy_to_ec2.sh  # Follow prompts
```

### 7. Access Airflow UI

```bash
# Get Airflow URL
cd terraform
terraform output airflow_ui_url
```

Open URL in browser:
- **Username**: `airflow`
- **Password**: `airflow`

---

## 📸 Screenshots

### Airflow DAG - Successful Run

![Airflow DAG](Screenshot(22).png)

*4-stage ETL pipeline: Extract → Transform → Load → dbt Transform*

### Airflow DAG Graph

```
extract (PythonOperator)
   ↓
transform (PythonOperator)
   ↓
load (PythonOperator)
   ↓
dbt_transform (BashOperator)
```

**Run Stats:**
- ✅ All 4 tasks succeeded
- ⏱️ Total duration: 29.889 seconds
- 📅 Scheduled: Daily at 21:00 Cairo Time
- 🔄 Retries: 1 (5-minute delay)

---

## 🗄️ Data Models

### Star Schema Design

#### `dim_coins` (Dimension Table)

| Column | Type | Description |
|--------|------|-------------|
| coin_id | TEXT | Primary key (e.g., 'bitcoin') |
| symbol | TEXT | Ticker symbol (e.g., 'btc') |
| name | TEXT | Display name (e.g., 'Bitcoin') |
| updated_at | TIMESTAMP | Last refresh timestamp |

**Grain:** One row per unique cryptocurrency

---

#### `fact_daily_prices` (Fact Table)

| Column | Type | Description |
|--------|------|-------------|
| price_id | TEXT | Surrogate key (MD5 hash) |
| market_date | DATE | Date of snapshot |
| coin_id | TEXT | FK to dim_coins |
| current_price_usd | NUMERIC | Spot price in USD |
| market_cap_usd | NUMERIC | Total market cap |
| total_volume_usd | NUMERIC | 24h trading volume |
| price_change_percentage_1h | NUMERIC | 1-hour % change |
| price_change_percentage_24h | NUMERIC | 24-hour % change |
| extracted_at | TIMESTAMP | ETL timestamp |

**Grain:** One row per coin per day

---

### Example Queries

**Top 10 Coins by Market Cap (Latest Date)**

```sql
SELECT 
    d.name,
    d.symbol,
    f.current_price_usd,
    f.market_cap_usd,
    f.price_change_percentage_24h
FROM fact_daily_prices f
JOIN dim_coins d ON f.coin_id = d.coin_id
WHERE f.market_date = (SELECT MAX(market_date) FROM fact_daily_prices)
ORDER BY f.market_cap_usd DESC
LIMIT 10;
```

**Bitcoin Price Trend (Last 30 Days)**

```sql
SELECT 
    market_date,
    current_price_usd,
    price_change_percentage_24h
FROM fact_daily_prices
WHERE coin_id = 'bitcoin'
ORDER BY market_date DESC
LIMIT 30;
```

---

## 🧪 Data Quality Tests

dbt runs **19 automated tests** on every pipeline execution:

### Source Tests (4)
- ✅ `crypto_raw_data.load_id` is unique
- ✅ `crypto_raw_data.load_id` is not null
- ✅ `crypto_raw_data.market_date` is not null
- ✅ `crypto_raw_data.coin_id` is not null

### Staging Tests (5)
- ✅ Unique load_id
- ✅ Not null: load_id, extracted_at, market_date, coin_id, name

### Dimension Tests (3)
- ✅ `dim_coins.coin_id` is unique
- ✅ `dim_coins.coin_id` is not null
- ✅ `dim_coins.name` is not null

### Fact Tests (7)
- ✅ `fact_daily_prices.price_id` is unique
- ✅ Not null: price_id, market_date, coin_id
- ✅ Referential integrity: coin_id exists in dim_coins

---

## 💰 Cost Breakdown

| Service | Instance Type | Cost |
|---------|---------------|------|
| RDS PostgreSQL | db.t3.micro | **FREE** (750 hrs/month) |
| EC2 (Airflow) | t3.medium | $0.04/hr (~$30/month) |
| S3 Storage | Standard | ~$0.01/month |
| **Total** | | **~$30/month** |

### Cost Optimization Tips

**Stop EC2 when not in use:**
```bash
aws ec2 stop-instances --instance-ids i-xxxxx
```

**Use AWS Free Tier:**
- RDS: 750 hours/month free for 12 months
- S3: 5GB free storage
- EC2: 750 hours/month t2.micro (or t3.micro in some regions)

---

## 🔐 Security Best Practices

✅ **VPC Isolation**: RDS and EC2 in private subnets  
✅ **Security Groups**: Restricted inbound rules (only your IP)  
✅ **IAM Roles**: EC2 instance profile for S3 access (no hardcoded keys)  
✅ **Secrets Management**: Environment variables in `.env` (not committed)  
✅ **S3 Block Public Access**: Enabled by default  
✅ **PostgreSQL**: Strong password, non-default username  

---

## 🐛 Troubleshooting

### Airflow DAG Not Showing

```bash
# Check Airflow logs
docker-compose logs airflow-scheduler

# Verify DAG syntax
docker-compose exec airflow-worker airflow dags list
```

### Cannot Connect to RDS

```bash
# Check security group allows your IP
# Verify RDS is publicly accessible
# Test connection
psql -h <rds-endpoint> -U postgres -d crypto_db -p 5432
```

### dbt Tests Failing

```bash
# Check database schema
\dt  # List tables

# Run dbt debug
dbt debug

# Re-run specific model
dbt run --select stg_crypto_raw
```

### S3 Upload Fails

```bash
# Check IAM role attached to EC2
# Verify boto3 credentials
aws s3 ls s3://your-bucket-name/
```

---

## 🔄 Development Workflow

### Local Development

```bash
# 1. Start local Airflow
cd airflow
docker-compose up -d

# 2. Test ETL script
python scripts/extract_crypto.py

# 3. Run dbt models
cd dbt_crypto
dbt run
dbt test

# 4. Trigger DAG manually in UI
# http://localhost:8080
```

### Deploy to Production

```bash
# 1. Update code
git add .
git commit -m "Your changes"

# 2. Sync to EC2
scp -r . ubuntu@<ec2-ip>:~/crypto_pipeline/

# 3. Restart Airflow
ssh ubuntu@<ec2-ip>
cd crypto_pipeline/airflow
docker-compose restart
```

---

## 📈 Future Enhancements

- [ ] Add more data sources (Binance, Coinbase APIs)
- [ ] Implement real-time streaming with Kafka
- [ ] Build Metabase/Superset dashboards
- [ ] Add data lineage tracking
- [ ] Implement incremental dbt models
- [ ] Set up CI/CD with GitHub Actions
- [ ] Add email/Slack alerts for failures
- [ ] Migrate to AWS MWAA (Managed Airflow)
- [ ] Implement data versioning with dbt snapshots
- [ ] Add ML models for price prediction

---

## 📚 Learning Resources

- [Apache Airflow Documentation](https://airflow.apache.org/docs/)
- [dbt Documentation](https://docs.getdbt.com/)
- [AWS RDS Best Practices](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_BestPractices.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Dimensional Modeling (Kimball)](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/)

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

---


## 👤 Author

**Your Name**

- GitHub: [@markisaac1812](https://github.com/markisaac1812)
- LinkedIn: [markisaac](https://linkedin.com/in/mark-isaac-982401389)
- Email: markisaac695@gmail.com

---

## 🙏 Acknowledgments

- **CoinGecko** for providing free cryptocurrency API
- **Apache Airflow** community for excellent orchestration tool
- **dbt Labs** for revolutionizing data transformation
- **Joe Reis** for excellent DE course materials

---

## 📊 Project Stats

![Lines of Code](https://img.shields.io/badge/Lines%20of%20Code-2500%2B-blue)
![Commits](https://img.shields.io/badge/Commits-50%2B-green)
![AWS Resources](https://img.shields.io/badge/AWS%20Resources-15-orange)
![Data Quality Tests](https://img.shields.io/badge/dbt%20Tests-19-purple)

---

<p align="center">
  <b>⭐ Star this repo if you found it helpful!</b>
</p>

<p align="center">
  Made with ❤️ and ☕ by a Data Engineer
</p>
