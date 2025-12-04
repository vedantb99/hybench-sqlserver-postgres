WITH q AS (
    -- 1. Load query vector
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
JOIN revision r 
    ON t.old_id = r.rev_text_id
CROSS JOIN q
WHERE 
    -- 2. Date filter (must be before distance checks)
    r.rev_timestamp::timestamptz >= '2010-01-01T00:00:00Z'
    AND r.rev_timestamp::timestamptz <= '2015-01-01T00:00:00Z'

    -- 3. Multi-range cosine distance filtering
    AND (
        cosine_distance(t.text_embedding, q.vec) BETWEEN 0.1 AND 0.2
        OR
        cosine_distance(t.text_embedding, q.vec) BETWEEN 0.4 AND 0.5
        -- Add more OR ranges as needed
    )
ORDER BY 
    distance ASC,
    t.old_id ASC;
