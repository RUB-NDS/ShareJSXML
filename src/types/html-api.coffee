# HTML document API

if WEB?
  html = exports.types.html
  XMLAPIClass = exports.types.xmlapiclass
else
  html = require './html'
  XMLAPIClass = require './xmlapiclass'

class HTMLAPIClass extends XMLAPIClass
  
  provides: {html:true}
  
  constructor: (@type) ->
    super(@type)
    @xpath = @xpathlib.useNamespaces({"x": "http://www.w3.org/1999/xhtml"});
  
  _extractPayload: (documentElement) ->
    return documentElement if require?
    return documentElement.lastElementChild.firstElementChild # gets first child in body      
  
html.api = new HTMLAPIClass(html)
