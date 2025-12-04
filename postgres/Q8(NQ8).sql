-- Step 1: Select same query vector as SQL Server
WITH q AS (
    SELECT page_embedding AS query_vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
)

-- Step 2: Hybrid Range Search + Aggregation
SELECT
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM
    page p
JOIN
    revision r ON p.page_id = r.rev_page
JOIN
    q ON TRUE
WHERE
    -- Relational Filter
    p.page_len < 1000
    -- Vector Range Filter
    AND (p.page_embedding <=> q.query_vec) < 0.5
GROUP BY
    r.rev_user_text
ORDER BY
    cou DESC;

