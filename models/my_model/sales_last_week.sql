{{ config(
    materialized='table',
    alias="dbt_" ~ this.name
)}}

select 
	id,
	pay,
	cdate,
	status,
	paymentStatus,
	cancelStatus
from {{ source('my_model_from_invoice','invoice') }} -- njinja syntax
where date(cdate) >= current_date()-interval 7 day

-- dbt build --select <model_name> --vars '{'is_test_run': 'false'}'
{% if var('is_test_run', default=true) %}

limit 100

{% endif %}
