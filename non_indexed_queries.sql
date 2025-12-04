-- NQ2 Range Search,NO,Index API mandates TOP_N; cannot handle distance thresholds.
USE index_hybench_100k;



-- 1. Define our distance threshold and query vector
DECLARE @distance_threshold FLOAT = 0.5; -- Example distance. {d}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector from the table to search with
SELECT TOP 1
    @query_vector = text_embedding
FROM
    dbo.text
WHERE
    text_embedding IS NOT NULL
ORDER BY
    old_id;

PRINT '--- Running a range search (distance < 0.5). This will be VERY SLOW. ---';

-- 3. Run the range search query
-- This translates the Postgres query
SELECT
    t.old_id,
    t.old_text,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM
    dbo.text AS t
WHERE
    -- This is the translation of: text_embedding {op} '{q}' < {d}
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) < @distance_threshold
ORDER BY
    distance ASC,   -- Primary sort: ORDER BY text_embedding {op} '{q}'
    t.old_id ASC;   -- Secondary sort (tie-breaker)



--      ### NEXT QUERY ###


-- Q3,Pre-filtered k-NN,NO,Index is Post-filter; Pre-filtering requires full scan for correctness.

USE index_hybench_100k; -- Use your 100k indexed database


-- 1. Enable Preview Features
ALTER DATABASE SCOPED CONFIGURATION
SET PREVIEW_FEATURES = ON;


-- 2. Define parameters
DECLARE @k INT = 10;
DECLARE @page_length_limit INT = 1000;
DECLARE @query_vector VECTOR(384);

-- 3. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding
FROM dbo.page
WHERE page_embedding IS NOT NULL
ORDER BY page_id;

PRINT '--- Running Q3 (Fast, Post-Filter) using VECTOR_SEARCH. ---';

-- 4. Run the query
SELECT
    t.page_id,
    t.page_title,
    s.distance AS cosine_distance
FROM
    VECTOR_SEARCH(
        TABLE = dbo.page AS t,
        COLUMN = page_embedding,
        SIMILAR_TO = @query_vector,
        METRIC = 'cosine',
        TOP_N = @k -- Find top 10 *first*
    ) AS s
WHERE
    t.page_len < @page_length_limit -- Apply filter *after*
ORDER BY
    s.distance ASC,
    t.page_id ASC;


-- ### NEXT QUERY ###

--Q4,Hybrid Range,NO,Cannot handle simultaneous relational and vector distance range filters.

USE index_hybench_100k; -- 

-- 1. Define parameters
DECLARE @distance_threshold FLOAT = 0.5; -- Example for {d}
DECLARE @page_length_limit INT = 1000; -- Example for {len}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector from the page table
SELECT TOP 1
    @query_vector = page_embedding
FROM
    dbo.page
WHERE
    page_embedding IS NOT NULL
ORDER BY
    page_id;

PRINT '--- Running Q4: Hybrid Filter (page_len < 1000 AND distance < 0.5). ---';
PRINT '--- This will be VERY SLOW (full table scan) on ALL databases. ---';

-- 3. Run the query
SELECT
    p.page_id,
    p.page_title,
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) AS distance
FROM
    dbo.page AS p
WHERE
    -- This is the translation of the hybrid WHERE clause
    p.page_len < @page_length_limit
    AND
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) < @distance_threshold
ORDER BY
    distance ASC,   -- ORDER BY page_embedding {op} '{q}'
    p.page_id ASC;  -- Tie-breaker


-- ### NEXT QUERY ###

-- NQ5 Pre-filtered k-NN,NO,Relational Join must happen before ranking (Pre-filter logic).


USE index_hybench_100k; -- 

-- 1. Define parameters
DECLARE @distance_threshold FLOAT = 0.5; -- Example for {d}
DECLARE @page_length_limit INT = 1000; -- Example for {len}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector from the page table
SELECT TOP 1
    @query_vector = page_embedding
FROM
    dbo.page
WHERE
    page_embedding IS NOT NULL
