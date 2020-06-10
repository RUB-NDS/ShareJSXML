fs     = require 'fs'
path   = require 'path'
os     = require 'os'
{exec, execSync, spawn} = require 'child_process'

# Gain access through PATH to all binaries added by `npm install`
# Without this, 'cake test' does not work
npm_bin  = path.resolve(path.join('node_modules', '.bin'))
path_sep = if os.platform() == 'win32' then ";" else ":"
process.env.PATH = "#{npm_bin}#{path_sep}#{process.env.PATH}"

task 'package', 'Convert package.coffee to package.json', ->
  execSync "coffee --compile --bare package.coffee"
  pkgInfo = require './package.js'
  fs.writeFileSync('package.json', JSON.stringify(pkgInfo, null, 2))
  execSync "rm package.js"

task 'test', 'Run all tests', (options) ->
  console.log 'Running tests... (is your webclient up-to-date and nodeunit installed?)'
  spawn 'nodeunit', ['tests.coffee'], stdio: 'inherit'

# This is only needed to be able to refer to the line numbers of crashes
task 'build', 'Build the .js files', ->
  invoke 'package'
  console.log 'Compiling Coffee from src to lib'
  execSync "coffee --compile --output lib/ src/"

task 'webclient', 'Build the web client into one file', ->
  execSync "mkdir -p webclient" 
  compile client, 'webclient/share'
  buildtype 'json'
  buildtype 'text-tp2'
  buildtype 'text2'
  buildtype 'xml'
  buildtype 'html'

  extrafiles = expandNames extras
  exec "coffee --compile --output webclient/ #{extrafiles}", (err, stdout, stderr) ->
    if err
      console.log stdout + stderr
      throw err 
    # For backwards compatibility. (The ace.js file used to be called share-ace.js)
    execSync "cp -f webclient/ace.js webclient/share-ace.js"
    execSync "cp -f src/lib-etherpad/* webclient/"

makeUgly = (infile, outfile) ->
  uglify = require('uglify-js')
  code = uglify.minify(infile).code
  fs.writeFileSync(outfile, code)
  console.log("Uglified " + outfile)

expandNames = (names) -> ("src/#{c}.coffee" for c in names).join ' '

compile = (filenames, dest) ->
  filenames = expandNames filenames
  execSync "cat #{filenames} | coffee --compile --stdio > #{dest}.uncompressed.js"
  makeUgly "#{dest}.uncompressed.js", "#{dest}.js"
  #execSync "rm #{dest}.uncompressed.js"

buildtype = (name) ->
  filenames = ['types/web-prelude']
  
  if name is 'xml' or name is 'html'
    filenames.push "types/xmlclass"
    filenames.push "types/xmlapiclass"
  
  filenames.push "types/#{name}"
  
  if name is 'html'
    filenames.push "types/xml"
    filenames.push "types/xml-api"
  
  try
    fs.accessSync "src/types/#{name}-api.coffee"
    filenames.push "types/#{name}-api"
  catch error
    # do nothing

  compile filenames, "webclient/#{name}"

client = [
  'client/web-prelude'
  'client/microevent'
  'types/helpers'
  'types/text'
  'types/text-api'
  'client/doc'
  'client/reconnecting_websocket'
  'client/connection'
  'client/index'
]

extras = [
  'client/ace'
  'client/cm'
  'client/textarea'
]

option '-V', '--version [version]', 'The new patch version'
task 'bump', 'Increase the patch level of the version, -V is optional', (options) ->
  oldVersion = require("./package.coffee").version

  console.log "Current version is #{oldVersion}"

  if options.version
    version = options.version
  else
    versions = oldVersion.match(/(\d+)\.(\d+)\.(\d+)/)
    versions.shift()
    versions[2]++
    version = versions.join '.'
  console.log "New version is #{version}"

  execSync "sed -i -e 's/version: \"#{oldVersion}\"/version: \"#{version}\"/' package.coffee"
  execSync "sed -i -e \"s/exports.version = '#{oldVersion}'/exports.version = '#{version}'/\" src/index.coffee"
  execSync "sed -i -e \"s/'version': '#{oldVersion}'/'version': '#{version}'/\" src/client/web-prelude.coffee"
  
  invoke "package"
  invoke "build"
  invoke "webclient"
