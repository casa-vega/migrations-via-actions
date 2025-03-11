module.exports = (migration, mappings) => {
  let customMappings = mappings
    .map(mapping => {
      if (mapping) {
        mapping = mapping.split(',')

        return `{
        modelName: "${mapping[0]}",
        sourceUrl: "${mapping[1]}",
        targetUrl: "${mapping[2]}",
        action: ${mapping[3]}
      }`
      }
    })
    .join(',')
  customMappings = '[' + customMappings + ']'

  return customMappings
}