ORDER BY
    page_id;

PRINT '--- Running Q4: Hybrid Filter (page_len < 1000 AND distance < 0.5). ---';
PRINT '--- This will be VERY SLOW (full table scan) on ALL databases. ---';

-- 3. Run the query
SELECT
    p.page_id,
    p.page_title,
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) AS distance
FROM
    dbo.page AS p
WHERE
    -- This is the translation of the hybrid WHERE clause
    p.page_len < @page_length_limit
    AND
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) < @distance_threshold
ORDER BY
    distance ASC,   -- ORDER BY page_embedding {op} '{q}'
    p.page_id ASC;  -- Tie-breaker


-- ### NEXT QUERY ###

-- NQ6 Hybrid Range,NO,Index cannot handle distance thresholds.

USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @distance_threshold FLOAT = 0.5; -- Example for {d}
DECLARE @date_low NVARCHAR(50) = '2010-01-01T00:00:00Z';
DECLARE @date_high NVARCHAR(50) = '2015-01-01T00:00:00Z';
DECLARE @query_vector VECTOR(384);
-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;
PRINT '--- Running Q6 (Hybrid Range Search). This will be SLOW (full scan). ---';
-- 3. Run the query
SELECT
    r.rev_id,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM
    dbo.text AS t
JOIN
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE
    -- Filter 1: Standard SQL
    r.rev_timestamp >= @date_low
    AND r.rev_timestamp <= @date_high
    -- Filter 2: Vector Range Search
    AND VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) < @distance_threshold
ORDER BY
    distance ASC,
    t.old_id ASC;


-- ### NEXT QUERY ###
-- NQ7,Agg on Pre-filter,NO,Pre-filter logic requires full scan.
USE index_hybench_100k; -- Or HyBenchDB



-- 1. Define parameters
DECLARE @k INT = 10;
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector from the page table
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running Q7: Aggregation on k-NN with Pre-Filter. ---';
PRINT '--- This will be SLOW (full table scan). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor, -- 'rev_user_text' maps to 'rev_actor' in our schema
    COUNT(*) AS cou
FROM 
    (
        -- Inner Query: k-NN with Pre-filter (must use VECTOR_DISTANCE)
        SELECT TOP (@k)
            p.page_id
        FROM 
            dbo.page AS p
        WHERE 
            p.page_len < @page_len_limit -- Pre-filter
        ORDER BY 
            VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) ASC,
            p.page_id ASC
    ) AS new_page
JOIN 
    dbo.revision AS r ON new_page.page_id = r.rev_page
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;


-- ### NEXT QUERY ###
-- NQ8,This is an Aggregation on a Hybrid Range Search.

USE index_hybench_100k; -- Or HyBenchDB

-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @distance_threshold FLOAT = 0.5; -- {d}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running Q9: Aggregation on Hybrid Range Search. ---';
PRINT '--- This will be SLOW (full table scan). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor, -- Maps to 'rev_actor'
    COUNT(*) AS cou
FROM 
    dbo.page AS p
JOIN 
    dbo.revision AS r ON p.page_id = r.rev_page
WHERE 
    -- Relational Filter
    p.page_len < @page_len_limit
    -- Vector Range Filter
    AND VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) < @distance_threshold
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;




-- ### NEXT QUERY ###
-- NQ9,Agg on Range,NO,Range search logic requires full scan.
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @k INT = 10; -- Top k per year
DECLARE @year_low INT = 2010;
DECLARE @year_high INT = 2015;
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running NQ9: Partitioned k-NN (Top K per Year). ---';
PRINT '--- This will be SLOW (scan + sort). ---';

-- 3. Run the query
SELECT 
    ranked_pages.year,
    ranked_pages.old_id,
    ranked_pages.distance
