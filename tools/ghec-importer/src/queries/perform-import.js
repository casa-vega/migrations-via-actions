// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=perform-the-import

const Logger = require('../utils/logger')
const graphql = require('../utils/graphql')
const waitForStatus = require('../utils/wait-for-status')
const checkStatus = require('../queries/check-status')
const sleep = require('../utils/sleep')

async function quiesceConflictResolution(migration) {
  const logger = new Logger(migration)

  logger.info('Waiting for conflict resolution to quiesce.')

  let state = await checkStatus(migration)
  let retries = 5

  while (state === 'CONFLICTS' && retries > 0) {
    logger.state(state)
    logger.sleep(5)
    await sleep(5)
    retries--
    state = await checkStatus(migration)
  }

  return state
}

module.exports = async migration => {
  const logger = new Logger(migration)

  logger.title('Performing import')

  // Edge case. Backend is returning no conflicts, but state may still be CONFLICTS (for a while....)
  const state = await quiesceConflictResolution(migration)

  // Sanity check, for an edge case that appears to be backend issue.
  if (state === 'CONFLICTS') {
    logger.space()
    logger.log("Import failed. Internal errror, there are unknown conflicts so we can't solve them.")
    logger.space()
    process.exit(5)
  }

  const query = `mutation ($migrationId: ID!) {
    performImport(input: { migrationId: $migrationId }) {
      migration {
        guid
        id
        state
        databaseId
      }
    }
  }`

  const variables = {
    migrationId: migration.id
  }

  await graphql(migration, query, variables)

  return await waitForStatus(migration, ['IMPORTED', 'FAILED_IMPORT'], 10)
}
