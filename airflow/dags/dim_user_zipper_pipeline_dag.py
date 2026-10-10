from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator


with DAG(
    dag_id='dim_user_zipper_pipeline',
    description='Initialize and run the Spark-based user zipper dimension pipeline',
    start_date=datetime(2026, 4, 22),
    schedule=None,
    catchup=False,
    tags=['dw_project', 'spark', 'offline', 'zipper'],
) as dag:
    init_user_zipper_tables = BashOperator(
        task_id='init_user_zipper_tables',
        bash_command=(
            "python /opt/project/pipeline/run_user_zipper_pipeline.py "
            "--run-dt {{ dag_run.conf.get('run_dt', ds) }} "
            "--init-tables --init-only"
        ),
    )

    run_user_zipper_pipeline = BashOperator(
        task_id='run_user_zipper_pipeline',
        bash_command=(
            "python /opt/project/pipeline/run_user_zipper_pipeline.py "
            "--run-dt {{ dag_run.conf.get('run_dt', ds) }}"
        ),
    )

    init_user_zipper_tables >> run_user_zipper_pipeline
