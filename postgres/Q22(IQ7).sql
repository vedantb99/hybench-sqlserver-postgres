WITH q AS (
    SELECT page_embedding AS vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM (
    -- Inner query: Pre-filter → Sort → Paginate
    SELECT
        p.page_id,
        cosine_distance(p.page_embedding, q.vec) AS distance
    FROM page p, q
    WHERE p.page_len < 1000                      -- {len}
    ORDER BY distance ASC, p.page_id ASC
    OFFSET 10                                    -- l = 11 → offset = 10
    LIMIT 10                                     -- r = 20 → r-l+1 = 10
) AS new_page
JOIN revision r ON new_page.page_id = r.rev_page
GROUP BY r.rev_user_text
ORDER BY cou DESC;
