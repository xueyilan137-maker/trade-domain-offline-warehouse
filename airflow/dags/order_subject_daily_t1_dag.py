from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator


with DAG(
    dag_id='order_subject_daily_t1',
    description='Run order subject FCT -> DWS -> ADS pipeline daily with T+1 business date',
    start_date=datetime(2026, 3, 2),
    schedule='0 1 * * *',
    catchup=False,
    tags=['dw_project', 'offline', 'order_subject', 't1'],
) as dag:
    run_fct_order = BashOperator(
        task_id='run_fct_order',
        bash_command=(
            "bash /opt/project/pipeline/run_order_fact_pipeline.sh "
            "--run-dt {{ dag_run.conf.get('run_dt') or ds }}"
        ),
    )

    run_dws_user_order_day_agg = BashOperator(
        task_id='run_dws_user_order_day_agg',
        bash_command=(
            "bash /opt/project/pipeline/run_dws_user_order_day_agg_pipeline.sh "
            "--run-dt {{ dag_run.conf.get('run_dt') or ds }}"
        ),
    )

    run_ads_order_day_overview = BashOperator(
        task_id='run_ads_order_day_overview',
        bash_command=(
            "bash /opt/project/pipeline/run_ads_order_day_overview_pipeline.sh "
            "--run-dt {{ dag_run.conf.get('run_dt') or ds }}"
        ),
    )

    run_fct_order >> run_dws_user_order_day_agg >> run_ads_order_day_overview

