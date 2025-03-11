module.exports = class Formatter {
  constructor(migration) {
    this.migration = migration
  }

  bulletList(items) {
    return items
      .map(item => {
        return `- ${item}\n`
      })
      .join('')
  }

  recordsList(records) {
    return records
      .map(({ sourceUrl, targetUrl, state }) => {
        if (!targetUrl && state === 'IMPORT') {
          return `- ${state}: ${sourceUrl} was not imported\n`
        }
        return `- ${state}: ${targetUrl}\n`
      })
      .join('')
  }

  // Remove leading whitespace per line
  body(body) {
    return body.replace(/  +/g, '')
  }

  table(data, columns, titles) {
    let table = ''
    table += titles.join('|') + '\n'
    table +=
      Array.apply(null, Array(titles.length))
        .map(() => ':---')
        .join('|') + '\n'
    table += this.tableRows(data, columns)
    return table
  }

  tableRows(data, columns) {
    return data
      .map(record => {
        let values = []

        columns.forEach(column => {
          values.push(record[column])
        })

        return values.join('|')
      })
      .join('\n')
  }

  details(summary, code) {
    let details = this.body(`
      <details>
        <summary>${summary}</summary>
        <p>
        
        \`\`\`
        `)

    details += JSON.stringify(code, null, 2)

    details += this.body(`
        \`\`\`
      
        </p>
      </details>
    `)

    return details
  }
}
