// The startImport mutation will create a migration object on GitHub to keep track of the import status.
//
// The migration status should return as WAITING after starting an import and
// will wait for an archive to be uploaded in the Upload Migration Archive step.
//
// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=start-an-import

const Logger = require('../utils/logger')
const graphql = require('../utils/graphql')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Starting import')

  const query = `mutation ($organizationId: ID!) {
    startImport(input: { organizationId: $organizationId }) {
      migration {
        uploadUrl
        guid
        id
        databaseId
        state
      }
    }
  }`

  const variables = {
    organizationId: migration.organizationId
  }

  const data = await graphql(migration, query, variables)

  migration = Object.assign(migration, data.startImport.migration)

  logger.info(`Migration ID: ${migration.id}`)
  logger.info(`Migration GUID: ${migration.guid}`)

  return migration
}
