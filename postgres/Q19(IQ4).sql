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
    -- relational filter
    p.page_len < 1000              -- {len}
    -- vector bounded range filter
    AND cosine_distance(p.page_embedding, q.vec)
            BETWEEN 0.2 AND 0.5    -- {d} AND {d*}
ORDER BY
    distance ASC,
    p.page_id ASC;
