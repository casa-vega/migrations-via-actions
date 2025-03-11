const checkStatus = require('../queries/check-status')
const sleep = require('./sleep')
const Logger = require('../utils/logger')

module.exports = async (migration, status, exceptionCountMax = 0) => {
  const waitTimes = [10, 5, 20, 30, 45, 60, 120, 150]
  const logger = new Logger(migration)

  let state
  let checks = 0
  let exceptionCount = 0

  do {
    if (checks > 0) {
      // The first time is smaller intentionally. Hence counter starts at 1.
      const sleepTime = waitTimes[checks % waitTimes.length]

      logger.sleep(sleepTime)
      await sleep(sleepTime)
    }

    try {
      // We are seeing a case where the status API gave us a 500 but the migration finished successfully
      // Ignoring exceptions to the api and retrying as usual
      state = await checkStatus(migration)
    } catch (e) {
      logger.log(JSON.stringify(e))
      state = 'EXCEPTION'
      exceptionCount++
    }

    logger.state(state)

    checks++
  } while (!status.includes(state) && exceptionCount <= exceptionCountMax) // make sure we don't infinite loop

  return state
}
