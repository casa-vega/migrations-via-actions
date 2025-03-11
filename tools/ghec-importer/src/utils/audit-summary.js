const core = require('@actions/core')
const Formatter = require('../utils/formatter')
const Logger = require('../utils/logger')
const comment = require('../utils/comment')
const migratableResources = require('../queries/migratable-resources')
const migratableResourcesTotals = require('../queries/migratable-resources-totals')
const checkStatus = require('../queries/check-status')
const auditSummaryWriter = require('./write-audit-summary-file')

module.exports = async (migration, title) => {
  const logger = new Logger(migration)
  const formatter = new Formatter(migration)

  title = title || 'Audit summary'

  let repositories = await migratableResources(migration, 'repository')
  let teams = await migratableResources(migration, 'team')

  const totals = await migratableResourcesTotals(migration)

  auditSummaryWriter(migration, repositories, teams, totals)

  migration.state = await checkStatus(migration)

  // don't remove admin token from migration object as it may be used by subsequent functions (e.g. delete repositories)
  const migrationDetails = Object.assign({}, migration)

  delete migrationDetails.adminToken
  delete migrationDetails.uploadUrl

  if (process.env.GITHUB_REPOSITORY) {
    const body = `
    ## ${title}

    ### Repositories

    ${formatter.recordsList(repositories)}

    ### Teams

    ${formatter.recordsList(teams)}

    ### Number of records

    ${formatter.table(totals, ['type', 'succeeded', 'failed'], ['Type', 'Succeeded', 'Failed'])}

    `

    await comment(formatter.body(body) + formatter.details('Migration details', migrationDetails))

    core.setOutput('migration-guid', migration.guid)
    core.setOutput('migration-id', migration.id)
    core.setOutput('migration-organization-id', migration.organizationId)
    core.setOutput('migration-repositories', repositories.map(repo => repo.targetUrl).join(','))
    core.setOutput('migration-repository-records', JSON.stringify(repositories))
  } else {
    logger.debugEnd()
    console.log()
    console.log(title)
    console.log()
    console.log('Repositories')
    console.log(formatter.recordsList(repositories))
    console.log('Teams')
    console.log(formatter.recordsList(teams))
    console.log('Number of records')
    console.table(totals, ['type', 'succeeded', 'failed'])
    console.log()
    console.log('Migration details:')
    console.log(migrationDetails)
  }
}
