WITH q AS (
    SELECT text_embedding AS v
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

SELECT
    t.old_id,
    t.old_text,
    cosine_distance(t.text_embedding, q.v) AS distance
FROM text t, q
WHERE
    cosine_distance(t.text_embedding, q.v)
        BETWEEN 0.2 AND 0.5   -- d and d* values
ORDER BY
    distance ASC,
    t.old_id ASC;

