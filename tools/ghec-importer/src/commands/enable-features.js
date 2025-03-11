const commander = require('commander')
const migratableResources = require('../queries/migratable-resources')
const { Octokit } = require('@octokit/rest')
const Logger = require('../utils/logger')
const proxyAgent = require('../utils/proxy-agent')

const VALID_FEATURES_LIST = ['actions', 'vulnerability-alerts', 'automated-security-fixes']

module.exports = Object.create(null, {
  command: {
    value: () => {
      const command = new commander.Command('enable-features')

      command
        .description('Enable features in repositories for a given GUID')
        .requiredOption('-g, --guid <string>', 'the GUID of the migration')
        .requiredOption(
          '-a, --admin-token <string>',
          'the personal access token (with admin:org scope) of an organization owner of the GitHub.com target organization',
          process.env.GHEC_IMPORTER_ADMIN_TOKEN
        )
        .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization the migration belongs to', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
        .requiredOption(
          '-f, --features <features>',
          'comma-separated list of features to enable on migrated repositories: actions,vulnerability-alerts,automated-security-fixes',
          value => value.split(','),
          process.env.GHEC_IMPORTER_ENABLE_FEATURES && process.env.GHEC_IMPORTER_ENABLE_FEATURES.split(',')
        )
        .option('-d, --debug', 'display debug output')
        .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
        .action(run)

      return command
    }
  },
  run: { value: run },
  validate: { value: validate },
  // VALID_FEATURES_LIST has been exposed only to support testing
  VALID_FEATURES_LIST: { get: () => VALID_FEATURES_LIST }
})

// The 'enable-features' command provides the `features` option
// whereas the'import' command provides the `enableFeatures` option.
function validate({ features, enableFeatures } = {}) {
  const invalidFeatures = (features || enableFeatures || []).filter(feature => !VALID_FEATURES_LIST.includes(feature))

  if (invalidFeatures.length) {
    console.error(`error: invalid features to enable: ${invalidFeatures.join(', ')}`)
    process.exit(7)
  }
}

async function run(migration) {
  const logger = new Logger(migration)
  const features = migration.features || migration.enableFeatures

  if (features.length) {
    validate(migration)

    const ghecAdminToken = migration.adminToken
    const proxy = proxyAgent()

    const ghecAdminOctokit = new Octokit({
      auth: ghecAdminToken,
      // Embed the proxy agent only if a proxy is used
      ...(proxy.enabled ? { request: { agent: proxy.proxyAgent } } : {})
    })

    let repositories = await migratableResources(migration, 'repository')
    repositories = repositories.map(repository => repository.targetUrl)

    logger.space()

    for (const repositoryUrl of repositories) {
      const repositoryUrlParts = repositoryUrl.split('/')
      const repo = repositoryUrlParts.pop()
      const owner = repositoryUrlParts.pop()

      if (features.includes('actions')) {
        logger.step(`Enabling actions for repository (${repositoryUrl})`)

        await ghecAdminOctokit.actions.setGithubActionsPermissionsRepository({
          owner,
          repo,
          enabled: true
        })
      }

      if (features.includes('vulnerability-alerts')) {
        logger.step(`Enabling vulnerability alerts for repository (${repositoryUrl})`)

        await ghecAdminOctokit.repos.enableVulnerabilityAlerts({
          owner,
          repo
        })
      }

      if (features.includes('automated-security-fixes')) {
        logger.step(`Enabling automated security fixes for repository (${repositoryUrl})`)

        await ghecAdminOctokit.repos.enableAutomatedSecurityFixes({
          owner,
          repo
        })
      }
    }
  }
}
