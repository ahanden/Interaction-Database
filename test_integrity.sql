SELECT * FROM interactions WHERE entrez_id1 >= entrez_id2;
SELECT * FROM interactions LEFT JOIN genes.genes ON interactions.entrez_id1 = genes.genes.entrez_id WHERE genes.genes.entrez_id IS NULL;
SELECT * FROM interactions LEFT JOIN genes.genes ON interactions.entrez_id2 = genes.genes.entrez_id WHERE genes.genes.entrez_id IS NULL;
