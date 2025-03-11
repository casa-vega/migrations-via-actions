const commander = require('commander')
const auditSummary = require('../utils/audit-summary')

module.exports = () => {
  const command = new commander.Command('audit-summary')

  command
    .description('Lists repositories and teams as well as total number of imported/to be imported records for a given GUID')
    .requiredOption('-g, --guid <string>', 'the GUID of the migration')
    .requiredOption(
      '-a, --admin-token <string>',
      'the personal access token (with admin:org scope) of an organization owner of the GitHub.com target organization',
      process.env.GHEC_IMPORTER_ADMIN_TOKEN
    )
    .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization the migration belongs to', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
    .option('--audit-summary-file <path>', 'Write audit summary to a JSON file')
    .option('-d, --debug', 'display debug output')
    .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
    .action(run)

  return command
}

async function run(options) {
  return auditSummary(options)
}
