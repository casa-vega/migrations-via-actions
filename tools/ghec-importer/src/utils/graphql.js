// graphql

const { Octokit } = require('@octokit/rest')
const Logger = require('../utils/logger')
const proxyAgent = require('../utils/proxy-agent')

module.exports = async (migration, query, variables) => {
  const logger = new Logger(migration)

  const ghecAdminToken = migration.adminToken

  const proxy = proxyAgent()

  const ghecAdminOctokit = new Octokit({
    auth: ghecAdminToken,
    // Embed the proxy agent only if a proxy is used
    ...(proxy.enabled ? { request: { agent: proxy.proxyAgent } } : {})
  })

  logger.graphql(query, variables)

  const result = await ghecAdminOctokit.request('POST /graphql', {
    headers: {
      'GraphQL-Features': 'gh_migrator_import_to_dotcom'
    },
    query: query,
    variables: variables
  })

  logger.graphqlResponse(result.data.data, result.headers['x-github-request-id'])

  return result.data.data
}
