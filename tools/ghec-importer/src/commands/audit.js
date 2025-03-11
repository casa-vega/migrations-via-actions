const commander = require('commander')
const migratableResources = require('../queries/migratable-resources')

module.exports = () => {
  const command = new commander.Command('audit')

  command
    .description('Lists all migratable resources for a given GUID in a comma separated list (CSV)')
    .requiredOption('-g, --guid <string>', 'the GUID of the migration')
    .requiredOption(
      '-a, --admin-token <string>',
      'the personal access token (with admin:org scope) of an organization owner of the GitHub.com target organization',
      process.env.GHEC_IMPORTER_ADMIN_TOKEN
    )
    .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization the migration belongs to', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
    .option('--filter-state <state>', 'Filter by resource state. Eg FAILED')
    .option('--model <model>', 'Filter by model name. Eg repository')
    .option('-d, --debug', 'display debug output')
    .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
    .action(run)

  return command
}

async function run(migration) {
  let records = await migratableResources(migration, migration.model)

  let recordsArrays = records.map(({ modelName, sourceUrl, targetUrl, state }) => {
    return [modelName, sourceUrl, targetUrl, state]
  })

  recordsArrays.forEach(record => {
    console.log(record.join(','))
  })
}
