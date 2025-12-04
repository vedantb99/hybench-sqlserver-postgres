WITH q AS (
    -- Load a real query vector (same as SQL Server TOP 1)
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),

ranked AS (
    SELECT
        r.rev_id,
        ROW_NUMBER() OVER (
            ORDER BY
                cosine_distance(t.text_embedding, q.vec) ASC,
                t.old_id ASC
        ) AS rank
    FROM text t
    JOIN revision r
        ON t.old_id = r.rev_text_id
    CROSS JOIN q
    WHERE
        -- Date pre-filter (rev_timestamp is TEXT → cast to timestamptz)
        r.rev_timestamp::timestamptz >= '2010-01-01T00:00:00Z'
        AND r.rev_timestamp::timestamptz <= '2015-01-01T00:00:00Z'
)

SELECT
    rev_id,
    rank
FROM ranked
WHERE rank IN (1, 5, 10, 50, 100)    -- {r1, r2, …}
ORDER BY rank ASC;