FROM (
    SELECT 
        t.old_id,
        LEFT(r.rev_timestamp, 4) AS [year], -- Extract Year
        VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance,
        
        -- Partition by Year and Rank by Distance
        ROW_NUMBER() OVER (
            PARTITION BY LEFT(r.rev_timestamp, 4) 
            ORDER BY VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC, t.old_id ASC
        ) AS rank
    FROM 
        dbo.text AS t
    JOIN 
        dbo.revision AS r ON t.old_id = r.rev_text_id
    WHERE 
        -- Filter date range first to reduce rows for the window function
        CAST(LEFT(r.rev_timestamp, 4) AS INT) BETWEEN @year_low AND @year_high
) AS ranked_pages 
WHERE 
    ranked_pages.rank <= @k -- Keep only Top K per year
ORDER BY 
    ranked_pages.year DESC, 
    ranked_pages.distance ASC;


-- ### NEXT QUERY ###
-- NQ10,Filtered Vector Range Search.
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @distance_threshold FLOAT = 0.5; -- {d1}
DECLARE @year_low INT = 2010;
DECLARE @year_high INT = 2015;
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running NQ10: Filtered Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    LEFT(r.rev_timestamp, 4) AS [year], -- Extract Year
    t.old_id,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE 
    -- Filter 1: Date Range
    CAST(LEFT(r.rev_timestamp, 4) AS INT) BETWEEN @year_low AND @year_high
    -- Filter 2: Vector Range (Index cannot be used)
    AND VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) <= @distance_threshold
ORDER BY 
    [year] DESC, 
    distance ASC;



-- ### NEXT QUERY ###
-- NQ12,Agg on Range,NO,Range search logic requires full scan.
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @distance_threshold FLOAT = 0.5; -- {d}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running NQ12: Aggregation on Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    -- Use the string slicing trick for robust year extraction
    LEFT(r.rev_timestamp, 4) AS [year],
    COUNT(*) AS [count]
FROM 
    dbo.page AS p
JOIN 
    dbo.revision AS r ON p.page_id = r.rev_page
WHERE 
    -- Range Search Filter (Index cannot be used)
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) < @distance_threshold
GROUP BY 
    LEFT(r.rev_timestamp, 4)
ORDER BY 
    [year] DESC;



-- ### NEXT QUERY ###
-- NQ14,,Agg on Range,NO,Range search logic requires full scan.

USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @distance_threshold FLOAT = 0.5; -- {d}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running Q12 (NQ14?): Aggregation on Text Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor,
    SUM(CAST(r.rev_minor_edit AS INT)) AS total_minor_edits
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id -- Join text to revision
WHERE 
    -- Range Search Filter (Index cannot be used)
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) < @distance_threshold
GROUP BY 
    r.rev_user_text
ORDER BY 
    total_minor_edits DESC;


-- ### NEXT QUERY ###
-- NQ17,Minimax k-NN,NO,Sorting logic (GREATEST) requires full table calculation.
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @k INT = 10;
DECLARE @query_vector_1 VECTOR(384); -- {q1}
DECLARE @query_vector_2 VECTOR(384); -- {q2}

-- 2. Grab two real vectors
SELECT TOP 1 @query_vector_1 = text_embedding FROM dbo.text ORDER BY old_id;
SELECT TOP 1 @query_vector_2 = text_embedding FROM dbo.text ORDER BY old_id DESC;

PRINT '--- Running NQ17: Minimax k-NN (Slow). ---';

-- 3. Run the query
SELECT TOP (@k)
    t.old_id,
    t.old_text
FROM 
    dbo.text AS t
ORDER BY 
    -- Sort by the GREATEST of the two distances (Minimax)
    GREATEST(
        VECTOR_DISTANCE('cosine', @query_vector_1, t.text_embedding),
        VECTOR_DISTANCE('cosine', @query_vector_2, t.text_embedding)
    ) ASC,
    t.old_id ASC;


-- ### NEXT QUERY ###
--NQ19,Dissimilarity k-NN,NO,Exclusion logic relies on distance threshold (Range logic).

USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @k INT = 10;
DECLARE @distance_threshold FLOAT = 0.5; -- {d} (Minimum distance from q2)
DECLARE @query_vector_1 VECTOR(384); -- {q1} (Target)
DECLARE @query_vector_2 VECTOR(384); -- {q2} (Avoid)

-- 2. Grab two real vectors
SELECT TOP 1 @query_vector_1 = text_embedding FROM dbo.text ORDER BY old_id;
SELECT TOP 1 @query_vector_2 = text_embedding FROM dbo.text ORDER BY old_id DESC;

PRINT '--- Running NQ19: k-NN with Dissimilarity Filter (Slow). ---';

-- 3. Run the query
SELECT TOP (@k)
    t.old_id,
    t.old_text
FROM 
    dbo.text AS t
WHERE 
    -- Filter: Must be "far" from q2
    VECTOR_DISTANCE('cosine', @query_vector_2, t.text_embedding) > @distance_threshold
ORDER BY 
    -- Rank: Must be "close" to q1
    VECTOR_DISTANCE('cosine', @query_vector_1, t.text_embedding) ASC,
    t.old_id ASC;


-- ### NEXT QUERY ###
-- IQ2
USE index_hybench_100k; -- Use your 100k DB



-- 1. Define parameters
DECLARE @dist_min FLOAT = 0.2; -- {d}
DECLARE @dist_max FLOAT = 0.5; -- {d*}
DECLARE @query_vector VECTOR(384);


-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;


PRINT '--- Running IQ2: Bounded Range Search (Slow). ---';


-- 3. Run the query
SELECT 
    t.old_id,
    t.old_text,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM 
    dbo.text AS t
WHERE 
    -- Range Filter (Index cannot be used)
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @dist_min AND @dist_max
ORDER BY 
    distance ASC,
    t.old_id ASC;

-- ### NEXT QUERY ###
-- IQ3
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @l INT = 11; -- Start Rank {l}
DECLARE @r INT = 20; -- End Rank {r}
DECLARE @query_vector VECTOR(384);

-- Calculate SQL pagination arguments
DECLARE @limit INT = @r - @l + 1; -- {r-l+1} (How many to fetch)
DECLARE @offset INT = @l - 1;     -- {l-1}   (How many to skip)

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running IQ3: Paginated k-NN with Pre-Filter (Slow). ---';

-- 3. Run the query
SELECT 
    p.page_id,
    p.page_title
FROM 
    dbo.page AS p
WHERE 
    -- Pre-filter (Must happen before sorting)
    p.page_len < @page_len_limit
ORDER BY 
    -- Full table scan required to sort filtered results
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) ASC,
    p.page_id ASC
-- Standard SQL Pagination
OFFSET @offset ROWS 
FETCH NEXT @limit ROWS ONLY;


-- ### NEXT QUERY ###
-- IQ4
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @dist_min FLOAT = 0.2;      -- {d}
DECLARE @dist_max FLOAT = 0.5;      -- {d*}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running IQ4: Filtered Bounded Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    p.page_id,
    p.page_title
FROM 
    dbo.page AS p
WHERE 
    -- Relational Filter
    p.page_len < @page_len_limit
    -- Vector Range Filter (Index cannot be used)
    AND VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) BETWEEN @dist_min AND @dist_max
ORDER BY 
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) ASC,
    p.page_id ASC;


-- ### NEXT QUERY ###
-- IQ5
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @l INT = 11; -- Start Rank
DECLARE @r INT = 20; -- End Rank
DECLARE @date_low NVARCHAR(50) = '2010-01-01T00:00:00Z';
DECLARE @date_high NVARCHAR(50) = '2015-01-01T00:00:00Z';
DECLARE @query_vector VECTOR(384);

-- Calculate SQL pagination arguments
DECLARE @limit INT = @r - @l + 1; -- How many to fetch
DECLARE @offset INT = @l - 1;     -- How many to skip

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;

PRINT '--- Running IQ5: Paginated k-NN with Date Filter (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_id
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE 
    -- Pre-filter (Must happen before sorting)
    r.rev_timestamp >= @date_low
    AND r.rev_timestamp <= @date_high
