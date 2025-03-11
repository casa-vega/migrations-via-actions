# Setup Guide

When using this codebase to migrate repos in your own organization, here are a few things that will need to be created/modified:

## Variables & Secrets

Create these [variables](https://docs.github.com/en/actions/learn-github-actions/variables#creating-configuration-variables-for-a-repository) and [secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository) on the repository that is hosting this migration utility according to the table above.

See [Variable and Secret Automation](#variable-secret-script) for a script to automate the creation of variables and secrets.

There are several migration workflows that can be used to migrate repositories from various sources to GitHub.com. Each workflow is configured to migrate repositories from a specific source to a specific target. The following table lists the available workflows and their configurations.

| Issue Template Name | Workflow Name | Source | Target | Vars | Secrets | Notes |
|---------------|---------------|--------|--------|-------|-------|-------|
| GitLab to GitHub migration | `.github/workflows/migration-gitlab.yml` | GitLab Server | GitHub.com | SOURCE_ADMIN_USERNAME SOURCE_HOST TARGET_ORGANIZATION | SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |
| GitHub Enterprise Server to GitHub migration | `.github/workflows/migration-github-enterprise-server.yml` | GHES | GitHub.com | SOURCE_HOST TARGET_ORGANIZATION | SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |
| GHES/GHEC repos to GitHub migration [GEI] | `.github/workflows/migration-github-repos-gei.yml` | GHES or GitHub.com | GitHub.com | SOURCE_HOST** TARGET_ORGANIZATION INSTALL_PREREQS*** AWS_REGION* AWS_BUCKET_NAME* | TARGET_ADMIN_TOKEN SOURCE_ADMIN_TOKEN AZURE_STORAGE_CONNECTION_STRING* AWS_ACCESS_KEY_ID* AWS_SECRET_ACCESS_KEY* | Uses [GEI](https://github.com/github/gh-gei) |
| GitHub.com Organization to GHEC EMU migration [GEI] | `.github/workflows/migration-github-org-gei.yml` | GitHub.com | GitHub.com | ENTERPRISE INSTALL_PREREQS*** | TARGET_ADMIN_TOKEN SOURCE_ADMIN_TOKEN | Uses [GEI](https://github.com/github/gh-gei) |
| GitHub to GitHub Enterprise Server migration | `.github/workflows/migration-github-enterprise-cloud.yml` | GitHub.com | GHES | TARGET_ADMIN_USERNAME TARGET_HOST | GHES_ADMIN_SSH_PRIVATE_KEY SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |
| BitBucket Server to GitHub Enterprise Server migration | `.github/workflows/migration-bitbucket-ghes.yml` | BitBucket Server | GHES | SOURCE_ADMIN_USERNAME SOURCE_HOST TARGET_ADMIN_USERNAME TARGET_HOST | GHES_ADMIN_SSH_PRIVATE_KEY SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |
| BitBucket Server to GitHub migration | `.github/workflows/migration-bitbucket-ghes.yml` | BitBucket Server | GitHub.com | SOURCE_HOST TARGET_ORGANIZATION | SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |
| BitBucket Server to GitHub migration [GEI] | `.github/workflows/migration-bitbucket-gei.yml` | BitBucket Server | GitHub.com | BITBUCKET_SERVER_URL BITBUCKET_USERNAME TARGET_ORGANIZATION BITBUCKET_SSH_USER BITBUCKET_SSH_PORT BITBUCKET_ARCHIVE_DOWNLOAD_HOST**** BITBUCKET_SHARED_HOME**** AWS_REGION AWS_BUCKET_NAME INSTALL_PREREQS*** | BITBUCKET_PASSWORD BITBUCKET_SSH_KEY TARGET_ADMIN_TOKEN AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY | Uses [GEI](https://github.com/github/gh-gei) |
| Azure DevOps to GitHub migration [GEI] | `.github/workflows/shared-gei-azure-devops.yml` | Azure DevOps | GitHub.com | TARGET_ORGANIZATION INSTALL_PREREQS*** | SOURCE_ADMIN_TOKEN TARGET_ADMIN_TOKEN | |

> [!NOTE]
> - \* When source is **GHES 3.7 and earlier** you need to define blob storage for GEI. To use Azure blob storage, define `AZURE_STORAGE_CONNECTION_STRING`. To use AWS blob storage, define `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, and `AWS_BUCKET_NAME`.
> - ** When source is GHES, you need to define `SOURCE_HOST`.
> - *** For GEI, you can set `INSTALL_PREREQS` to `false` to opt out of installing GEI and other prerequisites during the workflow run. If the variable is unset, it defaults to `true`.
> - **** For GEI with BitBucket Server, `BITBUCKET_ARCHIVE_DOWNLOAD_HOST` is only needed it using BBS Data Center cluster or if using a load balancer. `BITBUCKET_SHARED_HOME` can be set if your BitBucket Server is not using the default shared home directory.
> - Token requirements:
>   - **`SOURCE_ADMIN_TOKEN`** must have the `repo` and `admin:org` scopes set (for GitHub-based sources)
>   - **`TARGET_ADMIN_TOKEN`** must have the `admin:org`, `workflow` (if GEI), and `delete_repo` scopes set.

### Variable Secret Script

Review the following files:

- [.env.variables](.env.variables) - For Variables
- [.env.example](.env.example) - For Secrets Example

Once you have decided based on the chart above which variable and secrets you need to create, copy the `.env.example` and create your own `.env`. Then you can use the [setup-vars-and-secrets.sh](setup-vars-and-secrets.sh) script to automate the process.

To learn how to use the script run:

```bash
./setup-vars-and-secrets.sh -h
```

## Issue Labels

Verify that the [bootstrap actions](.github/workflows/bootstrap.yml) ran successfully as it creates the necessary issue labels. If not, create the following [issue labels](https://docs.github.com/en/issues/using-labels-and-milestones-to-track-work/managing-labels#creating-a-label):

1. `migration` (for all)
2. `github-enterprise-server` (for ghes)
3. `github-enterprise-cloud` (for github.com)
4. `gitlab` (for gitlab)
5. `gei` (for GEI)
6. `gei-org` (for GEI)
7. `bitbucket` (for BBS to GitHub.com)
8. `bitbucket-ghes` (for BBS to GHES)
9. `bitbucket-gei` (for BBS to GitHub.com with GEI)
10. `gei-azure-devops` (for Azure DevOps to GitHub.com)

## SSH Key setup

### GHES

For GHES Imports: The script needs to be able to SSH into the GitHub Enterprise Server instance. Add an SSH public key to the [GitHub Enterprise Server admin console](https://docs.github.com/en/enterprise-server@3.13/admin/configuration/configuring-your-enterprise/accessing-the-administrative-shell-ssh#enabling-access-to-the-administrative-shell-via-ssh). Create a repo secret named `GHES_ADMIN_SSH_PRIVATE_KEY` and use the contents of the SSH private key as the value. Instructions on creating and/or exporting the public key are below:

- [Creating public key](https://git-scm.com/book/en/v2/Git-on-the-Server-Generating-Your-SSH-Public-Key)
- Export public key to console: `cat ~/.ssh/id_rsa.pub`

### BitBucket Server (GEI)

SSH key for GEI needs to be in OpenSSH pem format.

Tip for creating a duplicate of your local SSH key and converting to OpenSSH pem format:

```bash
cp id_rsa id_rsa-backup && ssh-keygen -p -f id_rsa -m PEM && mv id_rsa id_rsa.pem && mv id_rsa-backup id_rsa
```

### External Actions in GHES / Self-Hosted Runners

When Importing into GHES, the following external actions need to be [synced](https://docs.github.com/en/enterprise-server@3.9/admin/github-actions/managing-access-to-actions-from-githubcom/manually-syncing-actions-from-githubcom#example-using-the-actions-sync-tool) to the GHES instance:

- [stefanbuck/github-issue-parser@v3](https://github.com/stefanbuck/github-issue-parser)
- [ruby/setup-ruby@v1](https://github.com/ruby/setup-ruby)

> [!NOTE]
> - This will only be needed when the `migrations-via-actions` repo is in a GHES instance (e.g., migrating into a GHES instance) with no [GitHub Connect](https://docs.github.com/en/enterprise-server@3.13/admin/github-actions/managing-access-to-actions-from-githubcom/about-using-actions-in-your-enterprise#configuring-access-to-actions-on-githubcom)
> - The Organization name can be different than the above when using the `actions-sync` command. Just take note that at the time of running `actions-sync`, both the organization and repository(empty) need to exist before running the command.

### Runner Setup

If necessary, update the self-hosted runner label in your workflow so that it picks up the designated runner - the runner label otherwise defaults to `self-hosted`. Runners need to the following software installed:

- curl, wget, unzip, ssh, jq, git
- For GEI migrations:
  - The appropriate binary (`gei`, `bbs2gh`, `ado2gh`) needs to be installed in the runner's PATH
  - `pwsh` is also required for GEI migrations
  - By default, these are installed during the workflow run, but can be disabled by setting the repo variable `INSTALL_PREREQS` to `false`
- libyaml-dev, build-essential, libncurses5-dev, libsqlite3-dev (*only needed for `bbs-exporter` (non-GEI) BitBucket Server migration*)

### Note on GEI Migrations

- Ensure that the `SOURCE_ADMIN_TOKEN` and `TARGET_ADMIN_TOKEN` tokens have the [appropriate PAT scopes](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/managing-access-for-a-migration-between-github-products#required-scopes-for-personal-access-tokens) for running a migration or has been [granted the migrator role](https://docs.github.com/en/migrations/using-github-enterprise-importer/migrating-between-github-products/managing-access-for-a-migration-between-github-products#granting-the-migrator-role)

### Note on GitLab Exports

Working through the `gl-exporter` ruby runtime [requirements](/tools/gl-exporter/docs/Requirements.md) can sometimes be tricky. It's possible to build and push the [Dockerfile](/tools/gl-exporter/Dockerfile) to the repository and run as a container job:

```yml
jobs:
  export:
    name: Export
    runs-on: ${{ inputs.runner }}
    container:
      image: 'ghcr.io/${{ github.repository }}:latest'
      credentials:
         username: ${{ github.ref }}
         password: ${{ secrets.GITHUB_TOKEN }}
```

### Note on Tools

This repo isn't intended to have the latest copies of the [ghec-importer](https://github.com/github/ghec-importer), [gl-exporter](https://github.com/github/gl-exporter) and [bbs-exporter](https://github.com/github/bbs-exporter). If desired, grab the latest versions of the code and update the copy in the `./tools` directory.
