WITH q AS (
    -- Load query vector
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),
ranked AS (
    SELECT
        t.old_id,
        (LEFT(r.rev_timestamp, 4))::INT AS year,
        cosine_distance(t.text_embedding, q.vec) AS distance,

        ROW_NUMBER() OVER (
            PARTITION BY (LEFT(r.rev_timestamp, 4))::INT
            ORDER BY cosine_distance(t.text_embedding, q.vec), t.old_id
        ) AS rank
    FROM text t
    JOIN revision r
        ON t.old_id = r.rev_text_id
    CROSS JOIN q
    WHERE (LEFT(r.rev_timestamp, 4))::INT BETWEEN 2010 AND 2015   -- {YEARL}, {YEARH}
)

SELECT
    year,
    old_id,
    distance
FROM ranked
WHERE rank IN (1, 5, 10, 20)     -- {r1, r2, r3...}
ORDER BY year DESC, distance ASC;
