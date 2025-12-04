WITH
q1 AS (
    SELECT text_embedding AS v1
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),
q2 AS (
    SELECT text_embedding AS v2
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id DESC
    LIMIT 1
)

SELECT
    t.old_id,
    t.old_text
FROM text t, q1, q2
ORDER BY
    GREATEST(
        cosine_distance(t.text_embedding, q1.v1),
        cosine_distance(t.text_embedding, q2.v2)
    ) ASC,
    t.old_id ASC
LIMIT 10;