ORDER BY 
    -- Full scan required to sort filtered results
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC,
    t.old_id ASC
-- Standard SQL Pagination
OFFSET @offset ROWS 
FETCH NEXT @limit ROWS ONLY;


-- ### NEXT QUERY ###
-- IQ6
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @dist_min FLOAT = 0.2;      -- {d}
DECLARE @dist_max FLOAT = 0.5;      -- {d*}
DECLARE @date_low NVARCHAR(50) = '2010-01-01T00:00:00Z'; -- {DATE_LOW}
DECLARE @date_high NVARCHAR(50) = '2015-01-01T00:00:00Z'; -- {DATE_HIGH}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;

PRINT '--- Running IQ6: Filtered Bounded Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_id
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE 
    -- Relational Filter: Date Range
    r.rev_timestamp >= @date_low
    AND r.rev_timestamp <= @date_high
    -- Vector Range Filter (Index cannot be used)
    AND VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @dist_min AND @dist_max
ORDER BY 
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC,
    t.old_id ASC;


-- ### NEXT QUERY ###
-- IQ7
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @l INT = 11; -- Start Rank {l}
DECLARE @r INT = 20; -- End Rank {r}
DECLARE @query_vector VECTOR(384);

-- Calculate SQL pagination arguments
DECLARE @limit INT = @r - @l + 1; -- {r-l+1} (How many to fetch)
DECLARE @offset INT = @l - 1;     -- {l-1}   (How many to skip)

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding FROM dbo.page ORDER BY page_id;

PRINT '--- Running IQ7: Aggregation on Paginated Pre-filtered Search (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM 
    (
        -- Inner Query: Paginated k-NN with Pre-filter
        SELECT 
            p.page_id
        FROM 
            dbo.page AS p
        WHERE 
            p.page_len < @page_len_limit -- Pre-filter
        ORDER BY 
            VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) ASC,
            p.page_id ASC
        OFFSET @offset ROWS 
        FETCH NEXT @limit ROWS ONLY
    ) AS new_page
JOIN 
    dbo.revision AS r ON new_page.page_id = r.rev_page
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;


-- ### NEXT QUERY ###
-- IQ8
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @dist_min FLOAT = 0.2;      -- {d}
DECLARE @dist_max FLOAT = 0.5;      -- {d*}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running IQ8: Aggregation on Filtered Bounded Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM 
    dbo.page AS p
JOIN 
    dbo.revision AS r ON p.page_id = r.rev_page
WHERE 
    -- Relational Filter
    p.page_len < @page_len_limit
    -- Vector Range Filter (Index cannot be used)
    AND VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) BETWEEN @dist_min AND @dist_max
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;


-- ### NEXT QUERY ###
-- IQ9
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @l INT = 11;  -- Start Rank {l}
DECLARE @r INT = 20;  -- End Rank {r}
DECLARE @year_low INT = 2010; -- {YEARL}
DECLARE @year_high INT = 2015; -- {YEARH}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running IQ9: Paginated Partitioned k-NN (Slow). ---';

-- 3. Run the query
SELECT 
    ranked_pages.[year],
    ranked_pages.old_id,
    ranked_pages.distance
FROM (
    SELECT 
        t.old_id,
        LEFT(r.rev_timestamp, 4) AS [year], -- Robust Year Extraction
        VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance,
        
        -- Partition by Year and Rank by Distance
        ROW_NUMBER() OVER (
            PARTITION BY LEFT(r.rev_timestamp, 4) 
            ORDER BY VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC, t.old_id ASC
        ) AS rank
    FROM 
        dbo.text AS t
    JOIN 
        dbo.revision AS r ON t.old_id = r.rev_text_id
    WHERE 
        -- Filter date range first to reduce rows for the window function
        CAST(LEFT(r.rev_timestamp, 4) AS INT) BETWEEN @year_low AND @year_high
) AS ranked_pages 
WHERE 
    ranked_pages.rank BETWEEN @l AND @r -- Select the specific slice
