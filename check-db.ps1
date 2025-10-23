# Query PostgreSQL for snapshot metadata
$query = "SELECT schema_version, snapshot_version, blob_path, size_bytes, created_at FROM snapshot_metadata ORDER BY created_at DESC LIMIT 5;"

# Using psql command line
$env:PGPASSWORD = "Advocate2!"
psql -h pg-mybartenderdb.postgres.database.azure.com -U pgadmin -d mybartender -c $query
