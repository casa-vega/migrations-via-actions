// prepare-import
//
// This mutation extracts the migration archive and creates database records for the models that will be imported.
//
// The state will transition to PENDING initially and once the archive begins to prepare,
// the state will transition as follows: PENDING -> PREPARING -> CONFLICTS.
//
// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=prepare-archive

const Logger = require('../utils/logger')
const graphql = require('../utils/graphql')
const waitForStatus = require('../utils/wait-for-status')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Preparing import')

  const query = `mutation ($migrationId: ID!) {
    prepareImport(input: { migrationId: $migrationId }) {
      migration {
        guid
        id
        state
        databaseId
      }
    }
  }`

  const variables = {
    migrationId: migration.id
  }

  await graphql(migration, query, variables)

  return await waitForStatus(migration, ['READY', 'CONFLICTS', 'FAILED'])
}