ORDER BY 
    ranked_pages.[year] DESC, 
    ranked_pages.distance ASC;


-- ### NEXT QUERY ###
-- IQ10

USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @dist_min FLOAT = 0.2;      -- {d}
DECLARE @dist_max FLOAT = 0.5;      -- {d*}
DECLARE @year_low INT = 2010;       -- {YEARL}
DECLARE @year_high INT = 2015;      -- {YEARH}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running IQ10: Filtered Bounded Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    LEFT(r.rev_timestamp, 4) AS [year], -- Robust Year Extraction
    t.old_id,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE 
    -- Filter 1: Date Range
    CAST(LEFT(r.rev_timestamp, 4) AS INT) BETWEEN @year_low AND @year_high
    -- Filter 2: Vector Range (Index cannot be used)
    AND VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @dist_min AND @dist_max
ORDER BY 
    [year] DESC, 
    distance ASC;



-- ### NEXT QUERY ###
-- SQ1
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector to search with
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;

PRINT '--- Running SQ1: Specific Rank Selection (Slow). ---';

-- 3. Run the query
SELECT 
    ranked.old_id,
    ranked.old_text,
    ranked.rank
FROM (
    SELECT 
        t.old_id,
        t.old_text,
        -- Calculate Rank based on Distance
        ROW_NUMBER() OVER (
            ORDER BY VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC, t.old_id ASC
        ) AS rank
    FROM 
        dbo.text AS t
) AS ranked
WHERE 
    -- Filter for specific ranks {r_1, r_2, ...}
    -- Replace this list with your specific {r} values
    rank IN (1, 5, 10, 50, 100) 
ORDER BY 
    rank ASC;


-- ### NEXT QUERY ###
-- SQ2
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
-- Range 1
DECLARE @d1_min FLOAT = 0.1; 
DECLARE @d1_max FLOAT = 0.2;
-- Range 2
DECLARE @d2_min FLOAT = 0.4;
DECLARE @d2_max FLOAT = 0.5;
-- Query Vector
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;

PRINT '--- Running SQ2: Multi-Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    t.old_id,
    t.old_text,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM 
    dbo.text AS t
WHERE 
    -- Range 1
    (VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @d1_min AND @d1_max)
    OR
    -- Range 2
    (VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @d2_min AND @d2_max)
    -- Add more OR conditions as needed
ORDER BY 
    distance ASC,
    t.old_id ASC;


-- ### NEXT QUERY ###
-- SQ3
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector to search with
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running SQ3: Specific Rank Selection with Pre-Filter (Slow). ---';

-- 3. Run the query
SELECT 
    ranked.page_id,
    ranked.page_title,
    ranked.rank
FROM (
    SELECT 
        p.page_id,
        p.page_title,
        -- Calculate Rank based on Distance
        ROW_NUMBER() OVER (
            ORDER BY VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) ASC, p.page_id ASC
        ) AS rank
    FROM 
        dbo.page AS p
    WHERE
        -- Pre-filter: Only consider short pages
        p.page_len < @page_len_limit
) AS ranked
WHERE 
    -- Filter for specific ranks {r_1, r_2, ...}
    rank IN (1, 5, 10, 50, 100) 
ORDER BY 
    rank ASC;


-- ### NEXT QUERY ###
-- SQ4
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @query_vector VECTOR(384);

-- Range 1 ({d_1} to {d_1*})
DECLARE @d1_min FLOAT = 0.1; 
DECLARE @d1_max FLOAT = 0.2;

-- Range 2 ({d_2} to {d_2*})
DECLARE @d2_min FLOAT = 0.4;
DECLARE @d2_max FLOAT = 0.5;

-- 2. Grab a real vector to search with
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running SQ4: Filtered Multi-Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    p.page_id,
    p.page_title,
    VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) AS distance
FROM 
    dbo.page AS p
