WITH
q AS (
    SELECT text_embedding AS vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),

top_r AS (
    SELECT
        t.old_id,
        t.old_text,
        cosine_distance(t.text_embedding, q.vec) AS distance
    FROM text t, q
    ORDER BY t.text_embedding <-> q.vec
    LIMIT 20     -- r = 20
)

SELECT
    old_id,
    old_text
FROM top_r
ORDER BY distance ASC, old_id ASC
OFFSET 10        -- l-1 = 11-1 = 10
LIMIT 10;        -- r-l+1 = 10 results (11..20)
