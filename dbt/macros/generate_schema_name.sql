{#-
    Decides which BigQuery dataset each model is built in.

    dbt's default glues the target's dataset and the layer together:
    dbt_amcdevops + staging -> dbt_amcdevops_staging. That is what we want in dev,
    so every developer gets separate datasets.

    In prod we want the clean layer name alone: staging, intermediate, marts.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
