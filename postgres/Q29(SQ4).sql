WITH q AS (
    -- Load a real query vector (equivalent to SQL Server TOP 1)
    SELECT page_embedding AS vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

SELECT
    p.page_id,
    p.page_title,
    cosine_distance(p.page_embedding, q.vec) AS distance
FROM page p
CROSS JOIN q
WHERE
    -- Filter 1: Relational pre-filter
    p.page_len < 1000                -- {len}

    AND (
        -- Vector Range 1
        cosine_distance(p.page_embedding, q.vec)
            BETWEEN 0.1 AND 0.2      -- {d1_min}, {d1_max}

        OR

        -- Vector Range 2
        cosine_distance(p.page_embedding, q.vec)
            BETWEEN 0.4 AND 0.5      -- {d2_min}, {d2_max}

        -- Add more ranges here:
        -- OR cosine_distance(...) BETWEEN x AND y
    )
ORDER BY
    distance ASC,
    p.page_id ASC;
