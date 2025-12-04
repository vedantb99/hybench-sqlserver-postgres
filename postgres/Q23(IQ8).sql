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
FROM page p
JOIN revision r ON p.page_id = r.rev_page
CROSS JOIN q
WHERE
    -- Relational filter
    p.page_len < 1000                 -- {len}
    -- Vector bounded range filter
    AND cosine_distance(p.page_embedding, q.vec)
            BETWEEN 0.2 AND 0.5       -- {d} AND {d*}
GROUP BY
    r.rev_user_text
ORDER BY
    cou DESC;
