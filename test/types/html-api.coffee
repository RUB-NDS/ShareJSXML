# Tests for the XML type API
assert = require 'assert'
html = require '../../src/types/html'
require '../../src/types/html-api'
MicroEvent = require '../../src/client/microevent'

Doc = (data) ->
  @snapshot = data ? html.create()
  @type = html
  @submitOp = (op) ->
    @snapshot = html.apply @snapshot, op
    @emit 'change', op
  @_register()
Doc.prototype = html.api
MicroEvent.mixin Doc

module.exports =  
  'getText() gives sane results': (test) ->
    doc = new Doc
    test.strictEqual null, doc.getText()
    test.strictEqual true, doc.provides.html
    
    test.done()
  
  'get() gives sane results': (test) ->
    doc = new Doc '<html xmlns="http://www.w3.org/1999/xhtml">abc<p id="bar">123</p>def<p>456</p></html>'
    test.deepEqual '<p xmlns="http://www.w3.org/1999/xhtml">456</p>', doc.get('/x:html/x:p[2]')
    
    doc = new Doc '<html xmlns="http://www.w3.org/1999/xhtml"><head>\n<title></title>\n</head>\n<body>&nbsp;</body>\n</html>'
    test.deepEqual '<body xmlns="http://www.w3.org/1999/xhtml"> </body>', doc.get('/x:html/x:body')
    
    test.done()
    
  'setElement() gives sane results': (test) ->
    doc = new Doc "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>\n	<title></title>\n</head>\n<body>&nbsp;</body>\n</html>"
    test.deepEqual "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>\n	<title></title>\n</head>\n<body></body>\n</html>", doc.type.apply(doc.getText(), [{p:[2], ed:'body', ei:'<body></body>'}])
    test.deepEqual "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>\n	<title></title>\n</head>\n<body>\n<p>h</p>\n</body>\n</html>", doc.type.apply(doc.getText(), [{p:[2], ed:'body', ei:"<body>\n<p>h</p>\n</body>"}])
    
    doc = new Doc "<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>\n	<title></title>\n</head>\n<body>&nbsp;</body>\n</html>"
    doc.setElement('/x:html', 3, "<body>\n<p>h</p>\n</body>")
    test.deepEqual '<html xmlns=\"http://www.w3.org/1999/xhtml\"><head>\n	<title></title>\n</head>\n<body>\n<p>h</p>\n</body>\n</html>', doc.getText()
    
    test.done()