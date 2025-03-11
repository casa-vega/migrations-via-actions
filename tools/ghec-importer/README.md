# ghec-importer

A command-line utility for importing repositories into GitHub Enterprise Cloud.

## Prerequisites

This utility uses a GraphQL API (the same as ECI) that is only available for Professional Services customers.  
Please [contact them](https://services.github.com/#services-contact) for access and questions.

<!-- prettier-ignore-start -->
> [!IMPORTANT]
> `ghec-importer` generally requires Node.js `v16` to work. Later versions of Node.js are not supported.
<!-- prettier-ignore-end -->

## Setup

```sh
cd ghec-importer
npm set-script prepare ""  # avoid failed installs due to husky
npm install
npm link
```

### GHES 3.x & Node 10

For customers migrating from GHES, `ghec-importer` needs the latest Node 14 or 16 to run, which are newer than the Node 10 bundled with GHES 3.4 and older.

You can use [node version manager (`nvm`)](https://github.com/nvm-sh/nvm#install--update-script) to install a local copy that is safe to use:

```shell
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
nvm install 14  # or nvm install 16
node --version
```

Once you do this, follow the above [setup](#setup) to download and link Node dependencies to this local version of Node.

## Commands

```
$ ghec-importer -h
Usage: ghec-importer [options] [command]

Options:
  -h, --help                                display help for command

Commands:
  prepare-archive [options] <archive-path>  Creates a new migration archive without the models specified in the -r|--remove option
  import [options] <archive-path>           Import a migration archive into GitHub.com
  audit [options]                           Lists all migratable resources for a given GUID in a comma separated list (CSV)
  audit-summary [options]                   Lists repositories and teams as well as total number of imported/to be imported records for a given
                                            GUID
  make-internal [options]                   Change the visibility of repositories for a given GUID to internal
  list-repositories [options]               Lists repositories for a given GUID
  enable-features [options]                 Enable features in repositories for a given GUID
  delete-imported [options]                 Delete imported models for a given GUID
  get-details [options]                     Gets migration details for a given GUID
  help [command]                            display help for command
```

### prepare-archive

```sh
$ ghec-importer prepare-archive -h
Usage: ghec-importer prepare-archive [options] <archive-path>

Creates a new migration archive without the models specified in the -r|--remove option

Options:
  -r, --remove <models>        projects (all projects), org-projects (organization-level projects),
                               teams (all teams), org-teams (teams that don't belong to migrated repositories), releases (all releases)
  -o, --output-path <string>   directory to create the new migration archive in (default: ".")
  -s, --staging-path <string>  directory to be used for storing files during preparation (default: "tmp")
  -S, --suffix <string>        suffix to be appended to the new migration archive (default: "prepared")
  -d, --debug                  display debug output
  --color                      Force colors (use --color to force when autodetect disables colors (eg: piping))
  -h, --help                   display help for command
```

### import

```sh
$ ghec-importer import -h
Usage: ghec-importer import [options] <archive-path>

Import a migration archive into GitHub.com

Options:
  -a, --admin-token <string>               the personal access token (with scopes `admin:org`, `repo` for unlocking, `delete_repo` for deleting)
                                           of an organization owner of the GitHub.com target organization
  -t, --target-organization <string>       the GitHub.com organization to import into
  -r, --remove <models>                    comma-separated list of models to remove before importing: projects (all projects),
                                           org-projects (organization-level projects), teams (all teams), org-teams (teams that do not belong to migrated repositories)
  --resolve-repository-renames <string>    resolve repository name conflicts by renaming the repository name, can be org-prefix or guid-suffix
  --disallow-team-merges                   disallow automatically merging teams, new teams will be created instead (default: false)
  --rename-teams                           rename all teams to include the source organization name as a prefix (default: false)
  -I, --make-internal                      change the visibility of migrated repositories to internal after the migration (default: false)
  -D, --delete-imported                    prompt to delete migrated repositories and teams after the migration completes (useful for dry-runs
                                           and debugging) (default: false)
  -m, --mappings-path <string>             path to a csv file that contains mappings to be applied before the import
                                           (modelName,sourceUrl,targetUrl,action)
  -f, --enable-features <features>         comma-separated list of features to enable on migrated repositories:
                                           actions,vulnerability-alerts,automated-security-fixes
  -u, --user-mappings-path <string>        path to a csv file that contains user mappings to be applied before the import
                                           (source,target\nuser-source,user-target)
  -s, --user-mappings-source-url <string>  the base url for user source urls, e.g. https://source.example.com
  --staging-path <string>                  Directory to be used for storing files during preparation (if remove is specified) (defaults to tmp)
  -d, --debug                              display debug output
  --color                                  Force colors (use --color to force when autodetect disables colors (eg: piping))
  --detail-output-file <path>              Write migration details to a JSON file
  --audit-summary-file <path>              Write audit summary to a JSON file
  -h, --help                               display help for command
```

#### Additional notes

- Mapping CSV files require a header and the actions are case sensitive (example below)
  ```
  modelName,sourceUrl,targetUrl,action
  repository,http://github.dev/acme/widgets,https://github.com/acme-new/widgets-new,RENAME
  ```

### audit

```sh
$ ghec-importer audit -h
Usage: ghec-importer audit [options]

Lists all migratable resources for a given GUID in a comma separated list (CSV)

Options:
  -g, --guid <string>                 the GUID of the migration
  -a, --admin-token <string>          the personal access token (with admin:org scope) of an organization owner of the GitHub.com target
                                      organization
  -t, --target-organization <string>  the GitHub.com organization the migration belongs to
  --filter-state <state>              Filter by resource state. Eg FAILED
  --model <model>                     Filter by model name. Eg repository
  -d, --debug                         display debug output
  --color                             Force colors (use --color to force when autodetect disables colors (eg: piping))
  -h, --help                          display help for command
```

### audit-summary

```sh
$ ghec-importer audit-summary -h
Usage: ghec-importer audit-summary [options]

Lists repositories and teams as well as total number of imported/to be imported records for a given GUID

Options:
  -g, --guid <string>                 the GUID of the migration
  -a, --admin-token <string>          the personal access token (with admin:org scope) of an organization owner of the GitHub.com target
                                      organization
  -t, --target-organization <string>  the GitHub.com organization the migration belongs to
  --audit-summary-file <path>         Write audit summary to a JSON file
  -d, --debug                         display debug output
  --color                             Force colors (use --color to force when autodetect disables colors (eg: piping))
  -h, --help                          display help for command
```

### list-repositories

```sh
❯ ghec-importer list-repositories -h
Usage: ghec-importer list-repositories [options]

Lists repositories for a given GUID

Options:
  -g, --guid <string>                 the GUID of the migration
  -a, --admin-token <string>          the personal access token (with admin:org scope) of an organization owner of the GitHub.com target
                                      organization
  -t, --target-organization <string>  the GitHub.com organization the migration belongs to
  -d, --debug                         display debug output
  --color                             Force colors (use --color to force when autodetect disables colors (eg: piping))
  -h, --help                          display help for command
```

### delete-imported

```sh
$ ghec-importer delete-imported -h
Usage: ghec-importer delete-imported [options]

Delete imported models for a given GUID

Options:
  -g, --guid <string>                 the GUID of the migration
  -a, --admin-token <string>          the personal access token (with admin:org scope) of an organization owner of the GitHub.com target
                                      organization
  -t, --target-organization <string>  the GitHub.com organization the migration belongs to
  -y, --yes                           do not prompt for confirmation
  -d, --debug                         display debug output
  --color                             Force colors (use --color to force when autodetect disables colors (eg: piping))
  -m, --models <models>               comma-separated list of models to delete (repositories, teams) (default: "repositories")
  -h, --help                          display help for command
```
