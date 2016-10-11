# Tests for the XML type API
assert = require 'assert'
xml = require '../../src/types/xml'
require '../../src/types/xml-api'
MicroEvent = require '../../src/client/microevent'

Doc = (data) ->
  @snapshot = data ? xml.create()
  @type = xml
  @submitOp = (op, callback) ->
    @snapshot = xml.apply @snapshot, op
    @emit 'change', op
    callback() if callback?
  @_register()
Doc.prototype = xml.api
MicroEvent.mixin Doc

module.exports =  
  'getText() gives sane results': (test) ->
    doc = new Doc
    test.strictEqual null, doc.getText()
    
    xmltext = '<foo>abc<p>123</p>def<p>456</p></foo>'
    doc = new Doc xmltext
    test.strictEqual xmltext, doc.getText()
    
    test.done()
    
  'traverseXMLTree() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p><bar>xyz</bar></p>def<p>456</p></foo>'
    dom = doc.getReadonlyDOM()
    
    test.deepEqual [], doc.xpath.traverseXMLTree(dom, '/foo')[0]
    test.deepEqual 'foo', doc.xpath.traverseXMLTree(dom, '/foo')[1].nodeName
    test.deepEqual [], doc.xpath.traverseXMLTree(dom, '/foo[1]')[0]
    test.deepEqual 'foo', doc.xpath.traverseXMLTree(dom, '/foo[1]')[1].nodeName
    test.deepEqual [0], doc.xpath.traverseXMLTree(dom, '/foo/text()')[0]
    test.deepEqual [2], doc.xpath.traverseXMLTree(dom, '/foo/text()[2]')[0]
    test.deepEqual [1], doc.xpath.traverseXMLTree(dom, '/foo/p[1]')[0]
    test.deepEqual 'p', doc.xpath.traverseXMLTree(dom, '/foo/p[1]')[1].nodeName
    test.deepEqual [3], doc.xpath.traverseXMLTree(dom, '/foo/p[2]')[0]
    test.deepEqual [1,0], doc.xpath.traverseXMLTree(dom, '/foo/p[1]/bar')[0]
    test.deepEqual [1], doc.xpath.traverseXMLTree(dom, '/foo/p')[0]
    test.deepEqual 'p', doc.xpath.traverseXMLTree(dom, '/foo/p')[1].nodeName
    
    try
      doc.xpath.traverseXMLTree(dom, 'bar')
      test.fail()
    catch error
      test.strictEqual(error.message, 'TinyXPath expression does not start with slash')
    
    try
      doc.xpath.traverseXMLTree(dom, '/bar')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Root in TinyXPath expression invalid')
      
    try
      doc.xpath.traverseXMLTree(dom, '/foo[2]')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Root in TinyXPath expression invalid')
    
    try
      doc.xpath.traverseXMLTree(dom, '/foo/p[-1]')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Position -1 invalid')
    
    try
      doc.xpath.traverseXMLTree(dom, '/foo/p[7]')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Child "p" (position 7) not found')
      
    test.done()
    
  'addListener() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p>456</p></foo>'
    test.deepEqual [3], doc.addListener('/foo/p[2]', 'insert', null).path
    test.done()
    
  'get() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p id="bar">123</p>def<p>456</p><abc:p>789</abc:p></foo>'
    test.deepEqual '<p>456</p>', doc.get('/foo/p[2]')
    test.deepEqual 'abc', doc.get('/foo/text()')
    test.deepEqual 'bar', doc.get('/foo/p[1]/@id')
    test.deepEqual '789', doc.get('/foo/abc:p/text()')
    
    try
      doc.get('/foo/p[1]/@id/@id')
      test.fail()
    catch error
      test.strictEqual(error.message, 'TinyXPath expression has more than one attribute accessor')
      
    try
      doc.get('/foo/p[1]/@123')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Attribute accessor in TinyXPath expression is invalid')
  
    test.done()

  'get() with attribute filter gives sane results': (test) ->
    doc = new Doc '<foo id="barfoo">abc<p id="bar"><a foo="bar">123</a></p>def<p id="xyz" class="x">456</p></foo>'
    test.deepEqual '<p id="bar"><a foo="bar">123</a></p>', doc.get('/foo/p[@id=bar]')
    test.deepEqual '<p id="xyz" class="x">456</p>', doc.get('/foo/p[@id=xyz]')
    test.deepEqual '<p id="xyz" class="x">456</p>', doc.get('/foo/p[@class=x]')
    test.deepEqual '456', doc.get('/foo/p[@class=x]/text()')
    test.deepEqual '123', doc.get('/foo/p[@id=bar]/a[@foo=bar]/text()')
    
    try
      doc.get('/foo/p[@class=y]')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Child "p" (Attribute class=y) not found')
      
    try
      doc.get('/foo/p[@class=y=abc]')
      test.fail()
    catch error
      test.strictEqual(error.message, 'TinyXPath expression invalid')
      
    try
      doc.get('/foo/p[@class@y=abc]')
      test.fail()
    catch error
      test.strictEqual(error.message, 'TinyXPath expression invalid')
    
    test.done()

  'createRoot() gives sane results': (test) ->  
    doc = new Doc
    doc.createRoot('<foo/>')
    test.deepEqual '<foo/>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    try
      doc.createRoot('<foo/>')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Replacing root element is unsupported. Create a new document instead.')
        
    #console.log('If the tests above give messages like "invalid document source @#[line:0,col:...]", ignore those. I don\'t know the cause but everything works as intended ;)')
    
    doc = new Doc
    doc.createRoot '<foo>abc<p id="bar">123</p>def<p>456</p></foo>', ->
      test.deepEqual '<foo>abc<p id="bar">123</p>def<p>456</p></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()

  'setElement() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p id="bar">123</p>def<p>456</p></foo>'
    
    # replace text node
    doc.setElement('/foo', 3, '<a></a>')
    test.deepEqual '<foo>abc<p id="bar">123</p><a/><p>456</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    # replace element
    doc.setElement('/foo', 4, '<a></a>')
    test.deepEqual '<foo>abc<p id="bar">123</p><a/><a/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc = new Doc '<foo>abc<p id="bar">123</p>def<p>456</p></foo>'
    
    try
      doc.setElement('/foo/@bar', 1, '')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Using setElement() to set attributes is unsupported. Use setAttribute() instead.')
      
    try
      doc.setElement('/foo/text()', 1, '')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Using setElement() to set text is unsupported. Use insertTextAt() instead.')
      
    try
      doc.setElement('/foo', 0, '')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Position 0 invalid')
    
    try
      doc.setElement('/foo', -1, '')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Position -1 invalid')
      
    try
      doc.setElement('/foo', 17, '')
      test.fail()
    catch error
      test.strictEqual(error.message, 'Cannot set element with index 16, parent has only 4 children')
    
    # check callback
    doc.setElement '/foo', 3, '<a></a>', ->
      test.deepEqual '<foo>abc<p id="bar">123</p><a/><p>456</p></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()
  
  'insertElementAt() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def</foo>'
    
    doc.insertElementAt('/foo', 4, '<p>456</p>')
    test.deepEqual '<foo>abc<p>123</p>def<p>456</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertElementAt '/foo/p', 2, '<a></a>', ->
      test.deepEqual '<foo>abc<p>123<a/></p>def<p>456</p></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()
    
  'moveElement() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p>456</p></foo>'
    
    doc.moveElement('/foo/p[2]', 1)
    test.deepEqual '<foo><p>456</p>abc<p>123</p>def</foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.moveElement('/foo/p[2]', 4)
    test.deepEqual '<foo><p>456</p>abcdef<p>123</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.moveElement('/foo/p[1]', 2)
    test.deepEqual '<foo>abcdef<p>456</p><p>123</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.moveElement '/foo/text()', 2, ->
      test.deepEqual '<foo><p>456</p>abcdef<p>123</p></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()

  'setAttribute() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p id="bar">123</p>def<p>456</p></foo>'
    
    doc.setAttribute('/foo/p[2]/@foobar', 'xyz')
    test.deepEqual '<foo>abc<p id="bar">123</p>def<p foobar="xyz">456</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.setAttribute '/foo/p/@id', 'zzz', ->
      test.deepEqual '<foo>abc<p id="zzz">123</p>def<p foobar="xyz">456</p></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()
    
  'removeElement() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p id="bar">123</p>def<p>456</p></foo>'
    
    doc.removeElement('/foo/p')
    test.deepEqual '<foo>abcdef<p>456</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    # This test is particularly interesting because it checks if "abc" and "def"
    # correctly merge to "abcdef" and not into two adjacent text nodes.
    doc.removeElement '/foo/p', ->
      test.deepEqual '<foo>abcdef</foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()
    
  'removeAttribute() gives sane results': (test) ->
    doc = new Doc '<foo name="foo">abc<p id="bar">123</p>def<p>456</p></foo>'

    doc.removeAttribute('/foo/p/@id')
    test.deepEqual '<foo name="foo">abc<p>123</p>def<p>456</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)

    doc.removeAttribute '/foo/@name', ->
      test.deepEqual '<foo>abc<p>123</p>def<p>456</p></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)

      test.done()
    
  'insertTextAt() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p/></foo>'
  
    doc.insertTextAt('/foo/text()', 3, 'def')
    test.deepEqual '<foo>abcdef<p>123</p>def<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt('/foo/p/text()', 0, 'zzz')
    test.deepEqual '<foo>abcdef<p>zzz123</p>def<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt('/foo/p[2]/text()', 0, 'zzz')
    test.deepEqual '<foo>abcdef<p>zzz123</p>def<p>zzz</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt('/foo/text()[2]', 3, 'ghi')
    test.deepEqual '<foo>abcdef<p>zzz123</p>defghi<p>zzz</p></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    # Einfügen von Text an beliebigen Orten
    doc = new Doc '<foo><p/></foo>'
    
    doc.insertTextAt('/foo/text()', 0, 'abc') # creates text node
    test.deepEqual '<foo>abc<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt('/foo/text()[2]', 0, 'def') # creates text node
    test.deepEqual '<foo>abc<p/>def</foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt('/foo/text()[2]', 0, 'ghi') # inserts text in existing node
    test.deepEqual '<foo>abc<p/>ghidef</foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt('/foo/text()[3]', 0, 'zzz') # creates text node that is merged with the existing one
    test.deepEqual '<foo>abc<p/>ghidefzzz</foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.insertTextAt '/foo/text()[2]', 8, 'xxx', -> # inserts text in merged node
      test.deepEqual '<foo>abc<p/>ghidefzzxxxz</foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()
    
  'removeTextAt() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p/></foo>'
  
    doc.removeTextAt('/foo/text()', 1, 1)
    test.deepEqual '<foo>ac<p>123</p>def<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.removeTextAt('/foo/p/text()', 0, 2)
    test.deepEqual '<foo>ac<p>3</p>def<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.removeTextAt('/foo/text()[2]', 1, -1)
    test.deepEqual '<foo>ac<p>3</p>d<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.removeTextAt '/foo/p/text()', 0, 1, ->
      test.deepEqual '<foo>ac<p/>d<p/></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
      test.done()
    
  'replaceTextAt() gives sane results': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p/></foo>'
    
    doc.replaceTextAt('/foo/text()', 1, 'de')
    test.deepEqual '<foo>ade<p>123</p>def<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.replaceTextAt('/foo/text()', 1, 'de123')
    test.deepEqual '<foo>ade123<p>123</p>def<p/></foo>', doc.getText()
    test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
    
    doc.replaceTextAt '/foo/p/text()', 0, 'def', ->
      test.deepEqual '<foo>ade123<p>def</p>def<p/></foo>', doc.getText()
      test.deepEqual doc.getText(), xml.serializer.serializeToString(doc.dom)
      test.done()
    
  'element insert listener': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p/></foo>'
    doc.addListener '/foo', 'insert', (pos, element) ->
      test.deepEqual element, '<a/>'
      test.deepEqual pos, 4
      test.done()
    doc.emit 'remoteop', [{p:[4],ei:'<a/>'}]
  
  'attribute insert listener': (test) ->
    doc = new Doc '<foo id="bar">abc<p>123</p>def<p/></foo>'
    doc.addListener '/foo', 'insert', (name, value) ->
      test.deepEqual value, 'zzz'
      test.deepEqual name, 'id'
      test.done()
    doc.emit 'remoteop', [{p:['id'],as:'zzz'}]

  'element delete listener': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p/></foo>'
    doc.addListener '/foo', 'delete', (pos, element) ->
      test.deepEqual element, 'p'
      test.deepEqual pos, 1
      test.done()
    doc.emit 'remoteop', [{p:[1],ed:'p'}]
  
  'attribute delete listener': (test) ->
    doc = new Doc '<foo id="bar">abc<p>123</p>def<p/></foo>'
    doc.addListener '/foo', 'delete', (name, value) ->
      test.deepEqual value, 'bar'
      test.deepEqual name, 'id'
      test.done()
    doc.emit 'remoteop', [{p:['id'],ad:'bar'}]

  'element replace listener': (test) ->
    doc = new Doc '<foo>abc<p>123</p>def<p/></foo>'
    doc.addListener '/foo', 'replace', (pos, before, after) ->
      test.deepEqual before, 'p'
      test.deepEqual after, '<a/>'
      test.deepEqual pos, 3
      test.done()
    doc.emit 'remoteop', [{p:[3],ed:'p',ei:'<a/>'}]
    
  'listener moves on ei': (test) ->
    doc = new Doc '<foo><p/></foo>'
    doc.addListener '/foo/p', 'insert', (pos, element) ->
      test.deepEqual element, '>foo'
      test.deepEqual pos, 0
      test.done()
    doc.insertElementAt('/foo', 1, '<a/>')
    test.deepEqual '<foo><a/><p/></foo>', doc.getText()
    doc.emit 'remoteop', [{p:[1,0], ei:'>foo'}]

  'listener moves on ed': (test) ->
    doc = new Doc '<foo><a/><b/><c/></foo>'
    doc.addListener '/foo/b', 'insert', (pos, element) ->
      test.deepEqual element, '>foo'
      test.deepEqual pos, 0
      test.done()
    doc.removeElement('/foo/a')
    test.deepEqual '<foo><b/><c/></foo>', doc.getText()
    doc.emit 'remoteop', [{p:[0,0], ei:'>foo'}]
  
  'listener moves on em': (test) ->
    doc = new Doc '<foo><a/><b/><c/></foo>'
    doc.addListener '/foo/b', 'insert', (pos, element) ->
      test.deepEqual element, '>foo'
      test.deepEqual pos, 0
      test.done()
    doc.moveElement('/foo/a', 3)
    test.deepEqual '<foo><b/><c/><a/></foo>', doc.getText()
    doc.emit 'remoteop', [{p:[0,0], ei:'>foo'}]
  
  'listener drops on ed': (test) ->
    doc = new Doc '<foo><a/><b/><c/></foo>'
    doc.addListener '/foo/b', 'insert', (pos, element) ->
      test.fail()
    doc.removeElement('/foo/b')
    test.deepEqual '<foo><a/><c/></foo>', doc.getText()
    doc.emit 'remoteop', [{p:[0,0], ei:'>foo'}]
    test.done()
    
  'listening on child ops works': (test) ->
    doc = new Doc '<foo><a/><b/><c/></foo>'
    doc.addListener '/foo', 'desc-or-self op', (pos, element) ->
      test.deepEqual element, {p:[3],ei:'<d/>'}
      test.deepEqual pos, [3]
      test.done()
    doc.emit 'remoteop', [{p:[3],ei:'<d/>'}]
    