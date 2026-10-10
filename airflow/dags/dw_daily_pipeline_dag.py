from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

with DAG(
    dag_id='dw_daily_pipeline',
    description='Run the daily Spark-based offline warehouse pipeline',
    start_date=datetime(2026, 3, 1),
    schedule=None,
    catchup=False,
    tags=['dw_project', 'spark', 'offline'],
) as dag:
    run_daily_pipeline = BashOperator(
        task_id='run_daily_pipeline',
        bash_command=(
            "bash /opt/project/pipeline/run_daily_pipeline.sh "
            "--run-dt {{ dag_run.conf.get('run_dt', ds) }}"
        ),
    )
