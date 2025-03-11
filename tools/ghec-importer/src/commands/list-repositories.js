const commander = require('commander')
const migratableResources = require('../queries/migratable-resources')

module.exports = () => {
  const command = new commander.Command('list-repositories')

  command
    .description('Lists repositories for a given GUID')
    .requiredOption('-g, --guid <string>', 'the GUID of the migration')
    .requiredOption(
      '-a, --admin-token <string>',
      'the personal access token (with admin:org scope) of an organization owner of the GitHub.com target organization',
      process.env.GHEC_IMPORTER_ADMIN_TOKEN
    )
    .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization the migration belongs to', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
    .option('-d, --debug', 'display debug output')
    .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
    .action(run)

  return command
}

async function run(migration) {
  let repositories = await migratableResources(migration, 'repository')

  repositories = repositories.map(repository => repository.targetUrl)

  repositories.forEach(repository => {
    console.log('- ' + repository)
  })
}
