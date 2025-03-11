const fs = require('fs')
const buildUserMappings = require('./build-user-mappings')
const addImportMapping = require('../queries/add-import-mapping')
const Logger = require('../utils/logger')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.step('Applying user mappings')

  // Load user mappings file
  const userMappings = fs.readFileSync(migration.userMappingsPath).toString().split('\n')

  // Number of user mappings that are applied at once
  // This avoids request timeouts for very large user mappings files
  const userMappingsBatchSize = 500

  // Remove header
  userMappings.shift()

  logger.debug(`Loaded ${userMappings.length} user mappings`)

  for (let i = 0; i < userMappings.length; i += userMappingsBatchSize) {
    logger.debug(`User mappings batch: ${i + 1} - ${i + userMappingsBatchSize}`)

    const userMappingsBatch = userMappings.slice(i, i + userMappingsBatchSize)
    let mappings = buildUserMappings(migration, userMappingsBatch)

    const state = await addImportMapping(migration, mappings)

    if (state === 'FAILED') {
      return state
    }
  }
}
