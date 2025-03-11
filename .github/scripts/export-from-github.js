const fs = require("fs");
const { Octokit } = require("octokit");

function sleep(delay) {
  var start = new Date().getTime();
  while (new Date().getTime() < start + delay);
}

let gh = new Octokit({
  baseUrl: "https://api.github.com",
  auth: process.env.SOURCE_ADMIN_TOKEN,
});

const repos = fs
  .readFileSync(
    `${process.env.MIGRATION_GUID}/repositories.txt`
  )
  .toString()
  .split("\n")
  .map((s) => s.trim())
  .filter((s) => s.length > 0);

const org = repos[0].split("/")[0];
console.log(repos);
console.log(org);

function runMigration(lock_repositories = false) {
  gh.rest.migrations
    .startForOrg({
      org: org,
      repositories: repos,
      lock_repositories: lock_repositories,
    })
    .then(async (response) => {
      let active = true;
      while (active) {
        await gh.rest.migrations
          .getStatusForOrg({
            org: org,
            migration_id: response.data.id,
          })
          .then(async (res) => {
            if (res.data.state == "pending") {
              console.log(`pending... migration_id: ${response.data.id}`);
              sleep(10000);
            } else if (res.data.state == "exporting") {
              console.log("exporting...");
              sleep(10000);
            } else if (res.data.state == "exported") {
              const filename = `${process.env.MIGRATION_GUID}.tar.gz`;
              await gh.rest.migrations
                .downloadArchiveForOrg({
                  org: org,
                  migration_id: response.data.id,
                })
                .then((res) => {
                  fs.appendFileSync(
                    `${process.env.MIGRATION_GUID}/${filename}`,
                    Buffer.from(res.data)
                  );
                  console.log(`created migration archive: ${filename}`);
                  active = false;
                });
            } else if (res.data.state == "failed") {
              console.log(`${res.data}:\n\nfailed`);
              process.exit(1);
            }
          })
          .catch((err) => {
            console.log(err);
            process.exit(1);
          });
      }
    });
}

module.exports = {
  runMigration: runMigration,
};
