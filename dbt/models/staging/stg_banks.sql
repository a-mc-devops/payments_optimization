SELECT
    bank_id,
    bank_name,
    country AS bank_country
    
FROM {{ source('raw', 'banks') }}