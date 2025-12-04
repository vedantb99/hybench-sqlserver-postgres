WITH q AS (
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
)
SELECT
    r.rev_user_text AS rev_actor,
    SUM(r.rev_minor_edit::int) AS total_minor_edits
FROM
    text t
JOIN
    revision r ON t.old_id = r.rev_id
JOIN
    q ON TRUE
WHERE
    (t.text_embedding <=> q.query_vec) < 0.5
GROUP BY
    r.rev_user_text
ORDER BY
    total_minor_edits DESC;
