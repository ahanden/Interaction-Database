# Check that Entrez IDs meet the ordering criteria
SELECT "Bad Pair" as "Improperly Ordered Entrez IDs", int_id, entrez_id1, entrez_id2
FROM interactions
WHERE entrez_id1 >= entrez_id2;

# Check that the interaction IDs match up with valid genes
SELECT "Bad IDs" AS "Entrez IDs missing from genedb", int_id, entrez_id1 AS entrez_id
FROM interactions
LEFT JOIN genes.genes
ON entrez_id1 = genes.genes.entrez_id
WHERE genes.genes.entrez_id IS NULL
UNION
SELECT "Bad IDs", int_id, entrez_id2
FROM interactions
LEFT JOIN genes.genes
ON entrez_id2 = genes.genes.entrez_id
WHERE genes.genes.entrez_id IS NULL;

# Check that publications correlate to an existing interaction id
SELECT "Bad Source" AS "Sources do not match interactions", sources.int_id AS int_id, pubmed_id
FROM sources
LEFT JOIN interactions
ON sources.int_id = interactions.int_id
WHERE interactions.int_id IS NULL;
