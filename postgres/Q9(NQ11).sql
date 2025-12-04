-- Step 1: Select the same query vector as SQL Server
WITH q AS (
    SELECT page_embedding AS query_vec
    FROM page
    WHERE page_embedding IS NOT NULL
    ORDER BY page_id
    LIMIT 1
),

-- Step 2: Inner k-NN (Top 10 nearest pages)
filtered_pages AS (
    SELECT
        p.page_id,
        (p.page_embedding <=> q.query_vec) AS distance
    FROM
        page p,
        q
    ORDER BY
        distance ASC,
        p.page_id ASC
    LIMIT 10
)

-- Step 3: Aggregate by YEAR
SELECT
    EXTRACT(YEAR FROM r.rev_timestamp::timestamptz) AS year,
    COUNT(*) AS count
FROM
    revision r
JOIN
    filtered_pages fp ON r.rev_page = fp.page_id
GROUP BY
    year
ORDER BY
    year DESC;
