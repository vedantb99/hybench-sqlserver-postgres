WITH q AS (
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

SELECT
    t.old_id,
    t.old_text,
    cosine_distance(t.text_embedding, q.vec) AS distance
FROM text t
CROSS JOIN q
WHERE
    -- Range 1
    cosine_distance(t.text_embedding, q.vec) BETWEEN 0.1 AND 0.2
    OR
    -- Range 2
    cosine_distance(t.text_embedding, q.vec) BETWEEN 0.4 AND 0.5
ORDER BY
    distance ASC,
    t.old_id ASC;
