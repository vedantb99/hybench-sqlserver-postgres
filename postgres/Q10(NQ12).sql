-- Step 1: Select same query vector as SQL Server
WITH q AS (
    SELECT page_embedding AS query_vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

-- Step 2: Range Search + Join + Aggregate
SELECT
    EXTRACT(YEAR FROM r.rev_timestamp::timestamptz) AS year,
    COUNT(*) AS count
FROM
    page p
JOIN
    revision r ON p.page_id = r.rev_page
JOIN
    q ON TRUE
WHERE
    (p.page_embedding <=> q.query_vec) < 0.5   -- Range threshold: {d}
GROUP BY
    year
ORDER BY
    year DESC;
