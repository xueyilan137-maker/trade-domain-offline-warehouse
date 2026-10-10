from datetime import datetime

from airflow import DAG
from airflow.models.param import Param
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator


MIN_DT = datetime.strptime('2026-03-01', '%Y-%m-%d').date()
MAX_DT = datetime.strptime('2026-03-07', '%Y-%m-%d').date()


def validate_params(**context):
    start_dt = context['params']['start_dt']
    end_dt = context['params']['end_dt']

    try:
        parsed_start_dt = datetime.strptime(start_dt, '%Y-%m-%d').date()
        parsed_end_dt = datetime.strptime(end_dt, '%Y-%m-%d').date()
    except ValueError as exc:
        raise ValueError(
            f'start_dt and end_dt must use YYYY-MM-DD format, got: {start_dt}, {end_dt}'
        ) from exc

    if parsed_start_dt > parsed_end_dt:
        raise ValueError(f'start_dt {start_dt} cannot be later than end_dt {end_dt}')

    if parsed_start_dt < MIN_DT or parsed_end_dt > MAX_DT:
        raise ValueError(
            'date range is outside the realistic demo range: 2026-03-01 to 2026-03-07'
        )

    print(f'Validated date range: start_dt={start_dt}, end_dt={end_dt}')


def runner_command(subject, allow_quality_fail=False):
    allow_quality_fail_arg = ' --allow-quality-fail' if allow_quality_fail else ''
    return (
        'cd /opt/project && '
        'python pipeline/trade_domain_realistic_runner.py '
        '--start-dt {{ params.start_dt }} '
        '--end-dt {{ params.end_dt }} '
        f'--subject {subject}'
        f'{allow_quality_fail_arg}'
    )


with DAG(
    dag_id='trade_domain_realistic_daily',
    description='Run realistic 7-day trade-domain warehouse pipeline by subject',
    start_date=datetime(2026, 3, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    params={
        'start_dt': Param(
            default='2026-03-01',
            type='string',
            description='Start business date. Demo range: 2026-03-01 to 2026-03-07.',
        ),
        'end_dt': Param(
            default='2026-03-07',
            type='string',
            description='End business date. Demo range: 2026-03-01 to 2026-03-07.',
        ),
    },
    tags=['dw_project', 'offline', 'trade_domain', 'realistic'],
) as dag:
    validate_params_task = PythonOperator(
        task_id='validate_params',
        python_callable=validate_params,
    )

    run_dwd_order = BashOperator(
        task_id='run_dwd_order',
        bash_command=runner_command('dwd_order'),
    )

    run_fct_order = BashOperator(
        task_id='run_fct_order',
        bash_command=runner_command('fct_order', allow_quality_fail=True),
    )

    run_refund_anomaly = BashOperator(
        task_id='run_refund_anomaly',
        bash_command=runner_command('refund_anomaly'),
    )

    run_dws_ads = BashOperator(
        task_id='run_dws_ads',
        bash_command=runner_command('dws_ads', allow_quality_fail=True),
    )

    run_payment = BashOperator(
        task_id='run_payment',
        bash_command=runner_command('payment'),
    )

    run_multi_theme = BashOperator(
        task_id='run_multi_theme',
        bash_command=runner_command('multi_theme', allow_quality_fail=True),
    )

    (
        validate_params_task
        >> run_dwd_order
        >> run_fct_order
        >> run_refund_anomaly
        >> run_dws_ads
        >> run_payment
        >> run_multi_theme
    )
