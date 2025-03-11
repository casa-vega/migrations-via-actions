const fs = require("fs");
const { Octokit } = require("octokit");

let baseUrl;
if (process.env.SOURCE_HOST != "") {
  baseUrl = `https://${process.env.SOURCE_HOST}/api/v3`;
} else {
  baseUrl = `https://api.github.com`;
}

let gh = new Octokit({
  auth: process.env.SOURCE_ADMIN_TOKEN,
  baseUrl: baseUrl
});

module.exports = async ({repositories}) => {
    const repos = repositories
        .split("\n")
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
    let visibilityMap = {};
    for (const url of repos) {
        let parts = url.split("/");
        let org = parts[parts.length-2];
        let repo = parts[parts.length-1];
        const { data } = await gh.request(`GET /repos/${org}/${repo}`, {
          owner: org,
          repo: repo,
          headers: {
            'X-GitHub-Api-Version': '2022-11-28'
          }
        })
        visibilityMap[url] = data.visibility;
    };

    fs.writeFileSync("source-repos-visibility.json", JSON.stringify(visibilityMap, null, 4));
}