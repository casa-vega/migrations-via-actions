const { validate, VALID_FEATURES_LIST } = require('../src/commands/enable-features')
const { SourceMapConsumer } = require('source-map')
const path = require('path')

SourceMapConsumer.initialize({
  'lib/mappings.wasm': path.resolve(__dirname, 'node_modules/source-map/lib/mappings.wasm')
})

beforeEach(() => {
  jest.spyOn(process, 'exit').mockImplementation(() => {})
  jest.spyOn(console, 'error').mockImplementation(() => {})
})

afterEach(() => {
  console.error.mockRestore()
  process.exit.mockRestore()
})

describe('validation succeeds when either `migration.features` or `migration.enableFeatures` is an array', () => {
  test('when `migration.features` is an array but `migration.enableFeatures` is not an array', () => {
    validate({ features: [], enableFeatures: undefined })

    expect(console.error).not.toHaveBeenCalled()
    expect(process.exit).not.toHaveBeenCalled()
  })

  test('when `migration.features` is not an array but `migration.enableFeatures` is an array', () => {
    validate({ features: undefined, enableFeatures: [] })

    expect(console.error).not.toHaveBeenCalled()
    expect(process.exit).not.toHaveBeenCalled()
  })

  test('when `migration.features` an array containing only supported features', () => {
    validate({ features: VALID_FEATURES_LIST, enableFeatures: undefined })

    expect(console.error).not.toHaveBeenCalled()
    expect(process.exit).not.toHaveBeenCalled()
  })
})

describe('validation fails when either `migration.features` or `migration.enableFeatures` is an array containing at least one unsupported feature', () => {
  test('when `migration.features` has one invalid feature', () => {
    validate({ features: ['unsupported-feature'] })

    expect(console.error).toHaveBeenCalled()
    expect(process.exit).toHaveBeenCalledWith(7)
  })

  test('when `migration.enableFeatures` has one invalid feature', () => {
    validate({ enableFeatures: ['unsupported-feature'] })

    expect(console.error).toHaveBeenCalled()
    expect(process.exit).toHaveBeenCalledWith(7)
  })
})