WHERE 
    -- Filter 1: Relational (Pre-filter)
    p.page_len < @page_len_limit
    
    AND (
        -- Filter 2: Vector Range 1
        (VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) BETWEEN @d1_min AND @d1_max)
        OR
        -- Filter 3: Vector Range 2
        (VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) BETWEEN @d2_min AND @d2_max)
    )
ORDER BY 
    distance ASC,
    p.page_id ASC;


-- ### NEXT QUERY ###
-- SQ5
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @date_low NVARCHAR(50) = '2010-01-01T00:00:00Z'; -- {DATE_LOW}
DECLARE @date_high NVARCHAR(50) = '2015-01-01T00:00:00Z'; -- {DATE_HIGH}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;

PRINT '--- Running SQ5: Specific Rank Selection with Date Filter (Slow). ---';

-- 3. Run the query
SELECT 
    ranked.rev_id,
    ranked.rank
FROM (
    SELECT 
        r.rev_id,
        -- Calculate Rank based on Distance
        ROW_NUMBER() OVER (
            ORDER BY VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC, t.old_id ASC
        ) AS rank
    FROM 
        dbo.text AS t
    JOIN 
        dbo.revision AS r ON t.old_id = r.rev_text_id
    WHERE 
        -- Pre-filter: Date Range
        r.rev_timestamp >= @date_low 
        AND r.rev_timestamp <= @date_high
) AS ranked
WHERE 
    -- Filter for specific ranks {r_1, r_2, ...}
    rank IN (1, 5, 10, 50, 100) 
ORDER BY 
    rank ASC;


-- ### NEXT QUERY ###
-- SQ6
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @date_low NVARCHAR(50) = '2010-01-01T00:00:00Z'; -- {DATE_LOW}
DECLARE @date_high NVARCHAR(50) = '2015-01-01T00:00:00Z'; -- {DATE_HIGH}
DECLARE @query_vector VECTOR(384);

-- Range 1 ({d_1} to {d_1*})
DECLARE @d1_min FLOAT = 0.1; 
DECLARE @d1_max FLOAT = 0.2;

-- Range 2 ({d_2} to {d_2*})
DECLARE @d2_min FLOAT = 0.4;
DECLARE @d2_max FLOAT = 0.5;

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding FROM dbo.text ORDER BY old_id;

PRINT '--- Running SQ6: Filtered Multi-Range Search with Join (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_id
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE 
    -- Filter 1: Relational Date Range
    r.rev_timestamp >= @date_low 
    AND r.rev_timestamp <= @date_high
    
    AND (
        -- Filter 2: Vector Range 1
        (VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @d1_min AND @d1_max)
        OR
        -- Filter 3: Vector Range 2
        (VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @d2_min AND @d2_max)
    )
ORDER BY 
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC,
    t.old_id ASC;


-- ### NEXT QUERY ###
-- SQ7
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding FROM dbo.page ORDER BY page_id;

PRINT '--- Running SQ7: Aggregation on Specific Ranks with Pre-Filter (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM 
    (
        SELECT 
            ranked.page_id
        FROM (
            SELECT 
                p.page_id,
                -- Calculate Rank based on Distance, considering only short pages
                ROW_NUMBER() OVER (
                    ORDER BY VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) ASC, p.page_id ASC
                ) AS rank
            FROM 
                dbo.page AS p
            WHERE
                p.page_len < @page_len_limit -- Pre-filter
        ) AS ranked
        WHERE 
            -- Select specific ranks {r_1, r_2...}
            ranked.rank IN (1, 5, 10, 50, 100) 
    ) AS filtered_page
JOIN 
    dbo.revision AS r ON filtered_page.page_id = r.rev_page
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;


-- ### NEXT QUERY ###
-- SQ8
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @page_len_limit INT = 1000; -- {len}
DECLARE @query_vector VECTOR(384);

-- Range 1
DECLARE @d1_min FLOAT = 0.1; 
DECLARE @d1_max FLOAT = 0.2;

