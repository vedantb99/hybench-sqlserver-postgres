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
CROSS JOIN q
WHERE
    -- Relational filter: date range
    r.rev_timestamp >= '2010-01-01T00:00:00Z'
    AND r.rev_timestamp <= '2015-01-01T00:00:00Z'
    -- Vector bounded range filter
    AND cosine_distance(t.text_embedding, q.vec)
            BETWEEN 0.2 AND 0.5
ORDER BY
    distance ASC,
    t.old_id ASC;
