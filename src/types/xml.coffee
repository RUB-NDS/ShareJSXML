# This is the implementation of the XML OT type.

if WEB?
  XMLClass = exports.types.xmlclass
else
  XMLClass = require './xmlclass'

xml = new XMLClass('xml', 'text/xml')

if WEB?
  exports.types ||= {}
  exports.types.xml = xml
else
  module.exports = xml

