from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.models.param import Param
from airflow.operators.python import PythonOperator


def validate_run_dt(**context):
    run_dt = context['params']['run_dt']

    try:
        parsed_dt = datetime.strptime(run_dt, '%Y-%m-%d').date()
    except ValueError as exc:
        raise ValueError(f'run_dt must use YYYY-MM-DD format, got: {run_dt}') from exc

    min_dt = datetime.strptime('2026-03-01', '%Y-%m-%d').date()
    max_dt = datetime.strptime('2026-03-05', '%Y-%m-%d').date()

    if parsed_dt < min_dt or parsed_dt > max_dt:
        raise ValueError(
            f'run_dt {run_dt} is outside the allowed sample range: 2026-03-01 to 2026-03-05'
        )

    print(f'Validated run_dt={run_dt}')


with DAG(
    dag_id='order_subject_daily_multi_task',
    description='Run order subject pipelines as separate Airflow tasks',
    start_date=datetime(2026, 3, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    params={
        'run_dt': Param(
            default='2026-03-01',
            type='string',
            description='Business date to process. Example: 2026-03-01.',
        ),
    },
    tags=['dw_project', 'offline', 'order_subject', 'multi_task'],
) as dag:
    validate_run_dt_task = PythonOperator(
        task_id='validate_run_dt',
        python_callable=validate_run_dt,
    )

    run_dwd_order_clean = BashOperator(
        task_id='run_dwd_order_clean',
        bash_command=(
            "bash /opt/project/pipeline/run_dwd_order_clean_pipeline.sh "
            "--run-dt {{ params.run_dt }}"
        ),
    )

    run_fct_order = BashOperator(
        task_id='run_fct_order',
        bash_command=(
            "bash /opt/project/pipeline/run_order_fact_pipeline.sh "
            "--run-dt {{ params.run_dt }}"
        ),
    )

    run_dws_user_order_day_agg = BashOperator(
        task_id='run_dws_user_order_day_agg',
        bash_command=(
            "bash /opt/project/pipeline/run_dws_user_order_day_agg_pipeline.sh "
            "--run-dt {{ params.run_dt }}"
        ),
    )

    run_ads_order_day_overview = BashOperator(
        task_id='run_ads_order_day_overview',
        bash_command=(
            "bash /opt/project/pipeline/run_ads_order_day_overview_pipeline.sh "
            "--run-dt {{ params.run_dt }}"
        ),
    )

    run_order_subject_dq_report = BashOperator(
        task_id='run_order_subject_dq_report',
        bash_command=(
            "bash /opt/project/pipeline/run_order_subject_dq_report_pipeline.sh "
            "--run-dt {{ params.run_dt }}"
        ),
    )

    (
        validate_run_dt_task
        >> run_dwd_order_clean
        >> run_fct_order
        >> run_dws_user_order_day_agg
        >> run_ads_order_day_overview
        >> run_order_subject_dq_report
    )
