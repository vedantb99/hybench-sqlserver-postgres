WITH q AS (
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
FROM page p, q
WHERE
    p.page_len < 1000      -- {len}
ORDER BY
    distance ASC,
    p.page_id ASC
OFFSET 10                  -- l = 11 → offset = 10
LIMIT 10;                  -- r = 20 → r-l+1 = 10
