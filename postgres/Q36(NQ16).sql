WITH
-- 1. Fetch two different query vectors
q1 AS (
    SELECT text_embedding AS vec1
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),
q2 AS (
    SELECT text_embedding AS vec2
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id DESC
    LIMIT 1
),

-- 2. First k-NN search (restricted to old_id <= 500k)
top_q1 AS (
    SELECT
        t.old_id,
        t.old_text,
        cosine_distance(t.text_embedding, q1.vec1) AS distance
    FROM text t, q1
    WHERE t.old_id <= 500000
    ORDER BY t.text_embedding <-> q1.vec1
    LIMIT 10
),

-- 3. Second k-NN search (restricted to old_id <= 500k)
top_q2 AS (
    SELECT
        t.old_id,
        t.old_text,
        cosine_distance(t.text_embedding, q2.vec2) AS distance
    FROM text t, q2
    WHERE t.old_id <= 500000
    ORDER BY t.text_embedding <-> q2.vec2
    LIMIT 10
)

-- 4. Combine + deduplicate + take final top 10
SELECT
    old_id,
    old_text,
    MIN(distance) AS best_distance
FROM (
    SELECT * FROM top_q1
    UNION ALL
    SELECT * FROM top_q2
) AS combined
GROUP BY old_id, old_text
ORDER BY best_distance ASC, old_id ASC
LIMIT 10;
