const fs = require("fs");
const { Octokit } = require("octokit");

let gh = new Octokit({
  auth: process.env.TARGET_ADMIN_TOKEN,
});

module.exports = async ({organization}) => {
    // read source-repos-visibility.json and set the visibility of the target repos
    const visibilityMap = JSON.parse(fs.readFileSync("source-repos-visibility.json"));
    const org = organization;
    for (const url of Object.keys(visibilityMap)) {
        let visibility = visibilityMap[url];
        // if visility == "public" then set the visibility to "internal"
        visibility = visibility == "public" ? "internal" : visibility;
        if (visibility != "private") {
            let parts = url.split("/");
            let repo = parts[parts.length-1];
            await gh.request(`PATCH /repos/${org}/${repo}`, {
              owner: org,
              repo: repo,
              visibility: visibility,
              headers: {
                'X-GitHub-Api-Version': '2022-11-28'
              }
            })
        }
    }
}