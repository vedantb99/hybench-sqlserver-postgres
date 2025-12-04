WITH q AS (
    -- 1. Grab the query vector (same as SQL Server)
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)
SELECT
    -- Extract year safely (works for any timestamp format)
    SUBSTRING(r.rev_timestamp, 1, 4)::int AS year,
    t.old_id,
    -- Compute cosine distance
    (t.text_embedding <=> q.query_vec) AS distance
FROM
    text t
JOIN
    revision r ON t.old_id = r.rev_id
JOIN
    q ON TRUE
WHERE
    -- Year range filter
    SUBSTRING(r.rev_timestamp, 1, 4)::int BETWEEN 2010 AND 2015

    -- Distance threshold filter (range search → no index)
    AND (t.text_embedding <=> q.query_vec) <= 0.5
ORDER BY
    year DESC,
    distance ASC;
