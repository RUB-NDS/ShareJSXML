# This script watches for changes in a document and constantly resaves a file
# with the document's contents.

client = require('../src').client
fs = require('fs')

argv = require('minimist')(process.argv.slice(2), {
  string: [ 'd', 'url' , 'f'],
  default: { d: 'hello', url: 'http://localhost:8000/channel' },
})

filename = argv.f || argv.d

console.log "Opening '#{argv.d}' at #{argv.url}. Saving to '#{filename}'"

timeout = null
doc = null

# Writes the snapshot data to the file not more than once per second.
write = ->
	if (timeout == null)
		timeout = setTimeout ->
        console.log "Saved version " + doc.version
        fs.writeFile filename, doc.snapshot
        timeout = null
      , 1000

client.open argv.d, 'text', argv.url, (d, error) ->
	doc = d
	console.log('Document ' + argv.d + ' open at version ' + doc.version)

	write()
	doc.on 'change', (op) ->
		write()
