// graphql

const { Octokit } = require('@octokit/rest')
const Logger = require('../utils/logger')
const proxyAgent = require('../utils/proxy-agent')

module.exports = async (migration, name) => {
  const logger = new Logger(migration)
  const ghecAdminToken = migration.adminToken
  const proxy = proxyAgent()

  const ghecAdminOctokit = new Octokit({
    auth: ghecAdminToken,
    // Embed the proxy agent only if a proxy is used
    ...(proxy.enabled ? { request: { agent: proxy.proxyAgent } } : {})
  })

  const parameters = {
    org: migration.targetOrganization,
    name,
    privacy: 'closed'
  }

  logger.rest('Create team', parameters)

  try {
    const response = await ghecAdminOctokit.teams.create(parameters)
    logger.data('REST API (Create team): Response', response)

    // As per documentation (https://docs.github.com/en/rest/reference/teams#create-a-team)
    // the authenticated user becomes a team member automatically.
    // In our case we don't want that.
    // Therefore we are removing the authenticated user from the team.
    const {
      data: { login }
    } = await ghecAdminOctokit.users.getAuthenticated()
    await ghecAdminOctokit.teams.removeMembershipForUserInOrg({
      org: migration.targetOrganization,
      team_slug: name,
      username: login
    })
  } catch (error) {
    logger.data('REST API (Create team): Error', error)

    if (error.status != 422) {
      throw error
    }
  }
}
