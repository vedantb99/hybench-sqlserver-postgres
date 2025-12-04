-- Step 1: Pick the same query vector as SQL Server
WITH q AS (
    SELECT page_embedding AS query_vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

-- Step 2: PRE-FILTER → ORDER → LIMIT
SELECT
    t.page_id,
    t.page_title,
    (t.page_embedding <=> q.query_vec) AS distance
FROM
    page t, q
WHERE
    t.page_len < 1000
ORDER BY
    distance ASC,
    t.page_id ASC
LIMIT 10;
