-- Step 1: Select same query vector as SQL Server
WITH q AS (
    SELECT page_embedding AS query_vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
),

-- Step 2: Inner k-NN with pre-filter (TOP 10 among short pages)
new_page AS (
    SELECT
        p.page_id,
        (p.page_embedding <=> q.query_vec) AS distance
    FROM
        page p,
        q
    WHERE
        p.page_len < 1000  -- pre-filter
    ORDER BY
        distance ASC,
        p.page_id ASC
    LIMIT 10
)

-- Step 3: Outer aggregation (count revisions grouped by actor)
SELECT
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM
    new_page np
JOIN
    revision r ON np.page_id = r.rev_page
GROUP BY
    r.rev_user_text
ORDER BY
    cou DESC;
