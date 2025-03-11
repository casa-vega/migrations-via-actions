const commander = require('commander')
const migratableResources = require('../queries/migratable-resources')
const { Octokit } = require('@octokit/rest')
const Formatter = require('../utils/formatter')
const Logger = require('../utils/logger')
const comment = require('../utils/comment')
const promptly = require('promptly')
const chalk = require('chalk')
const proxyAgent = require('../utils/proxy-agent')

module.exports = {
  command: () => {
    const command = new commander.Command('delete-imported')

    command
      .description('Delete imported models for a given GUID')
      .requiredOption('-g, --guid <string>', 'the GUID of the migration')
      .requiredOption(
        '-a, --admin-token <string>',
        'the personal access token (with admin:org scope) of an organization owner of the GitHub.com target organization',
        process.env.GHEC_IMPORTER_ADMIN_TOKEN
      )
      .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization the migration belongs to', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
      .option('-y, --yes', 'do not prompt for confirmation')
      .option('-d, --debug', 'display debug output')
      .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
      .option('-m, --models <models>', 'comma-separated list of models to delete (repositories, teams)', 'repositories')
      .action(run)

    return command
  },
  run
}

async function run(migration) {
  const logger = new Logger(migration)
  const formatter = new Formatter(migration)

  let repositories = await migratableResources(migration, 'repository')

  repositories = repositories.map(repository => repository.targetUrl)

  let teams = await migratableResources(migration, 'team')
  teams = teams.map(team => team.targetUrl)

  console.log()
  if (migration.models.includes('repositories')) {
    console.log("You're about to delete the following repositories:")

    repositories.forEach(repository => {
      console.log('- ' + chalk.yellow(repository))
    })
  }
  if (migration.models.includes('teams')) {
    console.log("You're about to delete the following teams:")

    teams.forEach(team => {
      console.log('- ' + chalk.yellow(team))
    })
  }

  console.log()

  let sure
  if (!migration.yes) {
    sure = await promptly.confirm(chalk.magenta.bold('Are you really sure you want to delete them?') + ' (y/n)')
  }

  if (migration.yes || sure) {
    const ghecAdminToken = migration.adminToken
    const proxy = proxyAgent()

    const ghecAdminOctokit = new Octokit({
      auth: ghecAdminToken,
      // Embed the proxy agent only if a proxy is used
      ...(proxy.enabled ? { request: { agent: proxy.proxyAgent } } : {})
    })

    if (migration.models.includes('repositories')) {
      for (const repositoryUrl of repositories) {
        const repositoryUrlParts = repositoryUrl.split('/')
        const owner = repositoryUrlParts[repositoryUrlParts.length - 2]
        const repo = repositoryUrlParts[repositoryUrlParts.length - 1]

        logger.step(`Deleting repository (${repositoryUrl})`)
        try {
          await ghecAdminOctokit.repos.delete({
            owner,
            repo
          })
        } catch (error) {
          logger.step(`Failed to delete repo ${error}`)
        }
      }
    }

    if (migration.models.includes('teams')) {
      for (const teamUrl of teams) {
        const teamUrlParts = teamUrl.split('/')
        const owner = teamUrlParts[teamUrlParts.length - 3]
        const team = teamUrlParts[teamUrlParts.length - 1]

        logger.step(`Deleting team (${teamUrl})`)
        try {
          await ghecAdminOctokit.teams.deleteInOrg({
            org: owner,
            team_slug: team
          })
        } catch (error) {
          logger.step(`Failed to delete team ${error}`)
        }
      }
    }

    if (process.env.GITHUB_REPOSITORY) {
      const body = `
        ## 🗑 Deleted repositories
    
        The following repositories have been deleted:
    
        ${formatter.bulletList(repositories)}
      `

      await comment(formatter.body(body))
    }
  }
}
