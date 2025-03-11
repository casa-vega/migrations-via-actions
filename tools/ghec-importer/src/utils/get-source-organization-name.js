const Logger = require('./logger')
const migratableResources = require('../queries/migratable-resources')

module.exports = async migration => {
  const logger = new Logger(migration)

  let organizations = await migratableResources(migration, 'organization')

  logger.debug('Getting source organization name', organizations)

  const organizationName = organizations[0].sourceUrl.split('/').pop()

  return organizationName
}
