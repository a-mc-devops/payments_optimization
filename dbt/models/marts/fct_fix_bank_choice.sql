WITH
    bank_payments AS (
        SELECT
        p.shop_id,
        p.business_type,
        p.amount_eur,
        p.final_outcome = 'approved' AS is_approved,
        p.card_country = b.bank_country AS is_local_bank 
        FROM {{ ref('int_payments')}} AS p
        JOIN {{ ref('stg_banks')}} AS b
            ON p.bank_id = b.bank_id
        WHERE p.card_country IN ('NL', 'DE', 'FR') AND p.final_outcome != 'gave_up'
    )
    ,
    approval_rates AS (
        SELECT
            business_type,
            COUNTIF(is_approved AND is_local_bank) / COUNTIF(is_local_bank) AS approval_rate_local,
            COUNTIF(is_approved AND NOT is_local_bank) / COUNTIF(NOT is_local_bank) AS approval_rate_other            
        FROM bank_payments
        GROUP BY business_type
    )
    ,
    shop_moved_payments AS (
        SELECT
            shop_id,
            SUM(CASE WHEN NOT is_local_bank THEN amount_eur ELSE 0 END) AS moved_payments_eur
        FROM bank_payments
        GROUP BY shop_id
    )
    ,
    fee_change AS (
        SELECT
            ap.shop_id,
            SUM(ROUND(ap.amount_eur * fr.bank_fee_pct / 100 + fr.bank_fixed_fee_eur, 2) - ap.expected_bank_fee_eur) AS fee_change_eur
        FROM {{ ref('int_approved_payments') }} AS ap
        JOIN {{ ref('int_payments') }} AS p
            ON ap.payment_id = p.payment_id             
        JOIN {{ ref('stg_banks') }} AS lb
            ON p.card_country = lb.bank_country        
        LEFT JOIN {{ ref('stg_fee_rules') }} AS fr
            ON fr.bank_id = lb.bank_id                
            AND fr.card_type = ap.card_type
            AND fr.card_region = ap.card_region
            AND ap.attempt_date >= fr.valid_from
            AND (fr.valid_to IS NULL OR ap.attempt_date <= fr.valid_to)
        WHERE p.card_country IN ('NL', 'DE', 'FR')
            AND ap.bank_id != lb.bank_id     
            GROUP BY ap.shop_id           
        )        

SELECT
    sm.shop_id, 
    sm.business_type, 
    mp.moved_payments_eur, 
    ar.approval_rate_local, 
    ar.approval_rate_other,
    ROUND(mp.moved_payments_eur * (ar.approval_rate_local - ar.approval_rate_other), 2) AS shop_sales_gain_eur,
    ROUND(fc.fee_change_eur, 2) AS fee_change_eur,
    ROUND(mp.moved_payments_eur * (ar.approval_rate_local - ar.approval_rate_other) * sm.expected_margin_per_100_eur_best / 100 - fc.fee_change_eur, 2) AS platform_profit_eur
FROM {{ ref('int_shop_margins') }} AS sm
JOIN shop_moved_payments AS mp
    ON sm.shop_id = mp.shop_id
JOIN fee_change AS fc
    ON sm.shop_id = fc.shop_id
JOIN approval_rates AS ar
    ON sm.business_type = ar.business_type
