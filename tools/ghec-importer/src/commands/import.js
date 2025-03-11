const commander = require('commander')
const { run: prepareArchive, deletePreparedArchive } = require('./prepare-archive')
const getOrganizationId = require('../queries/get-organization-id')
const startImport = require('../queries/start-import')
const uploadMigrationArchive = require('../queries/upload-migration-archive')
const prepareImport = require('../queries/prepare-import')
const performImport = require('../queries/perform-import')
const unlockImportedRepositories = require('../queries/unlock-imported-repositories')
const applyMappings = require('../utils/apply-mappings')
const applyUserMappings = require('../utils/apply-user-mappings')
const loadAndResolveConflicts = require('../utils/load-and-resolve-conflicts')
const reportConflicts = require('../utils/report-conflicts')
const auditSummary = require('../utils/audit-summary')
const renameTeams = require('../utils/rename-teams')
const { run: makeInternal } = require('./make-internal')
const { run: enableFeatures, validate: validateEnableFeatures } = require('./enable-features')
const { run: deleteImported } = require('./delete-imported')
const checkStatus = require('../queries/check-status')
const sleep = require('../utils/sleep')
const Logger = require('../utils/logger')
const writeMigrationDetailsToFile = require('../utils/write-migration-detail-file')

module.exports = () => {
  const command = new commander.Command('import')

  command
    .arguments('<archive-path>')
    .description('Import a migration archive into GitHub.com', {
      archive: 'path to migration archive, e.g. ../migration.tar.gz'
    })
    .requiredOption(
      '-a, --admin-token <string>',
      'the personal access token (with scopes `admin:org`, `repo` for unlocking, `delete_repo` for deleting) of an organization owner of the GitHub.com target organization',
      process.env.GHEC_IMPORTER_ADMIN_TOKEN
    )
    .requiredOption('-t, --target-organization <string>', 'the GitHub.com organization to import into', process.env.GHEC_IMPORTER_TARGET_ORGANIZATION)
    .option(
      '-r, --remove <models>',
      "comma-separated list of models to remove before importing: projects (all projects), org-projects (organization-level projects), teams (all teams), org-teams (teams that don't belong to migrated repositories), releases (all releases)",
      value => value.split(','),
      process.env.GHEC_IMPORTER_REMOVE && process.env.GHEC_IMPORTER_REMOVE.split(',')
    )
    .option(
      '--resolve-repository-renames <string>',
      'resolve repository name conflicts by renaming the repository name, can be org-prefix or guid-suffix',
      process.env.GHEC_IMPORTER_RESOLVE_REPOSITORY_RENAMES
    )
    .option('--disallow-team-merges', 'disallow automatically merging teams, new teams will be created instead', process.env.GHEC_IMPORTER_DISALLOW_TEAM_MERGES === 'true')
    .option('--rename-teams', 'rename all teams to include the source organization name as a prefix', process.env.GHEC_IMPORTER_RENAME_TEAMS === 'true')
    .option('-I, --make-internal', 'change the visibility of migrated repositories to internal after the migration', process.env.GHEC_IMPORTER_MAKE_INTERNAL === 'true')
    .option('-D, --delete-imported', 'prompt to delete migrated repositories and teams after the migration completes (useful for dry-runs and debugging)', process.env.GHEC_IMPORTER_DELETE === 'true')
    .option('-m, --mappings-path <string>', 'path to a csv file that contains mappings to be applied before the import (modelName,sourceUrl,targetUrl,action)', process.env.GHEC_IMPORTER_MAPPINGS_PATH)
    .option(
      '-f, --enable-features <features>',
      'comma-separated list of features to enable on migrated repositories: actions,vulnerability-alerts,automated-security-fixes',
      value => value.split(','),
      process.env.GHEC_IMPORTER_ENABLE_FEATURES && process.env.GHEC_IMPORTER_ENABLE_FEATURES.split(',')
    )
    .option(
      '-u, --user-mappings-path <string>',
      'path to a csv file that contains user mappings to be applied before the import (source,target\\nuser-source,user-target)',
      process.env.GHEC_IMPORTER_USER_MAPPINGS_PATH
    )
    .option('-s, --user-mappings-source-url <string>', 'the base url for user source urls, e.g. https://source.example.com', process.env.GHEC_IMPORTER_USER_MAPPINGS_SOURCE_URL)
    .option('--staging-path <string>', 'directory to be used for storing files during preparation (if remove is specified)', 'tmp')
    .option('-d, --debug', 'display debug output')
    .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
    .option('--detail-output-file <path>', 'Write migration details to a JSON file')
    .option('--audit-summary-file <path>', 'Write audit summary to a JSON file')
    .action(run)

  return command
}

