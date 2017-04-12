# XML and HTML document API

if require?
  XPathLib = require 'xpath'
else
  XPathLib = window.xpath

class XMLAPIClass
  constructor: (@type) ->
    @xpathlib = XPathLib
    @xpath = @xpathlib.select

  provides: {xml:true}

  _ensureDOMexists: ->
    @dom ?= @_parseDOM()
    # Some combinations of operations can leave the DOM in a bad state where e.g. 
    # text nodes are adjacent. This could lead to inconsistencies with the server's
    # version of the DOM. The call to normalize() fixes this problem.
    @dom.documentElement.normalize()
  
  _parseDOM: ->
    if not @snapshot?
      throw new Error 'You have to create a root element using createRoot() first'
    @dom = @type.parser.parseFromString(@snapshot, @type.docType)
  
  # Some document types in the XML parser add "junk" around the payload
  # E.g. the doctype "text/html" wraps everything in an /html/body structure
  # For plain XML we can simply return the documentElement
  # A subclass of XMLClass may override this
  _extractPayload: (documentElement) ->
    return documentElement

  _transformElementPosition: (pos) ->
    pos = if pos isnt undefined then parseInt(pos) else 1
    if pos is undefined or pos < 1
      throw new Error "Position #{pos} invalid."
    return pos - 1
    
  _transformTextPosition: (pos) ->
    pos = if pos isnt undefined then parseInt(pos) else 0
    if pos is undefined or pos < 0
      throw new Error "Position #{pos} invalid."
    return pos
    
  _getChildrenByNodeName: (elem, nodeName) ->
      nodeName = '#text' if nodeName is 'text()'
      result = []
      for child in elem.childNodes
        if child.nodeName.toLowerCase() == nodeName.toLowerCase()
          result.push(child)
      return result

  _selectSingle: (XPath, dom) ->
    nodes = @xpath(XPath, dom)
    if not nodes? or nodes.length is 0 or not nodes[0]?
      throw new Error 'Nothing selected.'
    if nodes.length > 1
      throw new Error 'More than one node selected.'
    return nodes[0]
    
  __getPath: (node) ->
    path = []
    while node.parentNode?
      path.unshift(Array.prototype.indexOf.call(node.parentNode.childNodes, node))
      node = node.parentNode
    path.shift()
    return path
    
  # Prepares event handlers
  _register: ->
    @_listeners = []
    
    # removes listeners that listen on something that does not exist anymore
    @on 'change', (op) ->
      for c in op
        if c.ti != undefined or c.td != undefined
          # text change, no change to structure
          continue
        to_remove = []
        for l, i in @_listeners
          # Transform a dummy op by the incoming op to work out what
          # should happen to the listener.
          dummy = {p:l.path, em:l.path[l.path.length - 1]}
          xformed = @type.transformComponent [], dummy, c, 'left'
          if xformed.length == 0
            # The op was transformed to noop, so we should delete the listener.
            to_remove.push i
          else if xformed.length == 1
            # The op remained, so grab its new path into the listener.
            l.path = xformed[0].p
          else
            throw new Error "Bad assumption in xml-api: xforming an 'em' op will always result in 0 or 1 components."
        to_remove.sort (a, b) -> b - a
        for i in to_remove
          @_listeners.splice i, 1
          
    @on 'remoteop', (op) -> # op has already been applied
      @_ensureDOMexists()
      for c in op
        for {path, event, cb} in @_listeners
          if @type.pathMatches(path, c.p[...-1])
            switch event
              when 'insert'
                if c.ei != undefined and c.ed == undefined
                  cb(c.p[c.p.length-1], c.ei)
                else if c.as != undefined and c.ad == undefined
                  cb(c.p[c.p.length-1], c.as)
              when 'delete'
                if c.ei == undefined and c.ed != undefined
                  cb(c.p[c.p.length-1], c.ed)
                else if c.as == undefined and c.ad != undefined
                  cb(c.p[c.p.length-1], c.ad)
              when 'replace'
                if c.ei != undefined and c.ed != undefined
                  cb(c.p[c.p.length-1], c.ed, c.ei)
              when 'move'
                if c.em != undefined
                  cb(c.p[c.p.length-1], c.em)
              when 'textInsert'
                if c.ti != undefined
                  cb(c.p[c.p.length-1], c.ti)
              when 'textDelete'
                if c.td != undefined
                  cb(c.p[c.p.length-1], c.td)
          if event == 'desc-or-self op' and @type.canOpAffectOp(path, c.p)
            child_path = c.p[path.length..]
            cb(child_path, c)

  addListener: (XPath, event, cb) ->
    @_ensureDOMexists()
    node = @_selectSingle(XPath, @dom)
    if node.nodeType isnt 1
      throw new Error 'Adding a listener on a non-element node is unsupported.'
    path = @__getPath(node)
    listener = {path, event, cb}
    @_listeners.push listener
    return listener
  
  removeListener: (listener) ->
    i = @_listeners.indexOf listener
    return false if i < 0
    @_listeners.splice i, 1
    return true

  # Get the text content of a document
  getText: -> @snapshot
  
  getReadonlyDOM: -> 
    @_ensureDOMexists()
    return @dom
  
  # Gets elements, text and attribute values
  get: (XPath) ->
    @_ensureDOMexists()
    node = @_selectSingle(XPath, @dom)
    if node.nodeType is 1 and not node.parentNode.parentNode?
      throw new Error 'Using get() to retrieve the root is unsupported. Use getText() instead.'
    if node.nodeType isnt 2
      return @type.serializer.serializeToString(node)
    else
      return node.ownerElement.getAttribute(node.nodeName)
  
  createRoot: (value, callback) ->
    if @dom and @dom.documentElement isnt undefined
      throw new Error 'Replacing root element is unsupported. Create a new document instead.'
    @dom = @type.parser.parseFromString(value, @type.docType)
    @submitOp [{ei:value, p:[]}], callback
  
  # Replaces/sets elements
  setElement: (XPathToParent, pos, value, callback) ->
    @_ensureDOMexists()
    parent = @_selectSingle(XPathToParent, @dom)
    if parent.nodeType is 2
      throw new Error 'Using setElement() to set attributes is unsupported. Use setAttribute() instead.'
    if parent.nodeType is 3
      throw new Error 'Using setElement() to set text is unsupported. Use insertTextAt() instead.'
    if parent.nodeType isnt 1
      throw new Error 'XPath has to select an element'
    if not parent.parentNode?
      throw new Error 'Replacing root element is unsupported. Create a new document instead.'
    pos = @_transformElementPosition(pos)
    if parent.childNodes.length < pos
      throw new Error "Cannot set element with index #{pos}, parent has only #{parent.childNodes.length} children."
    if parent.childNodes[pos] is undefined
      throw new Error "Using setElement() to append an element is unsupported. Use insertElementAt() instead."
    path = @__getPath(parent)
    op = {p:path.concat(pos)}
    op.ei = value
    newDoc = @type.parser.parseFromString(value, @type.docType)
    newElem = @_extractPayload(newDoc.documentElement)
    op.ed = parent.childNodes[pos].nodeName.toLowerCase()
    parent.replaceChild(newElem, parent.childNodes[pos])    
    @submitOp [op], callback
    
  insertElementAt: (XPathToParent, pos, value, callback) ->
    @_ensureDOMexists() # also normalizes DOM
    parent = @_selectSingle(XPathToParent, @dom)
    if parent.nodeType is 2
      throw new Error 'Using insertElementAt() to set attributes is unsupported. Use setAttribute() instead.'
    if parent.nodeType is 3
      throw new Error 'Using insertElementAt() to set text is unsupported. Use insertTextAt() instead.'
    if parent.nodeType isnt 1
      throw new Error 'XPath has to select an element.'
    if not parent.parentNode?
      if not @dom or @dom.documentElement is undefined
        throw new Error 'Inserting root element is unsupported. Create a new document instead.'
      else
        throw new Error 'Having more than one root element is no valid XML.'
    pos = @_transformElementPosition(pos)
    if parent.childNodes.length < pos
      throw new Error "Cannot set element at position #{pos}, parent has only #{parent.childNodes.length} children."
    path = @__getPath(parent)
    op = {p:path.concat(pos)}
    op.ei = value
    newDoc = @type.parser.parseFromString(value, @type.docType)
    newElem = @_extractPayload(newDoc.documentElement)
    if parent.childNodes[pos] is undefined
      parent.appendChild(newElem)
    else
      parent.insertBefore(newElem, parent.childNodes[pos])
    @submitOp [op], callback
  
  moveElement: (XPath, moveToPos, callback) ->
    @_ensureDOMexists()
    node = @_selectSingle(XPath, @dom)
    if node.nodeType is 2
      throw new Error 'Attributes cannot be moved.'
    if node.nodeType is 1 and not node.parentNode.parentNode?
      throw new Error 'Root element cannot be moved.'
    moveToPos = @_transformElementPosition(moveToPos)
    if node.parentNode.childNodes.length <= moveToPos
      throw new Error "Cannot move element to position #{moveToPos}, parent has only #{elem.parentNode.childNodes.length} children."
    path = @__getPath(node)
    op = {p:path, em:moveToPos}
    if node.parentNode.childNodes.length - moveToPos == 1 # special case, moving to last child
      node.parentNode.appendChild(node)
    else
      if path[path.length - 1] < moveToPos
        node.parentNode.insertBefore(node, node.parentNode.childNodes[moveToPos + 1])
      else
        node.parentNode.insertBefore(node, node.parentNode.childNodes[moveToPos])
    @submitOp [op], callback

  # Replaces/sets attributes
  setAttribute: (XPath, value, callback) ->
    @_ensureDOMexists()
    try
      # Case 1: Attribute already exists, so select it and set it's value
      node = @_selectSingle(XPath, @dom)
      if node.nodeType is 1
        throw new Error 'Using setAttribute() to set elements is unsupported. Use setElement() or insertElementAt() instead.'
      if node.nodeType is 3
        throw new Error 'Cannot set an attribute of a text node.'
      if node.nodeType isnt 2
        throw new Error 'XPath has to select an attribute.'
      parent = node.ownerElement
      attributeName = node.nodeName
      parent.setAttribute(attributeName, value)
    catch error
      # Case 2: Attribute does not exist yet, so get parent node and create it
      if error.message is 'Nothing selected.'
        parts = XPath.split('/@')
        if parts.length isnt 2
          throw new Error 'XPath has none or more than one attribute accessor.'
        if parts[1].match(/^[a-z][a-z0-9]*$/i) is undefined
          throw new Error 'Attribute accessor in XPath invalid.'
        parent = @_selectSingle(parts[0], @dom)
        attributeName = parts[1]
        parent.setAttribute(attributeName, value)
        node = @_selectSingle(XPath, @dom)
      else
        throw error
    path = @__getPath(parent)
    op = {p:path.concat(attributeName), as:value}
    @submitOp [op], callback
    
  removeElement: (XPath, callback) ->
    @_ensureDOMexists()
    node = @_selectSingle(XPath, @dom)
    if node.nodeType is 2
      throw new Error 'Using removeElement() to remove attributes is unsupported. Use removeAttribute() instead.'
    if node.nodeType is 3
      throw new Error 'Using removeElement() to remove text content is unsupported. Use removeTextAt() instead.'
    if node.nodeType is 1 and not node.parentNode.parentNode?
      throw new Error 'Removing root element is unsupported.'
    path = @__getPath(node)
    op = {p:path, ed:node.nodeName.toLowerCase()}
    node.parentNode.removeChild(node)
    @submitOp [op], callback
    
  removeAttribute: (XPath, callback) ->
    @_ensureDOMexists()
    node = @_selectSingle(XPath, @dom)
    if node.nodeType is 1
      throw new Error 'Using removeAttribute() to remove elements is unsupported. Use removeElement() instead.'
    if node.nodeType is 3
      throw new Error 'Cannot remove an attribute of a text node.'
    if node.nodeType isnt 2
      throw new Error 'XPath has to select an attribute.'
    parent = node.ownerElement
    path = @__getPath(parent)
    attributeName = node.nodeName
    op = {p:path.concat(attributeName), ad:parent.getAttribute(attributeName)}
    parent.removeAttribute(attributeName)
    @submitOp [op], callback
  
  insertTextAt:(XPath, pos, value, callback) ->
    @_getOpForInsertTextAt XPath, pos, value, (op) =>
      @submitOp op, callback

  _getOpForInsertTextAt: (XPath, pos, value, callback) ->
    @_ensureDOMexists()
    pos = @_transformTextPosition(pos)
    try
      # Case 1: Text node already exists, so select it and set it's value
      node = @_selectSingle(XPath, @dom)
      if node.nodeType is 2
        throw new Error 'Using insertTextAt() to set attribute content is unsupported. Use setAttribute() instead.'
      if node.nodeType isnt 3
        throw new Error 'XPath expression does not point at a text node.'
      if node.data.length < pos
        throw new Error "Cannot insert text at position #{pos}, element's content is only #{node.data.length} characters long."
      node.data = node.data[...pos] + value + node.data[pos..]
      path = @__getPath(node)
      op = {ti:value, p:path.concat(pos)}
    catch error
      # Case 2: Text node does not exist yet, so get parent node and create it
      if error.message is 'Nothing selected.'
        parts = XPath.split('/text()')
        if parts.length isnt 2
          throw new Error 'XPath has none or more than one "text()" expression.'
        if parts[1] isnt '' and parts[1].match(/^\[(\d+)\]$/) is undefined
          throw new Error 'Text node accessor in XPath invalid.'
        if pos isnt 0
          throw new Error "Cannot insert text at position #{pos}, only inserting at position 0 is possible."
        parent = @_selectSingle(parts[0], @dom)
        path = @__getPath(parent)
        newTextNode = @dom.createTextNode(value)
        op = {ei:'>' + value}
        existingTextNodes = @_getChildrenByNodeName(parent, 'text()')
        if parent.childNodes[0] is undefined or existingTextNodes.length != 0
          if existingTextNodes.length != 0
            op.p = path.concat(parent.childNodes.length)
          else
            op.p = path.concat(0)
          parent.appendChild(newTextNode)
        else
          parent.insertBefore(newTextNode, parent.childNodes[0])
          op.p = path.concat(0)
      else 
        throw error
    callback([op])
  
  removeTextAt:(XPath, pos, length, callback) ->
    @_getOpForRemoveTextAt XPath, pos, length, (op) =>
      @submitOp op, callback

  _getOpForRemoveTextAt: (XPath, pos, length, callback) -> # length = -1 means: Delete everything after pos
    @_ensureDOMexists()
    node = @_selectSingle(XPath, @dom)
    if node.nodeType is 2
      throw new Error 'Using removeTextAt() to remove attribute content is unsupported. Use setAttribute() instead.'
    if node.nodeType isnt 3
      throw new Error 'XPath expression does not point at a text node.'
    pos = @_transformTextPosition(pos)
    if length == -1
      length = node.data.length - pos
    path = @__getPath(node)
    op = {p:path.concat(pos), td:node.data[pos...(pos + length)]}
    node.data = node.data[...pos] + node.data[pos + length...]
    if node.data.length == 0 # we deleted all text, so delete the text node
      op = {p:path, ed:'#text'}
      node.parentNode.removeChild(node)
    callback([op])

  replaceTextAt: (XPath, pos, value, callback) ->
    @_getOpForInsertTextAt XPath, pos, value, (op1) =>
      @_getOpForRemoveTextAt XPath, pos + value.length, -1, (op2) =>
        @submitOp op1.concat(op2), callback
    
if WEB?
  exports.types ||= {}
  exports.types.xmlapiclass = XMLAPIClass
else
  module.exports = XMLAPIClass