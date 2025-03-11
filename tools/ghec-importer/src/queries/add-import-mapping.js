// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=map-conflicts

const Logger = require('../utils/logger')
const graphql = require('../utils/graphql')
const waitForStatus = require('../utils/wait-for-status')

module.exports = async (migration, mappings) => {
  const logger = new Logger(migration)

  logger.title('Adding import mapping')

  const query = `mutation ($migrationId: ID!) {
    addImportMapping(input: { 
      migrationId: $migrationId,
      mappings: ${mappings}
    }) {
      migration {
        guid
        id
        state
      }
    }
  }`

  const variables = {
    migrationId: migration.id
  }

  await graphql(migration, query, variables)

  return await waitForStatus(migration, ['READY', 'CONFLICTS', 'FAILED'])
}
