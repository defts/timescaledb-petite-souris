-- utilisation de la mvue
explain analyse
SELECT
    day,
    country_code,
    num_vals(price_stats) as teeth_count,
    ROUND(average(price_stats)::numeric, 2) as avg_price,
    ROUND(approx_percentile(0.50, price_percentiles)::numeric, 2) as p50_price,
    ROUND(approx_percentile(0.95, price_percentiles)::numeric, 2) as p95_price,
    ROUND(approx_percentile(0.99, price_percentiles)::numeric, 2) as p99_price
FROM daily_revenue_stats
WHERE day >= now() - interval '1 month' AND country_code = 'FR'
ORDER BY day DESC;

-- info sur le cagg
SELECT
    view_name,
    materialization_hypertable_name as materialized_table,
    pg_size_pretty(pg_total_relation_size(
        format('%I.%I', materialization_hypertable_schema, materialization_hypertable_name)
    )) as total_size,
    compression_enabled,
    materialized_only
FROM timescaledb_information.continuous_aggregates
WHERE view_name = 'daily_revenue_stats';


-- Afficher les détails de la refresh policy
SELECT
    application_name as policy_name,
    schedule_interval,
    config->>'start_offset' as start_offset,
    config->>'end_offset' as end_offset
FROM timescaledb_information.jobs
WHERE proc_name = 'policy_refresh_continuous_aggregate';


-- CREATE MATERIALIZED VIEW monthly_revenue_stats
-- WITH (timescaledb.continuous, timescaledb.materialized_only = false) AS
SELECT
    time_bucket('1 month', day) AS month,
    country_code,
    rollup(price_stats) as price_stats,
    rollup(price_percentiles) as price_percentiles
FROM daily_revenue_stats
GROUP BY month, country_code
ORDER BY month DESC, country_code ASC;
