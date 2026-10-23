WITH
    fix_options AS (
        SELECT
            'Reprice loss-making shops' AS fix_option,
            SUM(extra_price_income_eur) AS platform_profit_eur_low,
            SUM(extra_price_income_eur) AS platform_profit_eur_best,
            SUM(extra_price_income_eur) AS platform_profit_eur_high,
            0 AS shop_sales_eur,
            'Shops accept the new price' AS depends_on
        FROM {{ ref('fct_fix_repricing') }}

        UNION ALL

        SELECT
            '3D Secure on every payment',
            SUM(check_every_platform_profit_eur_low),
            SUM(check_every_platform_profit_eur_best),
            SUM(check_every_platform_profit_eur_high),
            SUM(check_every_shop_sales_eur),
            'Nothing outside the platform'
        FROM {{ ref('fct_fix_three_ds') }}

        UNION ALL

        SELECT
            '3D Secure on no payment',
            SUM(check_none_platform_profit_eur_low),
            SUM(check_none_platform_profit_eur_best),
            SUM(check_none_platform_profit_eur_high),
            SUM(check_none_shop_sales_eur),
            'Nothing outside the platform'
        FROM {{ ref('fct_fix_three_ds') }}

        UNION ALL

        SELECT
            'Retries on at the 6 never-on shops',
            SUM(platform_profit_eur),
            SUM(platform_profit_eur),
            SUM(platform_profit_eur),
            SUM(shop_sales_gain_eur),
            'Nothing outside the platform'
        FROM {{ ref('fct_fix_retries') }}
        WHERE is_never_switched_on

        UNION ALL

        SELECT
            'Route Dutch, German and French cards to their own-country bank',
            SUM(platform_profit_eur),
            SUM(platform_profit_eur),
            SUM(platform_profit_eur),
            SUM(shop_sales_gain_eur),
            'The new bank accepts the shop'
        FROM {{ ref('fct_fix_bank_choice') }}
        WHERE platform_profit_eur > 0 
    )

SELECT
    RANK() OVER (ORDER BY platform_profit_eur_low DESC) AS fix_rank,
    fix_option,
    ROUND(platform_profit_eur_low, 2) AS platform_profit_eur_low,
    ROUND(platform_profit_eur_best, 2) AS platform_profit_eur_best,
    ROUND(platform_profit_eur_high, 2) AS platform_profit_eur_high,
    ROUND(shop_sales_eur, 2) AS shop_sales_eur,
    depends_on
FROM fix_options