-- Range 2
DECLARE @d2_min FLOAT = 0.4;
DECLARE @d2_max FLOAT = 0.5;

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = page_embedding 
FROM dbo.page 
WHERE page_embedding IS NOT NULL 
ORDER BY page_id;

PRINT '--- Running SQ8: Aggregation on Filtered Multi-Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    r.rev_user_text AS rev_actor,
    COUNT(*) AS cou
FROM 
    dbo.page AS p
JOIN 
    dbo.revision AS r ON p.page_id = r.rev_page
WHERE 
    -- Relational Filter
    p.page_len < @page_len_limit
    
    AND (
        -- Multi-Range Vector Logic
        (VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) BETWEEN @d1_min AND @d1_max)
        OR
        (VECTOR_DISTANCE('cosine', @query_vector, p.page_embedding) BETWEEN @d2_min AND @d2_max)
    )
GROUP BY 
    r.rev_user_text
ORDER BY 
    cou DESC;


-- ### NEXT QUERY ###
-- SQ9
USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @year_low INT = 2010; -- {YEARL}
DECLARE @year_high INT = 2015; -- {YEARH}
DECLARE @query_vector VECTOR(384);

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running SQ9: Partitioned Specific Rank Selection (Slow). ---';

-- 3. Run the query
SELECT 
    ranked_pages.[year],
    ranked_pages.old_id,
    ranked_pages.distance
FROM (
    SELECT 
        t.old_id,
        LEFT(r.rev_timestamp, 4) AS [year], -- Robust Year Extraction
        VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance,
        
        -- Partition by Year and Rank by Distance
        ROW_NUMBER() OVER (
            PARTITION BY LEFT(r.rev_timestamp, 4) 
            ORDER BY VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) ASC, t.old_id ASC
        ) AS rank
    FROM 
        dbo.text AS t
    JOIN 
        dbo.revision AS r ON t.old_id = r.rev_text_id
    WHERE 
        -- Filter date range first
        CAST(LEFT(r.rev_timestamp, 4) AS INT) BETWEEN @year_low AND @year_high
) AS ranked_pages 
WHERE 
    -- Filter for specific ranks {r_1, r_2...}
    ranked_pages.rank IN (1, 5, 10, 20) 
ORDER BY 
    ranked_pages.[year] DESC, 
    ranked_pages.distance ASC;



-- ### NEXT QUERY ###
-- SQ10

USE index_hybench_100k; -- Or HyBenchDB


-- 1. Define parameters
DECLARE @year_low INT = 2010; -- {YEARL}
DECLARE @year_high INT = 2015; -- {YEARH}
DECLARE @query_vector VECTOR(384);

-- Range 1
DECLARE @d1_min FLOAT = 0.1; 
DECLARE @d1_max FLOAT = 0.2;

-- Range 2
DECLARE @d2_min FLOAT = 0.4;
DECLARE @d2_max FLOAT = 0.5;

-- 2. Grab a real vector
SELECT TOP 1 @query_vector = text_embedding 
FROM dbo.text 
WHERE text_embedding IS NOT NULL 
ORDER BY old_id;

PRINT '--- Running SQ10: Filtered Multi-Range Search (Slow). ---';

-- 3. Run the query
SELECT 
    LEFT(r.rev_timestamp, 4) AS [year], -- Robust Year Extraction
    t.old_id,
    VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) AS distance
FROM 
    dbo.text AS t
JOIN 
    dbo.revision AS r ON t.old_id = r.rev_text_id
WHERE 
    -- Filter 1: Date Range
    CAST(LEFT(r.rev_timestamp, 4) AS INT) BETWEEN @year_low AND @year_high
    
    AND (
        -- Filter 2: Vector Range 1
        (VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @d1_min AND @d1_max)
        OR
        -- Filter 3: Vector Range 2
        (VECTOR_DISTANCE('cosine', @query_vector, t.text_embedding) BETWEEN @d2_min AND @d2_max)
    )
ORDER BY 
    [year] DESC, 
    distance ASC;
