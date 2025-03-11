const Formatter = require('../utils/formatter')
const Logger = require('../utils/logger')
const comment = require('../utils/comment')

module.exports = async (migration, conflicts) => {
  const logger = new Logger(migration)
  const formatter = new Formatter(migration)

  const title = '⛔️ Migration failed due to conflicts'

  // don't remove admin token from migration object as it may be used by subsequent functions (e.g. delete repositories)
  const migrationDetails = Object.assign({}, migration)

  delete migrationDetails.state
  delete migrationDetails.adminToken
  delete migrationDetails.uploadUrl

  if (process.env.GITHUB_REPOSITORY) {
    const body = `
    ## ${title}

    ### Conflicts

    ${formatter.table(conflicts, ['modelName', 'sourceUrl', 'targetUrl', 'recommendedAction', 'notes'], ['Model name', 'Source URL', 'Target URL', 'Recommended action', 'Notes'])}

    `

    await comment(formatter.body(body) + formatter.details('Migration details', migrationDetails))
  } else {
    logger.debugEnd()
    console.log()
    console.log(title)
    console.log()
    console.log('Conflicts')
    console.table(conflicts)
    console.log()
    console.log('Migration details:')
    console.log(migrationDetails)
  }
}
