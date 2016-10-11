# This is the implementation of the HTML OT type.

if WEB?
  XMLClass = exports.types.xmlclass
else
  XMLClass = require './xmlclass'

html = new XMLClass('html', 'text/html')

if WEB?
  exports.types ||= {}
  exports.types.html = html
else
  module.exports = html

