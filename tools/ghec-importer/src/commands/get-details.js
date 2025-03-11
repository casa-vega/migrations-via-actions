const commander = require('commander')
const getMigration = require('../queries/get-migration')

module.exports = () => {
  const command = new commander.Command('get-details')

  command
    .description('Gets migration details for a given GUID')
    .requiredOption('-g, --guid <string>', 'the GUID of the migration')
    .requiredOption(
      '-a, --admin-token <string>',
      'the personal access token (with admin:org scope) of an organization owner of the GitHub.com target organization',
      process.env.GHEC_IMPORTER_ADMIN_TOKEN
    )
    .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization the migration belongs to', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
    .option('--include-conflicts', 'To get conflicts information included in the result.')
    .option('-d, --debug', 'display debug output')
    .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping')
    .action(run)

  return command
}

async function run(migration) {
  let migrationDetails = await getMigration(migration)
  console.log('Migration details:')
  console.log(migrationDetails)
}
