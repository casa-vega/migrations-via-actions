// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=audit-migration

// const github = require('@actions/github')
const graphql = require('../utils/graphql')
const Logger = require('../utils/logger')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Fetching migration resources total')

  const modelTypes = [
    'user',
    'organization',
    'repository',
    'team',
    'protected_branch',
    'milestone',
    'issue',
    'pull_request',
    'project',
    'pull_request_review',
    'pull_request_review_comment',
    'commit_comment',
    'issue_comment',
    'issue_event',
    'attachment',
    'release',
    'repository_file'
  ]

  const totalCountPartials = modelTypes.map(modelType => {
    return `
      ${modelType}: migratableResources(
        modelName: "${modelType}"
        state: $state
      ) {
        totalCount
      }`
  })

  const query = `query ($organization: String!, $guid: String!, $state: MigratableResourceState!) {
    organization (login: $organization) {
      migration (guid: $guid) {
        total: migratableResources(
          state: $state
        ) {
          totalCount
        }

        ${totalCountPartials}
      }
    }
  }`

  const variables = {
    organization: migration.targetOrganization,
    guid: migration.guid
  }

  const succeededData = await graphql(migration, query, {
    ...variables,
    state: 'SUCCEEDED'
  })

  const succeededRecords = succeededData.organization.migration

  const failedData = await graphql(migration, query, {
    ...variables,
    state: 'FAILED'
  })

  const failedRecords = failedData.organization.migration

  const totals = []

  for (const [modelType, values] of Object.entries(succeededRecords)) {
    totals.push({
      type: modelType,
      succeeded: values['totalCount'],
      failed: failedRecords[modelType]['totalCount']
    })
  }

  return totals
}
