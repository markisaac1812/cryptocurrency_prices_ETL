from datetime import timedelta
import os
import sys

import pendulum
from airflow import DAG
from airflow.providers.standard.operators.bash import BashOperator
from airflow.providers.standard.operators.python import PythonOperator

SCRIPTS_DIR = "/opt/airflow/scripts"
if os.path.isdir(SCRIPTS_DIR) and SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SCRIPTS_DIR)

def extract_task(ti):
    from extract_crypto import COINGECKO_URL, extract
    raw_rows = extract(COINGECKO_URL)
    ti.xcom_push(key="raw_rows", value=raw_rows)

def transform_task(ti):
    from extract_crypto import transform
    raw_rows = ti.xcom_pull(task_ids="extract", key="raw_rows")
    transformed_rows = transform(raw_rows)
    ti.xcom_push(key="transformed_rows", value=transformed_rows)


def load_task(ti):
    from extract_crypto import load
    transformed_rows = ti.xcom_pull(task_ids="transform", key="transformed_rows")
    inserted_count = load(transformed_rows)
    return inserted_count


with DAG(
    dag_id="crypto_etl_daily_9pm",
    description="Extract, transform, load crypto data and run dbt",
    schedule="0 21 * * *",  # daily at 9 PM Cairo time
    start_date=pendulum.datetime(2026, 4, 23, 21, 0, tz="Africa/Cairo"),
    catchup=False,
    default_args={
        "owner": "airflow",
        "retries": 1,
        "retry_delay": timedelta(minutes=5),
    },
) as dag:
    extract_operator = PythonOperator(
        task_id="extract",
        python_callable=extract_task,
    )

    transform_operator = PythonOperator(
        task_id="transform",
        python_callable=transform_task,
    )

    load_operator = PythonOperator(
        task_id="load",
        python_callable=load_task,
    )

    dbt_operator = BashOperator(
        task_id="dbt_transform",
        bash_command="cd /opt/airflow/dbt_crypto && dbt run && dbt test",
    )

    extract_operator >> transform_operator >> load_operator >> dbt_operator