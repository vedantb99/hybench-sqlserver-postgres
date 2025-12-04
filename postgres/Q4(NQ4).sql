-- Step 1: Select the same query vector as SQL Server
WITH q AS (
    SELECT page_embedding AS query_vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

-- Step 2: Hybrid filter (page_len < 1000 AND distance < 0.5)
SELECT
    p.page_id,
    p.page_title,
    (p.page_embedding <=> q.query_vec) AS distance
FROM
    page p,
    q
WHERE
    p.page_len < 1000
    AND (p.page_embedding <=> q.query_vec) < 0.5
ORDER BY
    distance ASC,
    p.page_id ASC
LIMIT 10;  -- optional (SQL Server uses TOP)
