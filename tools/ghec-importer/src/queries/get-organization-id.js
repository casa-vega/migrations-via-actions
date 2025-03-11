// const github = require('@actions/github')
const graphql = require('../utils/graphql')
const Logger = require('../utils/logger')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Retrieving organization ID')

  const query = `query ($organization: String!) {
    organization(login: $organization) {
      id
    }
  }`

  const variables = {
    organization: migration.targetOrganization
  }

  const data = await graphql(migration, query, variables)

  const organizationId = data.organization.id

  logger.info(`Organization ID: ${organizationId}`)

  return organizationId
}
