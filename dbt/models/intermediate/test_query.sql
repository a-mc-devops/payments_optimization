SELECT
    payment_id,
    CASE WHEN outcome = 'approved' THEN MAX_BY(attempt_id, attempt_number)END AS approved_attempt_id,
    COUNT(attempt_number) AS attempt_count
FROM {{ ref('int_attempts') }}
GROUP BY payment_id