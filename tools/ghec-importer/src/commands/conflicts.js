const loadConflicts = require('../queries/load-conflicts')
const comment = require('../utils/comment')

module.exports = async migration => {
  const conflicts = await loadConflicts(migration)

  comment(conflicts)

  console.log(conflicts)
}
