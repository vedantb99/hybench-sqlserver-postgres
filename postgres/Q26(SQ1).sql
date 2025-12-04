WITH q AS (
    -- load one real query vector (SQL Server TOP 1)
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),

ranked AS (
    SELECT
        t.old_id,
        t.old_text,
        ROW_NUMBER() OVER (
            ORDER BY
                cosine_distance(t.text_embedding, q.vec) ASC,
                t.old_id ASC
        ) AS rank
    FROM text t
    CROSS JOIN q
)

SELECT
    old_id,
    old_text,
    rank
FROM ranked
WHERE rank IN (1, 5, 10, 50, 100)   -- {r1, r2, …, rn}
ORDER BY rank;
