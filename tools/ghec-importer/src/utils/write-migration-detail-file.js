const fs = require('fs')
const Logger = require('../utils/logger')

module.exports = function (migration, step) {
  const logger = new Logger(migration)

  if (migration.detailOutputFile && migration.detailOutputFile.length > 0) {
    const allowedFields = ['id', 'guid', 'organizationId', 'targetOrganization', 'disallowTeamMerges', 'databaseId']
    logger.step('Writing Migration Details to file')

    const migrationDetails = { ...migration }

    Object.keys(migrationDetails).forEach(key => {
      if (!allowedFields.includes(key)) {
        delete migrationDetails[key]
      }
    })
    migrationDetails.step = step

    try {
      fs.writeFileSync(migration.detailOutputFile, JSON.stringify(migrationDetails, null, 2))
    } catch (err) {
      logger.info(`Error writing migration details to file: ${err.message}. Will continue`)
    }
  }
}
