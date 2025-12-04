WITH q AS (
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)

SELECT
    EXTRACT(YEAR FROM r.rev_timestamp::timestamptz) AS year,
    t.old_id,
    cosine_distance(t.text_embedding, q.vec) AS distance
FROM text t
JOIN revision r ON t.old_id = r.rev_text_id
CROSS JOIN q
WHERE
    -- Filter 1: year range
    EXTRACT(YEAR FROM r.rev_timestamp::timestamptz)
        BETWEEN 2010 AND 2015   -- {YEARL},{YEARH}

    -- Filter 2: distance range (bounded / annulus)
    AND cosine_distance(t.text_embedding, q.vec)
            BETWEEN 0.2 AND 0.5   -- {d},{d*}
ORDER BY
    year DESC,
    distance ASC;
