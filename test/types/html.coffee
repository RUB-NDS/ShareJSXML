# Tests for HTML OT type. (src/types/html.coffee)

nativetype = require '../../src/types/html'

util = require 'util'
p = util.debug
i = util.inspect

genTests = (type) ->
  sanity:
    'name is html': (test) ->
      test.strictEqual type.name, 'html'
      test.done()

    'create() returns null': (test) ->
      test.deepEqual type.create(), null
      test.done()

exports.node = genTests nativetype
exports.webclient = genTests require('../helpers/webclient').types.html
