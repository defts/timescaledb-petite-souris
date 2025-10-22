-- ============================================================================
-- DÉMO HYPERFUNCTIONS : time_bucket_gapfill + stats_agg + percentiles
-- ============================================================================
-- Cette démo montre les hyperfunctions TimescaleDB les plus utiles :
-- 1. time_bucket vs PostgreSQL standard (EPOCH)
-- 2. time_bucket_gapfill pour séries complètes
-- 3. stats_agg pour calculer toutes les stats en un scan
-- 4. Function pipelines (->)
-- 5. Percentiles approximatifs
--

-- Sans time_bucket
SELECT
    to_timestamp(floor((extract('epoch' from collected_at) / 1800)) * 1800) AS period, -- période de 30 minutes
    COUNT(*) as teeth_count
FROM tooth_loss
WHERE collected_at >= '2025-10-15' AND collected_at < '2025-10-16'
  AND country_code = 'FR'
GROUP BY period
ORDER BY period ASC;


-- Avec time_bucket
SELECT
    time_bucket('30 minutes', collected_at) AS period, -- Fini les date_trunc / EXTRACT !
    COUNT(*) as teeth_count
FROM tooth_loss
WHERE collected_at >= '2025-10-15' AND collected_at < '2025-10-16'
  AND country_code = 'FR'
GROUP BY period
ORDER BY period ASC;

-- time_bucket_gapfill
SELECT
    time_bucket_gapfill('30 minutes', collected_at) AS period,
--     interpolate(COUNT(*)), -- Fill in missing values by linear interpolation
--     locf(COUNT(*)), -- Fill in missing values by carrying the last observed value forward
    COUNT(*) as teeth_count,
    SUM(COUNT(*)) OVER (ORDER BY time_bucket_gapfill('30 minutes', collected_at)) as cumulative_teeth
FROM tooth_loss
WHERE collected_at >= '2025-10-15' AND collected_at < '2025-10-16'
  AND country_code = 'FR'
GROUP BY period
ORDER BY period ASC;

-- sans stats_agg
SELECT
    country_code,
    ROUND(AVG(price)::numeric, 2) as moyenne,
    ROUND(STDDEV(price)::numeric, 2) as ecart_type,
    ROUND(VARIANCE(price)::numeric, 2) as variance,
    ROUND(SUM(price)::numeric, 2) as total
FROM tooth_loss
WHERE collected_at >= '2025-10-15' AND collected_at < '2025-10-16'
GROUP BY country_code
ORDER BY country_code;

-- avec stats_agg
WITH stats as (
    SELECT
        country_code,
        stats_agg(price) as stats_agg,
        percentile_agg(price) as percentile_agg
    FROM tooth_loss
    WHERE collected_at >= '2025-10-15' AND collected_at < '2025-10-16'
    GROUP BY country_code
)
SELECT
    country_code,
    ROUND((stats_agg -> average())::numeric, 2) as moyenne,
    ROUND((stats_agg -> stddev())::numeric, 2) as ecart_type,
    ROUND(variance(stats_agg)::numeric, 2) as variance,
    ROUND(sum(stats_agg)::numeric, 2) as total,
    ROUND((percentile_agg -> approx_percentile(0.50))::numeric, 2) as median,
    ROUND(approx_percentile( 0.90, percentile_agg)::numeric, 2) as p90
FROM stats
ORDER BY country_code;


-- average - Calculate the average from a one-dimensional statistical aggregate
-- kurtosis - Calculate the kurtosis from a one-dimensional statistical aggregate
-- num_vals - Calculate the number of values in a one-dimensional statistical aggregate
-- skewness - Calculate the skewness from a one-dimensional statistical aggregate
-- stddev - Calculate the standard deviation from a one-dimensional statistical aggregate
-- sum - Calculate the sum from a one-dimensional statistical aggregate
-- variance - Calculate the variance from a one-dimensional statistical aggregate