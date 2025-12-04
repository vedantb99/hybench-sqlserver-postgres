-- Step 1: Pick the same first vector as SQL Server
WITH q AS (
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

-- Step 2: Perform full table scan k-NN using cosine (<=>)
SELECT
    t.old_id,
    t.old_text,
    (t.text_embedding <=> q.query_vec) AS distance   -- cosine distance
FROM
    text t, q
WHERE
    t.text_embedding IS NOT NULL
ORDER BY
    distance ASC,
    t.old_id ASC
LIMIT 10;   -- same as @k
