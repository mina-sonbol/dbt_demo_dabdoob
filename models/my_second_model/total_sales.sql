{{ config(
    materialized='view',
    alias="dbt_" ~ this.name
)}}

select 
	date(cdate) as creation_day,
	sum(pay) as total_payment
from {{ ref('sales_last_week') }}
where status = 1 and paymentStatus = 1 and cancelStatus = 0
group by 1

-- dbt build --select <model_name> --vars '{'is_test_run': 'false'}'
{% if var('is_test_run', default=true) %}

limit 100

{% endif %}
