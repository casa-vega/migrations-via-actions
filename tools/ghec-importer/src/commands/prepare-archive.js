const fs = require('fs')
const path = require('path')
const tar = require('tar')
const commander = require('commander')
const Logger = require('../utils/logger')

module.exports = {
  command: () => {
    const command = new commander.Command('prepare-archive')

    command
      .description('Creates a new migration archive without the models specified in the -r|--remove option')
      .arguments('<archive-path>')
      .requiredOption(
        '-r, --remove <models>',
        "projects (all projects), org-projects (organization-level projects), teams (all teams), org-teams (teams that don't belong to migrated repositories), releases (all releases)",
        value => value.split(',')
      )
      .option('-o, --output-path <string>', 'directory to create the new migration archive in', '.')
      .option('-s, --staging-path <string>', 'directory to be used for storing files during preparation', 'tmp')
      .option('-S, --suffix <string>', 'suffix to be appended to the new migration archive', 'prepared')
      .option('-d, --debug', 'display debug output')
      .option('--color', 'Force colors (use --color to force when autodetect disables colors (eg: piping))')
      .action(run)

    return command
  },
  run,
  deletePreparedArchive
}

async function run(archivePath, options) {
  const logger = new Logger(options)
  const { remove } = options
  const extension = '.tar.gz'
  const basename = path.basename(archivePath, extension)
  const preparedArchiveName = basename + '-' + options.suffix + extension
  const preparedArchivePath = path.join(options.outputPath, preparedArchiveName)

  logger.title('Preparing archive')

  const temporaryDirectory = createTemporaryDirectory(options.stagingPath)

  await tar.extract({
    file: archivePath,
    cwd: temporaryDirectory
  })

  await prepare(options, temporaryDirectory, remove)

  await tar.create(
    {
      gzip: true,
      file: preparedArchivePath,
      cwd: temporaryDirectory
    },
    fs.readdirSync(temporaryDirectory)
  )

  deleteTemporaryDirectory(temporaryDirectory)

  return preparedArchivePath
}

function createTemporaryDirectory(stagingPath) {
  const temporaryDirectory = stagingPath

  deleteTemporaryDirectory(temporaryDirectory)
  fs.mkdirSync(temporaryDirectory)

  return temporaryDirectory
}

function deleteTemporaryDirectory(temporaryDirectory) {
  fs.rmSync(temporaryDirectory, { recursive: true, force: true })
}

function deletePreparedArchive(preparedArchivePath) {
  fs.unlinkSync(preparedArchivePath)
}

async function prepare(options, temporaryDirectory, remove) {
  const logger = new Logger(options)

  const files = fs.readdirSync(temporaryDirectory)

  let repositories = []
  let teams = []

  for (const file of files) {
    const filePath = path.join(temporaryDirectory, file)

    if (remove.includes('projects') && file.startsWith('projects_')) {
      let projects = JSON.parse(fs.readFileSync(filePath, 'utf8'))

      logger.step(`Removing ${projects.length} project(s)`)
      fs.unlinkSync(filePath)
    }

    if (remove.includes('org-projects') && file.startsWith('projects_')) {
      let projects = JSON.parse(fs.readFileSync(filePath, 'utf8'))

      // Filter out organization projects
      // Repository project URL (6 slashes, 7 parts):
      // https://HOSTNAME/ORGANIZATION/REPOSITORY/projects/1
      // Organization project URL (5 slashes, 6 parts):
      // https://HOSTNAME/ORGANIZATION/projects/1
      const repositoryProjects = projects.filter(project => {
        if (project.url.split('/').length === 6) {
          logger.debug(`Removing org-project (${project.url})`)
          return false
        } else {
          return true
        }
      })

      logger.step(`Removing ${projects.length - repositoryProjects.length} org-project(s)`)

      const jsonContent = JSON.stringify(repositoryProjects, null, 2)
      fs.writeFileSync(filePath, jsonContent)
    }

    if (remove.includes('teams') && file.startsWith('teams_')) {
      let teams = JSON.parse(fs.readFileSync(filePath, 'utf8'))

      logger.step(`Removing ${teams.length} team(s)`)
      fs.unlinkSync(filePath)
    }

    if (remove.includes('org-teams')) {
      if (file.startsWith('repositories_')) {
        let fileContent = JSON.parse(fs.readFileSync(filePath, 'utf8'))

        repositories = repositories.concat(fileContent)
      }

      if (file.startsWith('teams_')) {
        let fileContent = JSON.parse(fs.readFileSync(filePath, 'utf8'))

        fs.unlinkSync(filePath)

        teams = teams.concat(fileContent)
      }
    }

    if (remove.includes('collaborators') && file.startsWith('repositories_')) {
      let repositories = JSON.parse(fs.readFileSync(filePath, 'utf8'))
      let collaborators = 0
      let repositoriesWithCollaborators = 0

      repositories = repositories.map(repository => {
        if (repository.collaborators.length) {
          collaborators += repository.collaborators.length
          repositoriesWithCollaborators++
        }

        repository.collaborators = []
        return repository
      })

      logger.step(`Removing ${collaborators} collaborator(s) from ${repositoriesWithCollaborators} repository(s)`)

      const jsonContent = JSON.stringify(repositories, null, 2)
      fs.writeFileSync(filePath, jsonContent)
    }

    // New logic for removing releases files
    if (remove.includes('releases') && file.startsWith('releases_')) {
      let releases = JSON.parse(fs.readFileSync(filePath, 'utf8'))
      logger.step(`Removing ${releases.length} release(s)`)
      fs.unlinkSync(filePath)
    }
  }

  let filteredTeams = []

  if (remove.includes('org-teams')) {
    // Only include teams with repositories that are migrated
    filteredTeams = teams.filter(team => {
      return team.permissions.some(permission => {
        return repositories.some(repository => {
          return repository.url == permission.repository
        })
      })
    })

    const organizationTeams = teams.filter(team => !filteredTeams.includes(team))

    logger.step(`Removing ${organizationTeams.length} organization team(s)`)

    const jsonContent = JSON.stringify(filteredTeams, null, 2)
    fs.writeFileSync(path.join(temporaryDirectory, 'teams_000001.json'), jsonContent)
  }
}
