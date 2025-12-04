-- 1. Pick a real query vector
WITH qvec AS (
    SELECT text_embedding AS q
    FROM text
    ORDER BY random()
    LIMIT 1
),
dist AS (
    SELECT
        (t.text_embedding <-> qvec.q) AS d
    FROM text t, qvec
)
SELECT 
    MIN(d)     AS min_distance,
    MAX(d)     AS max_distance,
    AVG(d)     AS avg_distance,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY d) AS d25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY d) AS d50,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY d) AS d75
FROM dist;
WITH 
-- pick a real query vector
qvec AS (
    SELECT text_embedding AS q
    FROM text
    ORDER BY random()
    LIMIT 1
),

-- compute dynamic distance stats
dist_stats AS (
    SELECT 
        PERCENTILE_CONT(0.40) WITHIN GROUP (ORDER BY (t.text_embedding <-> qvec.q)) AS d1_low,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY (t.text_embedding <-> qvec.q)) AS d1_high,
        PERCENTILE_CONT(0.60) WITHIN GROUP (ORDER BY (t.text_embedding <-> qvec.q)) AS d2_low,
        PERCENTILE_CONT(0.70) WITHIN GROUP (ORDER BY (t.text_embedding <-> qvec.q)) AS d2_high
    FROM text t, qvec
),

ranked_pages AS (
    SELECT 
        t.old_id,
        EXTRACT(YEAR FROM r.rev_timestamp::timestamp) AS year,
        (t.text_embedding <-> qvec.q) AS distance,
        s.*
    FROM text t
    JOIN revision r ON t.old_id = r.rev_id
    CROSS JOIN qvec
    CROSS JOIN dist_stats s
    WHERE (
           (t.text_embedding <-> qvec.q BETWEEN s.d1_low AND s.d1_high)
        OR (t.text_embedding <-> qvec.q BETWEEN s.d2_low AND s.d2_high)
    )
)

SELECT 
    year,
    old_id,
    distance
FROM ranked_pages
ORDER BY 
    year DESC,
    distance ASC
LIMIT 50;
