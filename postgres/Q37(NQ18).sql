WITH
-- Bring q1 and q2 vectors
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

-- Inner (forbidden) set: top k nearest to q2
forbidden AS (
    SELECT
        t.old_id
    FROM
        text t, q2
    ORDER BY
        t.text_embedding <-> q2.vec2
    LIMIT 10
)

-- Outer query: top k nearest to q1 but excluding forbidden
SELECT
    t.old_id,
    t.old_text,
    (t.text_embedding <-> q1.vec1) AS distance
FROM
    text t, q1
WHERE
    t.old_id NOT IN (SELECT old_id FROM forbidden)
ORDER BY
    distance ASC,
    t.old_id ASC
LIMIT 10;
