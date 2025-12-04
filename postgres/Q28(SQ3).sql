WITH q AS (
    -- Load a real query vector (equivalent to SQL Server TOP 1)
    SELECT page_embedding AS vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
),

ranked AS (
    SELECT
        p.page_id,
        p.page_title,
        ROW_NUMBER() OVER (
            ORDER BY
                cosine_distance(p.page_embedding, q.vec) ASC,
                p.page_id ASC
        ) AS rank
    FROM page p
    CROSS JOIN q
    WHERE p.page_len < 1000      -- {len}
)

SELECT
    page_id,
    page_title,
    rank
FROM ranked
WHERE rank IN (1, 5, 10, 50, 100)   -- {r1, r2, …}
ORDER BY rank ASC;
