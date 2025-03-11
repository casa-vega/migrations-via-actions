const Logger = require('../utils/logger')
const migratableResources = require('../queries/migratable-resources')
const createTeam = require('../queries/create-team')
const addImportMapping = require('../queries/add-import-mapping')

module.exports = async migration => {
  const logger = new Logger(migration)
  const teams = await migratableResources(migration, 'team')
  const organizations = await migratableResources(migration, 'organization')
  const organization = organizations[0]
  const organizationSourceUrlParts = organization.sourceUrl.split('/')
  const organizationSourceName = organizationSourceUrlParts.pop()
  const organizationTargetUrlParts = organization.targetUrl.split('/')
  const organizationTargetName = organizationTargetUrlParts.pop()

  let mappings = []

  for (let { modelName, sourceUrl, targetUrl } of teams) {
    // Teams that don't have a naming conflict will have an empty `targetUrl`,
    // therefore we're building the `targetUrl` from the `sourceUrl` parts
    // of the organization and team
    const sourceUrlParts = sourceUrl.split('/')
    const teamName = sourceUrlParts.pop()
    const newTeamName = organizationSourceName + '-' + teamName
    const action = 'MERGE'

    logger.info(`Renaming team '${teamName}' to '${newTeamName}'`)

    // Create team with new name. It fails silently if team already exists.
    await createTeam(migration, newTeamName)

    targetUrl = organizationTargetUrlParts.join('/') + '/orgs/' + organizationTargetName + '/teams/' + newTeamName

    mappings.push(`{
      modelName: "${modelName}",
      sourceUrl: "${sourceUrl}",
      targetUrl: "${targetUrl}",
      action: ${action}
    }`)
  }

  mappings = '[' + mappings.join(',') + ']'

  await addImportMapping(migration, mappings)
}
