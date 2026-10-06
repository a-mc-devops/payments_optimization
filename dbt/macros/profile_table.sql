{% macro profile_table(relation) %}
    {% set columns = adapter.get_columns_in_relation(relation ) %}
    {% for col in columns %}
        SELECT
            '{{ relation.identifier }}' AS table_name,
            '{{ col.name }}' AS column_name,
            '{{ col.dtype }}' AS data_type,
            COUNT(*) AS row_count,
            COUNTIF({{ col.name }} IS NULL) AS empty_values,
            COUNT(DISTINCT {{ col.name }}) AS distinct_values,
            {% if col.dtype in ['NUMERIC', 'INT64', 'INTEGER', 'FLOAT64', 'DATE', 'TIMESTAMP'] %}
                CAST(MIN( {{ col.name }} ) AS STRING) AS min_value,
                CAST(MAX( {{ col.name }} ) AS STRING) AS max_value
            {% else %}
                CAST(NULL AS STRING) AS min_value,
                CAST(NULL AS STRING) AS max_value
            {% endif %}
        FROM {{ relation }}
        {% if not loop.last %} UNION ALL {% endif %}
    {% endfor %}
{% endmacro %}