async function run(archivePath, options) {
  let migration = options
  const logger = new Logger(migration)

  if (options.userMappingsPath && !options.userMappingsSourceUrl) {
    console.error(`error: option '-s, --user-mappings-source-url <string>' is required when --user-mappings-path is specified`)
    process.exit(1)
  }

  validateEnableFeatures(migration)

  if (options.remove) {
    archivePath = await prepareArchive(archivePath, {
      ...options,
      outputPath: '.',
      suffix: 'prepared'
    })
  }

  const organizationId = await getOrganizationId(migration)

  migration['organizationId'] = organizationId

  await startImport(migration)
  writeMigrationDetailsToFile(migration, 'uploading')

  await uploadMigrationArchive(migration, archivePath)

  let state = await checkStatus(migration)
  writeMigrationDetailsToFile(migration, `upload-${state}`)

  if (state !== 'ARCHIVE_UPLOADED') {
    logger.space()
    logger.log(`Archive Upload failed.\nState is ${state}.\nQuitting`)
    logger.space()
    process.exit(2)
  }

  if (options.remove) {
    deletePreparedArchive(archivePath)
  }

  state = await prepareImport(migration)
  writeMigrationDetailsToFile(migration, `prepare-${state}`)

  if (state === 'FAILED') {
    logger.space()
    logger.log(`Failed Prepare. Archive Upload failed.\nState is ${state}.\nQuitting`)
    logger.space()
    process.exit(3)
  }

  // apply mappings with the csv
  if (options.mappingsPath) {
    state = await applyMappings(migration)
  }

  // leave for existing ppl
  if (options.userMappingsPath) {
    state = await applyUserMappings(migration)
  }

  if (state === 'FAILED') {
    logger.space()
    logger.log(`Failed to apply user mappings.\nState is ${state}.\nQuitting`)
    logger.space()
    process.exit(5)
  }

  let conflicts = await loadAndResolveConflicts(migration)

  if (options.renameTeams) {
    await renameTeams(migration)
  }

  // Stop import process if there are unresolved conflicts
  if (conflicts.length > 0) {
    await reportConflicts(migration, conflicts)
    writeMigrationDetailsToFile(migration, 'conflicts')
    process.exit(4)
  }

  writeMigrationDetailsToFile(migration, 'importing')
  let completionState = await performImport(migration)
  writeMigrationDetailsToFile(migration, `import-${completionState}`)

  if (completionState == 'FAILED_IMPORT') {
    // Retry the import if it failed as there are cases where a failed import
    // can be resolved by a single retry
    await sleep(10)
    logger.title('Retrying import')
    completionState = await performImport(migration)
    writeMigrationDetailsToFile(migration, `import-retry-${completionState}`)
  }

  let summaryTitle = completionState == 'IMPORTED' ? '🎉 Migration completed!' : '⛔️ Migration failed due to failed import'

  if (completionState != 'FAILED_IMPORT') {
    try {
      await unlockImportedRepositories(migration)
    } catch (e) {
      logger.log('Unlocked failed. Will retry one more time')
      console.error(e)
      logger.sleep(10)

      state = await checkStatus(migration)

      if (state === 'UNLOCKED') {
        logger.log('Already unlocked. No need to retry.')
      } else {
        await unlockImportedRepositories(migration)
      }
    }
    writeMigrationDetailsToFile(migration, 'unlocked')
  }

  if (completionState === 'IMPORTED' && options.makeInternal) {
    // Occasionally the API request for making a repository internal returns
    // the error "Repository has been locked for migration" with HTTP status 403.
    // Therefore we add a 10 seconds sleep to give the backend a bit more time.
    await sleep(10)

    migration.yes = true
    await makeInternal(migration)
    delete migration.yes
  }

  if (completionState === 'IMPORTED' && options.enableFeatures) {
    // Add a 10 seconds safety buffer for allowing the backend to unlock the repositories.
    await sleep(10)

    await enableFeatures(migration)
  }

  await auditSummary(migration, summaryTitle)

  if (options.deleteImported) {
    migration.models = 'repositories,teams'
    await deleteImported(migration)
  }

  if (completionState != 'IMPORTED') {
    process.exit(6)
  }
}
