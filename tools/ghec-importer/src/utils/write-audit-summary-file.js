const Logger = require('./logger')
const fs = require('fs')

function getName(repoUrl) {
  if (!repoUrl) return ''

  const url = new URL(repoUrl)

  return url.pathname.substring(1)
}

module.exports = async (migration, repositories, teams, totals) => {
  const logger = new Logger(migration)

  if (!migration.auditSummaryFile) return

  logger.info('Writing audit summary file')

  const repos = repositories.map(repo => {
    return {
      source: getName(repo.sourceUrl),
      target: getName(repo.targetUrl),
      state: repo.state,
      warning: repo.warning
    }
  })

  const teamsData = teams.map(team => {
    return {
      source: team.sourceUrl,
      target: team.targetUrl,
      state: team.state,
      warning: team.warning
    }
  })

  const auditSummaryObject = {
    repos,
    teams: teamsData,
    totals
  }

  try {
    fs.writeFileSync(migration.auditSummaryFile, JSON.stringify(auditSummaryObject, null, 2))
  } catch (err) {
    logger.info(`Error writing audit summary to file: ${err.message}. Will continue`)
  }
}
