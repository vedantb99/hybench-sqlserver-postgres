WITH q AS (
    -- Load a query vector
    SELECT page_embedding AS vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM 
    page p
JOIN 
    revision r ON p.page_id = r.rev_page
CROSS JOIN 
    q
WHERE 
    -- Relational filter
    p.page_len < 1000

    AND (
        -- Vector Distance Range 1
        cosine_distance(p.page_embedding, q.vec) BETWEEN 0.1 AND 0.2

        OR

        -- Vector Distance Range 2
        cosine_distance(p.page_embedding, q.vec) BETWEEN 0.4 AND 0.5

        -- Add more OR conditions for more ranges
    )
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;
