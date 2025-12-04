-- Step 1: Select the same query vector as SQL Server (first vector by old_id)
WITH q AS (
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

-- Step 2: Range search (distance < d) using cosine distance (<=>)
SELECT
    t.old_id,
    t.old_text,
    (t.text_embedding <=> q.query_vec) AS distance
FROM
    text t, q
WHERE
    (t.text_embedding <=> q.query_vec) < 0.05   -- your {d}
ORDER BY
    distance ASC,
    t.old_id ASC;
