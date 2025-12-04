-- Step 1: pick the same query vector as SQL Server
WITH q AS (
    SELECT text_embedding AS query_vec
    FROM text
    WHERE text_embedding IS NOT NULL
    ORDER BY old_id
    LIMIT 1
),

-- Step 2: indexed k-NN search (top 10)
topk AS (
    SELECT old_id
    FROM text, q
    ORDER BY text_embedding <=> q.query_vec
    LIMIT 10
)

-- Step 3: aggregate minor edits per actor
SELECT
    r.rev_user_text AS rev_actor,
    SUM(r.rev_minor_edit::int) AS total_minor_edits
FROM
    topk t
JOIN
    revision r ON t.old_id = r.rev_id
GROUP BY
    r.rev_user_text
ORDER BY
    total_minor_edits DESC;
