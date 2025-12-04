-- Step 1: Pick the same query vector as SQL Server
WITH q AS (
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

-- Step 2: Pre-filter + distance + ordering + limit
SELECT
    r.rev_id,
    (t.text_embedding <=> q.query_vec) AS distance
FROM
    text t
JOIN
    revision r ON t.old_id = r.rev_text_id
JOIN
    q ON TRUE
WHERE
    r.rev_timestamp >= '2010-01-01T00:00:00Z'
    AND r.rev_timestamp <= '2015-01-01T00:00:00Z'
ORDER BY
    distance ASC,
    t.old_id ASC
LIMIT 10;
