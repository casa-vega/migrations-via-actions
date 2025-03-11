const github = require('@actions/github')

module.exports = async body => {
  let issue

  if (process.env.GHEC_IMPORTER_ISSUE) {
    let issueParameters = process.env.GHEC_IMPORTER_ISSUE.split('/')

    issue = {
      owner: issueParameters[0],
      repo: issueParameters[1],
      issue_number: issueParameters[3]
    }
  } else if (process.env.GITHUB_REPOSITORY) {
    const context = github.context

    console.log('context', context)

    issue = {
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: context.issue.number
    }
  }

  // if no issue details are given, don't post a comment
  if (!issue && !issue.issue_number) {
    return
  }

  const octokit = github.getOctokit(process.env.GITHUB_TOKEN)

  await octokit.rest.issues.createComment({
    ...issue,
    body
  })
}
