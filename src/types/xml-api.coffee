# XML document API

if WEB?
  xml = exports.types.xml
  XMLAPIClass = exports.types.xmlapiclass
else
  xml = require './xml'
  XMLAPIClass = require './xmlapiclass'

xml.api = new XMLAPIClass(xml)
