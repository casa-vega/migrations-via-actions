// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=unlock-imported-repositories

const Logger = require('../utils/logger')
const graphql = require('../utils/graphql')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Unlocking imported repositories')

  const query = `mutation ($migrationId: ID!) {
    unlockImportedRepositories(input: { migrationId: $migrationId }) {
      migration {
        guid
        id
        state
      }
      unlockedRepositories {
        nameWithOwner
      }
    }
  }`

  const variables = {
    migrationId: migration.id
  }

  await graphql(migration, query, variables)
}
