WITH q AS (
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

SELECT
    r.rev_id,
    cosine_distance(t.text_embedding, q.vec) AS distance
FROM text t
JOIN revision r ON t.old_id = r.rev_text_id
CROSS JOIN q         -- IMPORTANT: add q here
WHERE
    r.rev_timestamp >= '2010-01-01T00:00:00Z'
    AND r.rev_timestamp <= '2015-01-01T00:00:00Z'
ORDER BY
    distance ASC,
    t.old_id ASC
OFFSET 10
LIMIT 10;
