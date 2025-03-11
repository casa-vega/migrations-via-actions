const Logger = require('../utils/logger')
const getSourceOrganizationName = require('../utils/get-source-organization-name')
const createTeam = require('../queries/create-team')

module.exports = async (migration, conflicts) => {
  const logger = new Logger(migration)

  let mappings = []
  let sourceOrganizationName

  for (let { modelName, sourceUrl, targetUrl, recommendedAction } of conflicts) {
    if (migration.resolveRepositoryRenames) {
      if (modelName == 'repository' && recommendedAction == 'RENAME') {
        if (migration.resolveRepositoryRenames == 'org-prefix') {
          if (!sourceOrganizationName) {
            sourceOrganizationName = await getSourceOrganizationName(migration)
          }

          let targetUrlParts = targetUrl.split('/')
          let repositoryName = targetUrlParts.pop()
          targetUrl = targetUrlParts.concat(sourceOrganizationName + '-' + repositoryName).join('/')
        } else {
          targetUrl = targetUrl + '-' + migration.guid
        }
      }
    }

    // Disallow team merges
    //
    // When importing repositories from different source organizations,
    // teams may have the same name with different members.
    // In order to avoid security issues that would be caused by merging
    // different teams with the same name, the option below
    // prevents team merges and creates new teams with the source organization
    // name as a prefix.
    // Since the importer API does not support team renames, we're using the
    // standard API for creating the team which we then merge to.
    //
    // Caveat: If the team is renamed on the target before all team repositories
    // have been migrated, another new team will be created.
    // Team maintainers can resolve this manually by assigning the repositories
    // to the primary team and delete the duplicate team
    if (migration.disallowTeamMerges) {
      if (modelName == 'team' && recommendedAction == 'MERGE') {
        if (!sourceOrganizationName) {
          sourceOrganizationName = await getSourceOrganizationName(migration)
        }

        const targetUrlParts = targetUrl.split('/')
        const teamName = targetUrlParts.pop()
        const newTeamName = sourceOrganizationName + '-' + teamName

        logger.title(`Disallowing team merge for '${teamName}', renaming to '${newTeamName}'`)

        // Create team with new name. It fails silently if team already exists.
        await createTeam(migration, newTeamName)

        targetUrlParts.push(newTeamName)
        targetUrl = targetUrlParts.join('/')
      }
    }

    mappings.push(`{
      modelName: "${modelName}",
      sourceUrl: "${sourceUrl}",
      targetUrl: "${targetUrl}",
      action: ${recommendedAction}
    }`)
  }

  mappings = '[' + mappings.join(',') + ']'

  return mappings
}
