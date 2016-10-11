# Package.json file in CoffeeScript
# Nicer to write and you can have comments
# Compile with "cake package"

module.exports =
  name: "ShareJSXML"

  # Change version with "cake [-V newversion] bump"
  version: "0.9.23"
  description: "A database for concurrent XML document editing"
  keywords: [
  	"operational transformation"
  	"ot"
  	"concurrent"
  	"collaborative"
  	"database"
  	"server"
    "XML"
  ]

  homepage: ""

  author: "Joseph Gentle <josephg@gmail.com> and Dennis Felsch <dennis.felsch@ruhr-uni-bochum.de>"

  dependencies:
    # Transports
    sockjs: ">= 0.3.1"
    "socket.io": "~0.8"
    "socket.io-client": "~0.8"
    browserchannel: "~1"
    ws: "*"

    # Server works with v1 or v2
    connect: "<3.x"

    # CouchDB Backend
    request: ">= 2.1.1"

    # Prevent upgrade failures like v1.3. Bump this when tested.
    "coffee-script": "~1.8.x"

    # Useragent hashing
    hat: "*"
    
    #XML parsing and serializing
    xmldom: "0.1.19"

  # Developer dependencies
  devDependencies:
    # Example server
    express: "~ 3.x"
    optimist: ">= 0.2.4"

    # Tests
    nodeunit: "*"

    # Unixy shell stuff for Cakefile
    shelljs: "*"

    # Javascript compression
    "uglify-js": "*"

    # SockJS
    "websocket": "*"

  engine: "node >= 0.6"

  # Main file to execute
  main: "index.js"

  # Binaries to install
  bin:
    sharejs: "bin/sharejs"
    "sharejs-exampleserver": "bin/exampleserver"

  scripts:
    build: "cake build"
    test: "cake test"
    prepublish: "cake webclient"

  licenses: [
    type: "MIT"
  ]
  
  repository:
    type: "git"
    url: "https://github.com/RUB-NDS/ShareJSXML"
