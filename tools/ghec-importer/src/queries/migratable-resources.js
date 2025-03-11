// migratable-resources
//
// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=audit-migration

const graphql = require('../utils/graphql')
const Logger = require('../utils/logger')

module.exports = async (migration, modelName) => {
  const logger = new Logger(migration)

  logger.title('Fetching migration resources' + (modelName ? ` (${modelName})` : '') + (migration.filterState ? `Filter by ${migration.filterState}` : ''))

  let filterState = null
  if (migration.filterState) {
    filterState = migration.filterState.toUpperCase()
  }

  const query = `query(
    $organization: String!
    $guid: String!
    $cursor: String
    ${modelName ? '$modelName: String!' : ''}
    ${filterState ? '$filterState: MigratableResourceState!' : ''}
  ){
    organization(login: $organization) {
      migration(guid: $guid) {
        migratableResources(first: 100 after: $cursor 
          ${modelName ? 'modelName: $modelName' : ''} ${filterState ? 'state: $filterState' : ''}) {
          pageInfo {
            hasNextPage
            endCursor
          }
          totalCount
          nodes {
            modelName
            sourceUrl
            targetUrl
            state
            warning
          }
        }
      }
    }
  }`

  const variables = {
    organization: migration.targetOrganization,
    guid: migration.guid,
    modelName,
    filterState
  }

  let records = []
  let cursor = null
  let hasNextPage = null
  do {
    const data = await graphql(migration, query, { ...variables, cursor })
    const migratableResources = data.organization.migration.migratableResources

    hasNextPage = migratableResources.pageInfo.hasNextPage
    cursor = migratableResources.pageInfo.endCursor

    logger.debug(`Has Next ${hasNextPage} Next Page Cursor: ${cursor}`)

    records.push(...migratableResources.nodes)
  } while (hasNextPage)

  return records
}
