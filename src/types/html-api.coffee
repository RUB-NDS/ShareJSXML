# HTML document API

if WEB?
  html = exports.types.html
  XMLAPIClass = exports.types.xmlapiclass
else
  html = require './html'
  XMLAPIClass = require './xmlapiclass'

class HTMLAPIClass extends XMLAPIClass
  
  provides: {html:true}
  
  _extractPayload: (documentElement) ->
    return documentElement if require?
    return documentElement.lastElementChild.firstElementChild # gets first child in body      
  
html.api = new HTMLAPIClass(html)
