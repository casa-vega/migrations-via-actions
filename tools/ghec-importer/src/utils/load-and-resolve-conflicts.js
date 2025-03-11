const loadConflicts = require('../queries/load-conflicts')
const buildConflictMappings = require('./build-conflict-mappings')
const addImportMapping = require('../queries/add-import-mapping')
const Logger = require('../utils/logger')

function isEqual(array1, array2) {
  return array1.every(({ sourceUrl }, i) => sourceUrl === array2[i].sourceUrl)
}

module.exports = async migration => {
  const logger = new Logger(migration)

  let conflicts
  let previousConflicts

  let state
  do {
    conflicts = await loadConflicts(migration)

    logger.data('GraphQL: Conflicts', conflicts)

    if (previousConflicts && isEqual(conflicts, previousConflicts)) {
      break
    }

    let mappings = await buildConflictMappings(migration, conflicts)

    state = await addImportMapping(migration, mappings)

    previousConflicts = conflicts
    conflicts = []
  } while (!['READY'].includes(state))

  return conflicts
}
