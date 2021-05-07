# Package.json file in CoffeeScript
# Nicer to write and you can have comments
# Compile with "cake package"

module.exports =
  name: "sharejsxml"

  # Change version with "cake [-V newversion] bump"
  version: "0.10.1"
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
    sockjs: "^0.3.21"
    "socket.io": "^2.4.1"
    "socket.io-client": "^2.3.1"
    browserchannel: "^2.1.0"
    ws: "~3.3.1"

    connect: "~3"
    "serve-static": "^1.14.1"
    "connect-route": "^0.1.5"

    # CouchDB Backend
    request: "^2.88.2"

    # Prevent upgrade failures like v1.3. Bump this when tested.
    "coffee-script": "~1"

    # Useragent hashing
    hat: "*"
    
    #XML parsing and serializing
    xmldom: "0.5.0"
    
    #XPath processing
    xpath: "0.0.27"

  # Developer dependencies
  devDependencies:
    # Example server
    express: "~4"
    minimist: "^1.2.5"

    # Tests
    nodeunit: "^0.11.3"

    # Javascript compression
    "uglify-js": "~2.7"

    # SockJS
    "websocket": "^1.0.31"

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
    prepare: "cake webclient"

  license: "MIT"
  
  repository:
    type: "git"
    url: "https://github.com/RUB-NDS/ShareJSXML"
