# Issues and possible remediation

## Bitbucket

### Import of large archive fails due to timeout

Consider splitting the export:

1. Export just the base repository then import it
  
   ```sh
   bbs-exporter --only repository --max-threads 25 --retries 5 -f repositories.txt -o ${MIGRATION_GUID}.tar.gz
   ```
1. Export only metadata and then import it

   ```sh
   bbs-exporter --except repository --max-threads 25 --retries 5 -f repositories.txt -o ${MIGRATION_GUID}.tar.gz
   ```
