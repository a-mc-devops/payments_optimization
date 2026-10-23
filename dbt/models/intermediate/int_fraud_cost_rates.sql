WITH 
    jan_jul_sales AS (
        SELECT
            business_type,
            SUM(amount_eur) AS sales_without_3ds_eur,
            COUNTIF(fraud_report_id IS NOT NULL) AS fraud_case_count,
            SUM(guarantee_cost_eur) AS guarantee_cost_eur
        FROM {{ ref('int_approved_payments')}}
        WHERE three_ds_used IS FALSE AND attempt_date < DATE '{{ var("fraud_complete_before") }}'
        GROUP BY business_type
    )

SELECT
    business_type,
    sales_without_3ds_eur,
    fraud_case_count,
    guarantee_cost_eur,
    ROUND(guarantee_cost_eur / sales_without_3ds_eur * 100
        * (fraud_case_count - {{ var('standard_errors_in_range') }} * SQRT(fraud_case_count)) / fraud_case_count, 4)
        AS fraud_cost_per_100_eur_low,
    ROUND(guarantee_cost_eur / sales_without_3ds_eur * 100, 4) AS fraud_cost_per_100_eur_best,
    ROUND(guarantee_cost_eur / sales_without_3ds_eur * 100
        * (fraud_case_count + {{ var('standard_errors_in_range') }} * SQRT(fraud_case_count)) / fraud_case_count, 4)
        AS fraud_cost_per_100_eur_high
FROM jan_jul_sales