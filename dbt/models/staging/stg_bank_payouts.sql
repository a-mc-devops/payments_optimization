SELECT
    payout_id,
    shop_id,
    bank_id,
    payment_date,
    payout_date,
    payment_count,
    gross_eur,
    fees_eur AS bank_fees_eur,
    net_eur

FROM {{ source('raw', 'bank_payouts') }}