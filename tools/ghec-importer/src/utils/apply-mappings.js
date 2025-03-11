const fs = require('fs')
const buildMappings = require('./build-mappings')
const addImportMapping = require('../queries/add-import-mapping')
const Logger = require('../utils/logger')

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.step('Applying mappings')

  // Load mappings file
  const mappings = fs.readFileSync(migration.mappingsPath).toString().split('\n')

  // Number of mappings that are applied at once
  // This avoids request timeouts for very large mappings files
  const mappingsBatchSize = 500

  // Remove header
  mappings.shift()

  logger.debug(`Loaded ${mappings.length} mappings`)

  for (let i = 0; i < mappings.length; i += mappingsBatchSize) {
    logger.debug(`Mappings batch: ${i + 1} - ${i + mappingsBatchSize}`)

    const mappingsBatch = mappings.slice(i, i + mappingsBatchSize)
    let customMappings = buildMappings(migration, mappingsBatch)

    const state = await addImportMapping(migration, customMappings)

    if (state === 'FAILED') {
      return state
    }
  }
}
