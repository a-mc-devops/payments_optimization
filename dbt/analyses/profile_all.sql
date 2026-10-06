{{ profile_table(ref('stg_bank_payouts')) }}
UNION ALL
{{ profile_table(ref('stg_banks')) }}
UNION ALL
{{ profile_table(ref('stg_fee_rules')) }}
UNION ALL
{{ profile_table(ref('stg_fraud_reports')) }}
UNION ALL
{{ profile_table(ref('stg_payment_attempts')) }}
UNION ALL
{{ profile_table(ref('stg_shops')) }}

ORDER BY table_name