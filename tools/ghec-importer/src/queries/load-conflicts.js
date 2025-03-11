// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=check-for-conflicts

const Logger = require('../utils/logger')
const graphql = require('../utils/graphql')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Loading conflicts')

  const query = `query ($organization: String!, $guid: String!) {
    organization (login: $organization) {
      migration (guid: $guid) {
        state
        conflicts {
          modelName
          sourceUrl
          targetUrl
          recommendedAction
          notes
        }
      }
    }
  }`

  const variables = {
    organization: migration.targetOrganization,
    guid: migration.guid
  }

  const data = await graphql(migration, query, variables)

  return data.organization.migration.conflicts
}
