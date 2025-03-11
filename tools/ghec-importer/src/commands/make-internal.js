const commander = require('commander')
const migratableResources = require('../queries/migratable-resources')
const { Octokit } = require('@octokit/rest')
const Logger = require('../utils/logger')
const proxyAgent = require('../utils/proxy-agent')
const promptly = require('promptly')
const chalk = require('chalk')

module.exports = {
  command: () => {
    const command = new commander.Command('make-internal')

    command
      .description('Change the visibility of repositories for a given GUID to internal')
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
      .action(run)

    return command
  },
  run
}

async function run(migration) {
  const logger = new Logger(migration)

  let repositories = await migratableResources(migration, 'repository')

  repositories = repositories.map(repository => repository.targetUrl)

  console.log()
  console.log(`You're about to change the visibility of the following repositories to internal:`)

  repositories.forEach(repository => {
    console.log('- ' + chalk.yellow(repository))
  })

  console.log()

  let sure
  if (!migration.yes) {
    sure = await promptly.confirm(chalk.magenta.bold('Are you really sure you want to make them internal?') + ' (y/n)')
  }

  if (migration.yes || sure) {
    const ghecAdminToken = migration.adminToken
    const proxy = proxyAgent()

    const ghecAdminOctokit = new Octokit({
      auth: ghecAdminToken,
      // Embed the proxy agent only if a proxy is used
      ...(proxy.enabled ? { request: { agent: proxy.proxyAgent } } : {})
    })

    for (const repositoryUrl of repositories) {
      const repositoryUrlParts = repositoryUrl.split('/')
      const owner = repositoryUrlParts[repositoryUrlParts.length - 2]
      const repo = repositoryUrlParts[repositoryUrlParts.length - 1]

      logger.step(`Changing repository to internal (${repositoryUrl})`)

      await ghecAdminOctokit.repos.update({
        mediaType: {
          previews: ['nebula-preview']
        },
        owner,
        repo,
        visibility: 'internal'
      })
    }
  }
}
