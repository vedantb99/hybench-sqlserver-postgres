-- Step 1: Choose the same query vector as SQL Server
WITH q AS (
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

-- Step 2: Hybrid range search (distance < 0.5 AND timestamp in range)
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
    -- SQL Filter 1: Timestamp range
    r.rev_timestamp >= '2010-01-01T00:00:00Z'
    AND r.rev_timestamp <= '2015-01-01T00:00:00Z'
    -- SQL Filter 2: Vector range search
    AND (t.text_embedding <=> q.query_vec) < 0.5
ORDER BY
    distance ASC,
    t.old_id ASC;
