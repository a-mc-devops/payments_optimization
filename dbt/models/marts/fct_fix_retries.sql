WITH
    try_again AS (
        SELECT
            p.shop_id,
            p.business_type,
            p.retries_on_date,
            p.amount_eur,
            p.final_outcome = 'approved' AS is_rescued,
            p.retries_on_date IS NOT NULL AND p.payment_date >= p.retries_on_date AS retries_were_on
        FROM {{ ref('int_attempts') }} AS a
        JOIN {{ ref('int_payments') }} AS p ON a.payment_id = p.payment_id
        WHERE a.attempt_number = 1 AND a.decline_type = 'try_again'
    ),

    rescue_rates AS (
        SELECT
            business_type,
            COUNTIF(is_rescued AND retries_were_on) / COUNTIF(retries_were_on) AS rescue_rate_on,
            COUNTIF(is_rescued AND NOT retries_were_on) / COUNTIF(NOT retries_were_on) AS rescue_rate_off
        FROM try_again
        GROUP BY business_type
    ),

    shop_try_again AS (
        SELECT shop_id, retries_on_date, SUM(amount_eur) AS try_again_declines_eur
        FROM try_again
        GROUP BY shop_id, retries_on_date
    )

SELECT
    st.shop_id,
    sm.business_type,
    st.retries_on_date IS NULL AS is_never_switched_on,
    st.try_again_declines_eur,
    r.rescue_rate_on,
    r.rescue_rate_off,
    ROUND(st.try_again_declines_eur * (r.rescue_rate_on - r.rescue_rate_off), 2) AS shop_sales_gain_eur,
    ROUND(st.try_again_declines_eur * (r.rescue_rate_on - r.rescue_rate_off)
        * sm.expected_margin_per_100_eur_best / 100, 2) AS platform_profit_eur
FROM shop_try_again AS st
JOIN {{ ref('int_shop_margins') }} AS sm ON st.shop_id = sm.shop_id
JOIN rescue_rates AS r ON sm.business_type = r.business_type