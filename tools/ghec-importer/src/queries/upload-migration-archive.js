// The startImport mutation will create a migration object on GitHub to keep track of the import status.
//
// The migration status should return as WAITING after starting an import and
// will wait for an archive to be uploaded in the Upload Migration Archive step.
//
// https://github.github.com/enterprise-migrations/#/3.1.2-import-using-graphql-api?id=upload-migration-archive

const Logger = require('../utils/logger')
const proxyAgent = require('../utils/proxy-agent')
const fetch = require('node-fetch')
const fs = require('fs')
const filesize = require('file-size')

const maxSize = 4000000000 // 4 GB
const partsSize = 100000000 // 100 MB

const getPartsFromData = function* (migration, fd, fileSizeInBytes, partSize) {
  const logger = new Logger(migration)

  let partCount = 0
  logger.info('Splitting data of size ' + fileSizeInBytes + ' into parts of size ' + partSize + ' B')

  let offset = 0
  let chunkBuffer = new Buffer.alloc(partsSize)
  let bytesRead = 0
  let bytesToRead = partsSize
  while ((bytesRead = fs.readSync(fd, chunkBuffer, 0, bytesToRead, offset))) {
    offset += bytesRead
    partCount += 1

    logger.debug('Part ' + partCount + ': ' + bytesRead + ' bytes read')
    yield chunkBuffer

    if (fileSizeInBytes - offset < partsSize) {
      chunkBuffer = new Buffer.alloc(fileSizeInBytes - offset)
      bytesToRead = fileSizeInBytes - offset
    } else {
      chunkBuffer = new Buffer.alloc(partsSize)
      bytesToRead = partSize
    }
  }
}

const uploadParts = async (migration, parts, size) => {
  const { adminToken, uploadUrl } = migration
  const logger = new Logger(migration)

  const baseHeaders = {
    Authorization: `Bearer ${adminToken}`,
    'Content-Type': 'application/octet-stream',
    Accept: 'application/vnd.github.wyandotte-preview+json'
  }
  // Start Upload and get GUID and ID
  let finalUrl = `${uploadUrl.split('?')[0]}/blobs/uploads`
  const response = await fetch(finalUrl, {
    method: 'POST',
    body: JSON.stringify({
      content_type: 'application/octet-stream',
      name: 'migration_upload.tar.gz.zip',
      size: size
    }),
    headers: baseHeaders
  })

  const responseLocation = response.headers.raw().location[0]
  const uploadId = response.headers.raw()['multipart-upload-id'][0]
  const uploadGuid = responseLocation
    .split('?')[1]
    .split('&')
    .filter(param => param.indexOf('guid') > -1)[0]
    .split('=')[1] // yuck

  let index = 0

  for await (const part of parts) {
    const headers = {
      ...baseHeaders
    }
    index++

    const finalUrl = `${uploadUrl.split('?')[0]}/blobs/uploads?upload_id=${uploadId}&guid=${uploadGuid}&part_number=${index}`

    logger.step(`Uploading part ${index}`)
    logger.debug(`Upload URL for part ${index}`, finalUrl)

    const uploadResult = await fetch(finalUrl, {
      method: 'PATCH',
      body: part,
      headers: headers
    })

    logger.debug('Upload result', uploadResult)
  }
  finalUrl = `${uploadUrl.split('?')[0]}/blobs/uploads?upload_id=${uploadId}&guid=${uploadGuid}&part_number=${index}`

  logger.debug('Final put upload url', finalUrl)

  const putUploadResult = await fetch(finalUrl, {
    method: 'PUT',
    body: JSON.stringify({}),
    headers: baseHeaders
  })

  logger.debug('Upload confirmation result', putUploadResult)
}

module.exports = async (migration, archivePath) => {
  const logger = new Logger(migration)

  logger.title('Uploading migration archive')

  const stats = fs.statSync(archivePath)
  const fileSizeInBytes = stats.size
  const bufferContent = fs.createReadStream(archivePath)

  logger.info('Archive size: ' + filesize(fileSizeInBytes).human('si'))
  logger.debug('Maximum single upload limit: ' + filesize(maxSize).human('si'))

  if (fileSizeInBytes < maxSize) {
    const proxy = proxyAgent()

    logger.debug('Uploading archive to', migration.uploadUrl)

    const response = await fetch(migration.uploadUrl, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${migration.adminToken}`,
        Accept: 'application/vnd.github.wyandotte-preview+json',
        'Content-Type': 'application/gzip',
        'Content-length': fileSizeInBytes
      },
      body: bufferContent,
      // Embed the proxy agent only if a proxy is used
      ...(proxy.enabled ? { agent: proxy.proxyAgent } : {})
    })

    if (logger.isDebugMode) {
      console.log(response)
      // Log the X-Github-Request-Id header
      console.log('X-Github-Request-Id:' + response.headers.raw()['x-github-request-id'])
    }
  } else {
    logger.info('Archive exceeds maximum single upload limit. Uploading in parts.')
    const fileDescriptor = fs.openSync(archivePath, 'r')
    const parts = getPartsFromData(migration, fileDescriptor, fileSizeInBytes, partsSize)

    try {
      await uploadParts(migration, parts, fileSizeInBytes)
    } finally {
      fs.closeSync(fileDescriptor)
    }
  }
}
