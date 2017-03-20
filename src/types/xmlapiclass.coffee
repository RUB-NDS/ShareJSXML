# XML and HTML document API

class XMLAPIClass
  constructor: (@type) ->
    @xpath = new TinyXPathProcessor()

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
  
  class TinyXPathProcessor
    traverseXMLTree: (dom, tinyXPath) ->
      path = []
      if tinyXPath[0] isnt '/'
        throw new Error 'TinyXPath expression does not start with slash'
      steps = tinyXPath.split('/')[1...]
      [rootName, pos] = steps[0].split('[')
      if rootName isnt dom.documentElement.nodeName.toLowerCase() or (pos? and pos != '1]')
        throw new Error 'Root in TinyXPath expression invalid'
      child = elem = dom.documentElement
      for step in steps[1...]
        [childName, filter] = step.split('[')
        if filter? and filter[0] == '@'
          [filterAttribute, filterValue] = filter[1...-1].split('=')
          found = false
          for child in @getChildrenByNodeName(elem, childName)
            if child.getAttribute(filterAttribute) == filterValue
              found = true
              break
          if !found
            throw new Error "Child \"#{childName}\" (Attribute #{filter[1...-1]}) not found"
        else
          pos = if filter isnt undefined then parseInt(filter[...-1]) else 1
          if pos is undefined or pos < 1
            throw new Error "Position #{pos} invalid"
          child = @getChildrenByNodeName(elem, childName)[pos - 1] # TinyXPath always returns the first match; XPath is 1-indexed
          if child is undefined
            @getChildrenByNodeName(elem, childName)[pos - 1]
            throw new Error "Child \"#{childName}\" (position #{pos}) not found"
        path.push(Array.prototype.indexOf.call(elem.childNodes, child))
        elem = child
      return [path, child]

    getChildrenByNodeName: (elem, nodeName) ->
      nodeName = '#text' if nodeName is 'text()'
      result = []
      for child in elem.childNodes
        if child.nodeName.toLowerCase() == nodeName.toLowerCase()
          result.push(child)
      return result

    checkTinyXPath: (dom, tinyXPath) ->
      parts = tinyXPath.split('/@')
      if parts.length > 2
        throw new Error 'TinyXPath expression has more than one attribute accessor'
      if parts.length > 1 and parts[1].match(/^[a-z][a-z0-9]*$/i) is null
        throw new Error 'Attribute accessor in TinyXPath expression is invalid'
      if parts[0].match(/^(\/[a-z@][a-z0-9:]*(\(\))?(\[(\d+|(@[a-z][a-z0-9]*=[a-z0-9]+))\])?)*$/i) is null
        throw new Error 'TinyXPath expression invalid'
      return tinyXPath.split('/@')

  # adds TinyXPathProcessor to the prototype of XMLAPIClass
  TinyXPathProcessor: TinyXPathProcessor

  _transformElementPosition: (pos) ->
    pos = if pos isnt undefined then parseInt(pos) else 1
    if pos is undefined or pos < 1
      throw new Error "Position #{pos} invalid"
    return pos - 1
    
  _transformTextPosition: (pos) ->
    pos = if pos isnt undefined then parseInt(pos) else 0
    if pos is undefined or pos < 0
      throw new Error "Position #{pos} invalid"
    return pos

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

  addListener: (tinyXPath, event, cb) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName isnt undefined
      throw new Error 'Adding a listener on an attribute is unsupported. Register the listener on the element.'
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)
    l = {path, event, cb}
    @_listeners.push l
    return l
  
  removeListener: (l) ->
    i = @_listeners.indexOf l
    return false if i < 0
    @_listeners.splice i, 1
    return true

  # Get the text content of a document
  getText: -> @snapshot
  
  getReadonlyDOM: -> 
    @_ensureDOMexists()
    return @dom
  
  # Gets elements, text and attribute values
  get: (tinyXPath) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)
    if path.length is 0
      throw new Error 'Using get() to retrieve the root is unsupported. Use getText() instead.'
    if attributeName is undefined
      return @type.serializer.serializeToString(elem)
    else
      return elem.getAttribute(attributeName)
  
  createRoot: (value, callback) ->
    if @dom and @dom.documentElement isnt undefined
      throw new Error 'Replacing root element is unsupported. Create a new document instead.'
    @dom = @type.parser.parseFromString(value, @type.docType)
    @submitOp [{ei:value, p:[]}], callback
  
  # Replaces/sets elements
  setElement: (tinyXPathToParent, pos, value, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPathToParent)
    if attributeName isnt undefined
      throw new Error 'Using setElement() to set attributes is unsupported. Use setAttribute() instead.'
    if steps == '/'
      throw new Error 'Replacing root element is unsupported. Create a new document instead.'
    @_ensureDOMexists()
    [path, parent] = @xpath.traverseXMLTree(@dom, steps)
    if parent.nodeName.toLowerCase() == '#text'
      throw new Error 'Using setElement() to set text is unsupported. Use insertTextAt() instead.'
    pos = @_transformElementPosition(pos)
    if parent.childNodes.length < pos
      throw new Error "Cannot set element with index #{pos}, parent has only #{parent.childNodes.length} children"
    op = {p:path.concat(pos)}
    op.ei = value
    newDoc = @type.parser.parseFromString(value, @type.docType)
    newElem = @_extractPayload(newDoc.documentElement)
    if parent.childNodes[pos] is undefined
      throw new Error "Using setElement() to append an element is unsupported. Use insertElementAt() instead." 
    op.ed = parent.childNodes[pos].nodeName.toLowerCase()
    parent.replaceChild(newElem, parent.childNodes[pos])    
    @submitOp [op], callback
    
  insertElementAt: (tinyXPathToParent, pos, value, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPathToParent)
    if attributeName isnt undefined
      throw new Error 'Using insertElementAt() to set attributes is unsupported. Use setAttribute() instead.'
    if steps == '/'
      if not @dom or @dom.documentElement is undefined
        throw new Error 'Inserting root element is unsupported. Create a new document instead.'
      else
        throw new Error 'Having more than one root element is no valid XML'
    @_ensureDOMexists() # normalizes DOM
    [path, parent] = @xpath.traverseXMLTree(@dom, steps)
    if parent.nodeName.toLowerCase() == '#text'
      throw new Error 'Using insertElementAt() to set text is unsupported. Use insertTextAt() instead.'
    pos = @_transformElementPosition(pos)
    if parent.childNodes.length < pos
      throw new Error "Cannot set element at position #{pos}, parent has only #{parent.childNodes.length} children"
    op = {p:path.concat(pos)}
    op.ei = value
    newDoc = @type.parser.parseFromString(value, @type.docType)
    newElem = @_extractPayload(newDoc.documentElement)
    if parent.childNodes[pos] is undefined
      parent.appendChild(newElem)
    else
      parent.insertBefore(newElem, parent.childNodes[pos])
    @submitOp [op], callback
  
  moveElement: (tinyXPath, moveToPos, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName isnt undefined
      throw new Error 'Attributes cannot be moved'
    if steps == '/'
      throw new Error 'Root element cannot be moved'
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)
    moveToPos = @_transformElementPosition(moveToPos)
    if elem.parentNode.childNodes.length <= moveToPos
      throw new Error "Cannot move element to position #{moveToPos}, parent has only #{elem.parentNode.childNodes.length} children"
    op = {p:path, em:moveToPos}
    if elem.parentNode.childNodes.length - moveToPos == 1 # special case, moving to last child
      elem.parentNode.appendChild(elem)
    else
      if path[path.length - 1] < moveToPos
        elem.parentNode.insertBefore(elem, elem.parentNode.childNodes[moveToPos + 1])
      else
        elem.parentNode.insertBefore(elem, elem.parentNode.childNodes[moveToPos])
    @submitOp [op], callback

  # Replaces/sets attributes
  setAttribute: (tinyXPath, value, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName is undefined
      throw new Error 'Using setAttribute() to set elements is unsupported. Use setElement() or insertElementAt() instead.'
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)  
    if elem.nodeName.toLowerCase() == '#text'
      throw new Error 'Cannot set an attribute of a text node.'
    op = {p:path.concat(attributeName), as:value}
    elem.setAttribute(attributeName, value)  
    @submitOp [op], callback
    
  removeElement: (tinyXPath, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName isnt undefined
      throw new Error 'Using removeElement() to remove attributes is unsupported. Use removeAttribute() instead.'
    if steps == '/'
      throw new Error 'Removing root element is unsupported'
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)
    if elem.nodeName.toLowerCase() == '#text'
      throw new Error 'Using removeElement() to remove text content is unsupported. Use removeTextAt() instead.'
    op = {p:path, ed:elem.nodeName.toLowerCase()}
    elem.parentNode.removeChild(elem)
    @submitOp [op], callback
    
  removeAttribute: (tinyXPath, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName is undefined
      throw new Error 'Using removeAttribute() to set elements is unsupported. Use removeElement() instead.'
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)  
    if elem.nodeName.toLowerCase() == '#text'
      throw new Error 'Cannot remove an attribute of a text node.'
    op = {p:path.concat(attributeName), ad:elem.getAttribute(attributeName)}
    elem.removeAttribute(attributeName)  
    @submitOp [op], callback
  
  insertTextAt:(tinyXPath, pos, value, callback) ->
    @_getOpForInsertTextAt tinyXPath, pos, value, (op) =>
      @submitOp op, callback

  _getOpForInsertTextAt: (tinyXPath, pos, value, callback) ->
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName isnt undefined
      throw new Error 'Using insertTextAt() to set attribute content is unsupported. Use setAttribute() instead.'
    pos = @_transformTextPosition(pos)
    @_ensureDOMexists()
    try
      [path, elem] = @xpath.traverseXMLTree(@dom, steps)
      if elem.nodeName.toLowerCase() != '#text'
        throw new Error 'TinyXPath expression does not point at a text node'
      if elem.data.length < pos
        throw new Error "Cannot insert text at position #{pos}, element's content is only #{elem.data.length} characters long"
      op = {ti:value, p:path.concat(pos)}
      elem.data = elem.data[...pos] + value + elem.data[pos..]
    catch error
      # if the text node does not exist yet, find the parent and create one
      if pos != 0 or error.message.lastIndexOf('Child "text()" (position ') != 0
        throw error
      op = {ei:'>' + value}
      steps = steps[...steps.lastIndexOf('/')]
      [path, elem] = @xpath.traverseXMLTree(@dom, steps)
      newTextNode = @dom.createTextNode(value)
      existingTextNodes = @xpath.getChildrenByNodeName(elem, 'text()')
      if elem.childNodes[0] is undefined or existingTextNodes.length != 0
        if existingTextNodes.length != 0
          op.p = path.concat(elem.childNodes.length)
        else
          op.p = path.concat(0)
        elem.appendChild(newTextNode)
      else
        elem.insertBefore(newTextNode, elem.childNodes[0])
        op.p = path.concat(0)
    callback([op])
  
  removeTextAt:(tinyXPath, pos, length, callback) ->
    @_getOpForRemoveTextAt tinyXPath, pos, length, (op) =>
      @submitOp op, callback

  _getOpForRemoveTextAt: (tinyXPath, pos, length, callback) -> # length = -1 means: Delete everything after pos
    [steps, attributeName] = @xpath.checkTinyXPath(@dom, tinyXPath)
    if attributeName isnt undefined
      throw new Error 'Using removeTextAt() to remove attribute content is unsupported. Use setAttribute() instead.'
    pos = @_transformTextPosition(pos)
    @_ensureDOMexists()
    [path, elem] = @xpath.traverseXMLTree(@dom, steps)
    if elem.nodeName.toLowerCase() != '#text'
      throw new Error 'TinyXPath expression does not point at a text node'
    if elem.data.length < pos
      throw new Error "Cannot insert text at position #{pos}, element's content is only #{elem.data.length} characters long"
    if length == -1
      length = elem.data.length - pos
    op = {p:path.concat(pos), td:elem.data[pos...(pos + length)]}
    elem.data = elem.data[...pos] + elem.data[pos + length...]
    if elem.data.length == 0 # we deleted all text, so delete the text node
      op = {p:path, ed:'#text'}
      elem.parentNode.removeChild(elem)
    callback([op])

  replaceTextAt: (tinyXPath, pos, value, callback) ->
    @_getOpForInsertTextAt tinyXPath, pos, value, (op1) =>
      @_getOpForRemoveTextAt tinyXPath, pos + value.length, -1, (op2) =>
        @submitOp op1.concat(op2), callback
    
if WEB?
  exports.types ||= {}
  exports.types.xmlapiclass = XMLAPIClass
else
  module.exports = XMLAPIClass