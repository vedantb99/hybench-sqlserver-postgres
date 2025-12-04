WITH q AS (
    -- 1. Get the query vector
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),
ranked AS (
    SELECT
        t.old_id,

        -- 2. Extract year safely
        SUBSTRING(r.rev_timestamp, 1, 4)::int AS year,

        -- 3. Compute cosine distance
        (t.text_embedding <=> q.query_vec) AS distance,

        -- 4. Partitioned ranking: top K per year
        ROW_NUMBER() OVER (
            PARTITION BY SUBSTRING(r.rev_timestamp, 1, 4)
            ORDER BY (t.text_embedding <=> q.query_vec), t.old_id
        ) AS rank
    FROM
        text t
    JOIN
        revision r ON t.old_id = r.rev_id
    JOIN
        q ON TRUE
    WHERE
        -- 5. Year range filter
        SUBSTRING(r.rev_timestamp, 1, 4)::int BETWEEN 2010 AND 2015
)
-- 6. Select only the top K per year
SELECT
    year,
    old_id,
    distance
FROM
    ranked
WHERE
    rank <= 10
ORDER BY
    year DESC,
    distance ASC;
