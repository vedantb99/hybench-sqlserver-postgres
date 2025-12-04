WITH q AS (
    -- Load the query vector
    SELECT page_embedding AS vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
),
ranked_pages AS (
    SELECT 
        p.page_id,
        ROW_NUMBER() OVER (
            ORDER BY cosine_distance(p.page_embedding, q.vec), p.page_id
        ) AS rank
    FROM page p
    CROSS JOIN q
    WHERE 
        p.page_len < 1000   -- {len}
),
filtered_page AS (
    SELECT page_id
    FROM ranked_pages
    WHERE rank IN (1, 5, 10, 50, 100)   -- {r1, r2, ...}
)

SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM filtered_page fp
JOIN revision r
    ON fp.page_id = r.rev_page
GROUP BY r.rev_user_text
ORDER BY cou DESC;
