WITH q AS (
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),

ranked_pages AS (
    SELECT
        t.old_id,
        EXTRACT(YEAR FROM r.rev_timestamp::timestamptz) AS year,
        cosine_distance(t.text_embedding, q.vec) AS distance,

        ROW_NUMBER() OVER (
            PARTITION BY EXTRACT(YEAR FROM r.rev_timestamp::timestamptz)
            ORDER BY
                cosine_distance(t.text_embedding, q.vec) ASC,
                t.old_id ASC
        ) AS rank
    FROM text t
    JOIN revision r ON t.old_id = r.rev_text_id
    CROSS JOIN q
    WHERE
        EXTRACT(YEAR FROM r.rev_timestamp::timestamptz)
            BETWEEN 2010 AND 2015
)

SELECT
    year,
    old_id,
    distance
FROM ranked_pages
WHERE rank BETWEEN 11 AND 20
ORDER BY year DESC, distance ASC;
