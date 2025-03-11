const path = require('path')

module.exports = (migration, userMappings) => {
  let mappings = userMappings
    .map(mapping => {
      if (mapping) {
        mapping = mapping.split(',')

        let sourceUrl
        if (mapping[0].startsWith('http')) sourceUrl = mapping[0]
        else {
          sourceUrl = new URL(migration.userMappingsSourceUrl)
          sourceUrl.pathname = path.join(sourceUrl.pathname, mapping[0])
        }
        const targetUrl = mapping[1].startsWith('http') ? mapping[1] : `https://github.com/${mapping[1]}`

        return `{
        modelName: "user",
        sourceUrl: "${sourceUrl}",
        targetUrl: "${targetUrl}",
        action: MAP
      }`
      }
    })
    .join(',')
  mappings = '[' + mappings + ']'

  return mappings
}
