# This is the implementation of the XML OT type.
# 
# Each operation component is an object with a p:PATH component. The path is a 
# list of zero-indexed numbers that identify child nodes below each respective
# element.
# 
# For example, given the following document:
#
# <wrapper>
#   <a>123</a>
#   text
#   <x>
#     <a>456</a>
#   </x>
#   hello
# </wrapper>
#
# An operation to delete the second "a" element (<a>456</a>) would be the following:
# {p:[2,0], ed:'a'}
#
# "p:[2,0]" means that the element referenced can be found in the DOM using
# "root.childNodes[2].childNodes[0]".
# "ed:'a'" means that the element to delete is an "a" element. This information
# is given for sanity checks, it is not necessarily needed for the logic, but 
# required by the API.
#
# An operation to edit the second text node (creating 'hello world') would be
# the following: {p:[3,5], ti:' world'}
#
# "p:[3,5]" in this case means that the element referenced can be found as the
# fourth child of the root element ("root.childNodes[3]"). Since this is a 
# text-node, the path is followed by a offset pointer into the text ("5").
# 
# Summary of operations
# ===============================|=========================
# {p:[path,offset], ti:str}      | inserts the string [str] at [offset] into the text node at [path].
# {p:[path,offset], td:str}      | deletes the string [str] at [offset] from the text node at [path].
# {p:[path,pos], ei:xml}         | inserts the element that can be parsed from [xml] as the [pos]th child of the element at [path]. If [xml] is a string that starts with '>', a new text node is created
# {p:[path,pos], ed:elem}        | deletes the [pos]th child of the element at [path] if it's elementName is [elem]
# {p:[path,pos1], em:pos2}       | moves the [pos1]th child such that the node will be the [pos2]th child of the element at [path]
# {p:[path,name], as:value}      | sets or overwrites the attribute [name] with [value] in the element at [path]
# {p:[path,name], ad:value}      | deletes the attribute [name] in the element at [path] if its value is [value]
#

if WEB?
  text = exports.types.text
else
  text = require './text'

if require?
  xmldom = require 'xmldom'
  DOMParser = xmldom.DOMParser
  XMLSerializer = xmldom.XMLSerializer
else
  DOMParser = window.DOMParser
  XMLSerializer = window.XMLSerializer

class XMLClass
  constructor: (@name, @docType) ->

  parser: new DOMParser()
  serializer: new XMLSerializer()

  create: -> null

  checkValidOp: (op) -> 

  apply: (snapshot, op) ->
    @checkValidOp op
    if snapshot? and snapshot.length > 0
      doc = @parser.parseFromString(snapshot, @docType)
    else if  op[0]? and op[0].ei?
      if op[0].ei[0] == '>'
        throw new Error 'Cannot use a text node as root element' 
      # first insert
      doc = @parser.parseFromString(op[0].ei, @docType)
      return @serializer.serializeToString(@apply2DOM(doc, op[1..]))
    else
      throw 'Document is empty and no root element is created by op'
    return @serializer.serializeToString(@apply2DOM(doc, op))

  apply2DOM: (doc, op) ->
    try
      for component in op # an operation may contain more than one component            
        elem = doc.documentElement

        for step, i in component.p 
          if parseInt(step) == step # position pointer to n'th element
            break if component.p.length - i == 1
            elem = elem.childNodes[step]
          else
            if component.as is undefined and component.ad is undefined
              throw new Error 'Path contains something that is no number'
          if elem is undefined or (elem == doc.documentElement and component.as is undefined and component.ad is undefined)
            throw new Error 'Path invalid'

        if component.ti != undefined # Text insert
          if elem.nodeName.toLowerCase() != '#text'
            throw new Error 'Cannot insert text into a non-text-node'
          elem.data = elem.data[...step] + component.ti + elem.data[step..]

        else if component.td != undefined # Text delete
          if elem.nodeName.toLowerCase() != '#text'
            throw new Error 'Cannot delete text from a non-text-node'
          if elem.data[step...step + component.td.length] != component.td
            throw new Error 'Deleted string does not match'
          elem.data = elem.data[...step] + elem.data[step + component.td.length..]

        else if component.ei != undefined and component.ed != undefined # Element replace
          if step < 0 or elem.childNodes.length <= step
              throw new Error 'Position invalid, cannot replace element at pos ' + step
          if component.ed != elem.childNodes[step].nodeName.toLowerCase()
            throw new Error 'Name of element to replace does not match'
          if component.ei[0] == '>' # insert text node
            newElem = doc.createTextNode(component.ei[1...])
          else
            newDoc = @parser.parseFromString(component.ei, @docType)
            newElem = @api._extractPayload(newDoc.documentElement)
          elem.replaceChild(newElem, elem.childNodes[step])

        else if component.ei != undefined # Element insert
          if step < 0 or elem.childNodes.length < step
              throw new Error 'Position invalid, cannot insert element at pos ' + step
          if component.ei[0] == '>' # insert text node
            newElem = doc.createTextNode(component.ei[1...])
          else
            newDoc = @parser.parseFromString(component.ei, @docType)
            newElem = @api._extractPayload(newDoc.documentElement)
          if step == elem.childNodes.length # insert at end => appendChild()
            elem.appendChild(newElem)
          else
            elem.insertBefore(newElem, elem.childNodes[step])

        else if component.ed != undefined # Element delete
          if step < 0
            throw new Error 'Position invalid'
          if component.ed != elem.childNodes[step].nodeName.toLowerCase()
            throw new Error 'Name of element to delete does not match'
          elem.removeChild(elem.childNodes[step])

        else if component.em != undefined
          if step < 0 or elem.childNodes.length <= step
            throw new Error 'Position invalid, cannot move element at pos ' + step
          if parseInt(component.em) != component.em or component.em < 0 or component.em >= elem.childNodes.length
            'Position to move to is invalid'
          if elem.childNodes.length - component.em == 1 # special case, moving to last child
            elem.appendChild(elem.childNodes[step])
          else
            if step < component.em
              elem.insertBefore(elem.childNodes[step], elem.childNodes[component.em + 1])
            else if step > component.em
              elem.insertBefore(elem.childNodes[step], elem.childNodes[component.em])
            # step == component.em is a noop
            # Furthermore, there's bug in XMLDOM: Inserting an element before itself crashes the library :D

        else if component.as != undefined # Attribute set
          if typeof step isnt 'string' or typeof component.as isnt 'string'
            throw new Error "Attribute data not strings (it was [#{[typeof step, typeof component.as]}])"
          elem.setAttribute(step, component.as)

        else if component.ad != undefined # Attribute delete
          if typeof step isnt 'string' or typeof component.ad isnt 'string'
            throw new Error "Attribute data not strings (it was [#{[typeof step, typeof component.ad]}])"
          if elem.getAttribute(step) != component.ad
            throw new Error 'Value of attribute to delete does not match'
          elem.removeAttribute(step)

        else
          throw new Error 'invalid / missing instruction in op'
    catch error
      throw error

    return doc

  # Checks if two paths, p1 and p2 match.
  pathMatches: (p1, p2) ->
    return false unless p1.length == p2.length
    for p, i in p1
      return false if p != p2[i]
    return true

  append: (dest, component) ->
    if dest.length != 0 and @pathMatches component.p, (last = dest[dest.length - 1]).p
      if last.ad != undefined and last.as == undefined and
          component.as != undefined and component.ad == undefined
        last.as = component.as
      else if component.em != undefined and component.p[component.p.length-1] == component.em
        null # don't do anything
      else
        dest.push component
    else
      dest.push component

  compose: (op1, op2) ->
    @checkValidOp op1
    @checkValidOp op2

    newOp = @clone op1
    @append newOp, component for component in op2
    return newOp

  # hax, copied from test/types/xml. Apparently this is still the fastest way to deep clone an object, assuming
  # we have browser support for JSON.
  # http://jsperf.com/cloning-an-object/12
  clone: (o) -> JSON.parse(JSON.stringify o)

  # Returns true if an op at otherPath may affect an op at path
  canOpAffectOp: (otherPath, path) ->
    return true if otherPath.length == 0
    return false if path.length == 0

    path = path[...path.length-1]
    otherPath = otherPath[...otherPath.length-1]

    for p,i in otherPath
      if i >= path.length
        return false
      if p != path[i]
        return false

    # Same
    return true

  # transform component so it applies to a document with otherComponent applied.
  transformComponent: (dest, component, otherComponent, type) ->
    component = @clone component

    common = otherComponent.p.length - 1 if @canOpAffectOp otherComponent.p,  component.p
    common2 =  component.p.length - 1 if @canOpAffectOp  component.p, otherComponent.p

    cplength =  component.p.length
    otherComponentplength = otherComponent.p.length

    if common?
      commonOperand = cplength == otherComponentplength
      # transform based on otherComponent
      if otherComponent.ti != undefined || otherComponent.td != undefined
        # String op vs string op - pass through to text type
        if component.ti != undefined || component.td != undefined
          throw new Error("must be a string?") unless commonOperand

          # Convert an op component to a text op component
          convert = (component) ->
            newC = p:component.p[component.p.length - 1]
            if component.ti?
              newC.i = component.ti
            else
              newC.d = component.td
            newC

          tc1 = convert component
          tc2 = convert otherComponent

          res = []
          text._tc res, tc1, tc2, type
          for tc in res
            jc = { p: component.p[...common] }
            jc.p.push(tc.p)
            jc.ti = tc.i if tc.i?
            jc.td = tc.d if tc.d?
            @append dest, jc
          return dest
      else if otherComponent.ei != undefined && otherComponent.ed != undefined
        if otherComponent.p[common] == component.p[common]
          # noop
          if !commonOperand
            # we're below the deleted element, so -> noop
            return dest
          else if component.ed != undefined
            # we're trying to delete the same element, -> noop
            if component.ei != undefined and type == 'left'
              # we're both replacing one element with another. only one can
              # survive!
              component.ed = @clone otherComponent.ei
            else
              return dest
      else if otherComponent.ei != undefined
        if component.ei != undefined and component.ed == undefined and commonOperand and component.p[common] == otherComponent.p[common]
          # in li vs. li, left wins.
          if type == 'right'
            component.p[common]++
        else if otherComponent.p[common] <= component.p[common]
          component.p[common]++

        if component.em != undefined
          if commonOperand
            # otherComponent edits the same list we edit
            if otherComponent.p[common] <= component.em
              component.em++
            # changing component.from is handled above.
      else if otherComponent.ed != undefined
        if component.em != undefined
          if commonOperand
            if otherComponent.p[common] == component.p[common]
              # they deleted the thing we're trying to move
              return dest
            # otherComponent edits the same list we edit
            p = otherComponent.p[common]
            from = component.p[common]
            to = component.em
            if p < to || (p == to && from < to)
              component.em--

        if otherComponent.p[common] < component.p[common]
          component.p[common]--
        else if otherComponent.p[common] == component.p[common]
          if otherComponentplength < cplength
            # we're below the deleted element, so -> noop
            return dest
          else if component.ed != undefined
            if component.ei != undefined
              # we're replacing, they're deleting. we become an insert.
              delete component.ed
            else
              # we're trying to delete the same element, -> noop
              return dest
      else if otherComponent.em != undefined
        if component.em != undefined and cplength == otherComponentplength
          # lm vs lm, here we go!
          from = component.p[common]
          to = component.em
          otherFrom = otherComponent.p[common]
          otherTo = otherComponent.em
          if otherFrom != otherTo
            # if otherFrom == otherTo, we don't need to change our op.

            # where did my thing go?
            if from == otherFrom
              # they moved it! tie break.
              if type == 'left'
                component.p[common] = otherTo
                if from == to # ugh
                  component.em = otherTo
              else
                return dest
            else
              # they moved around it
              if from > otherFrom
                component.p[common]--
              if from > otherTo
                component.p[common]++
              else if from == otherTo
                if otherFrom > otherTo
                  component.p[common]++
                  if from == to # ugh, again
                    component.em++

              # step 2: where am i going to put it?
              if to > otherFrom
                component.em--
              else if to == otherFrom
                if to > from
                  component.em--
              if to > otherTo
                component.em++
              else if to == otherTo
                # if we're both moving in the same direction, tie break
                if (otherTo > otherFrom and to > from) or
                   (otherTo < otherFrom and to < from)
                  if type == 'right'
                    component.em++
                else
                  if to > from
                    component.em++
                  else if to == otherFrom
                    component.em--
        else if component.ei != undefined and component.ed == undefined and commonOperand
          # li
          from = otherComponent.p[common]
          to = otherComponent.em
          p = component.p[common]
          if p > from
            component.p[common]--
          if p > to
            component.p[common]++
        else
          # ld, ld+li, si, sd, na, oi, od, oi+od, any li on an element beneath
          # the lm
          #
          # i.e. things care about where their item is after the move.
          from = otherComponent.p[common]
          to = otherComponent.em
          p = component.p[common]
          if p == from
            component.p[common] = to
          else
            if p > from
              component.p[common]--
            if p > to
              component.p[common]++
            else if p == to
              if from > to
                component.p[common]++
      else if otherComponent.as != undefined and otherComponent.ad != undefined
        if component.p[common] == otherComponent.p[common]
          if component.as != undefined and commonOperand
            # we inserted where someone else replaced
            if type == 'right'
              # left wins
              return dest
            else
              # we win, make our op replace what they inserted
              component.ad = otherComponent.as
          else
            # -> noop if the other component is deleting the same object (or any
            # parent)
            return dest
      else if otherComponent.as != undefined
        if component.as != undefined and component.p[common] == otherComponent.p[common]
          # left wins if we try to insert at the same place
          if type == 'left'
            @append dest, {p:component.p, ad:otherComponent.as}
          else
            return dest
      else if otherComponent.ad != undefined
        if component.p[common] == otherComponent.p[common]
          return dest if !commonOperand
          if component.as != undefined
            delete component.ad
          else
            return dest

    @append dest, component
    return dest
    
  transformComponentX: (left, right, destLeft, destRight) ->
    @transformComponent destLeft, left, right, 'left'
    @transformComponent destRight, right, left, 'right'
    
  transformX: (leftOp, rightOp) ->
    @checkValidOp leftOp
    @checkValidOp rightOp

    newRightOp = []

    for rightComponent in rightOp
      # Generate newLeftOp by composing leftOp by rightComponent
      newLeftOp = []

      k = 0
      while k < leftOp.length
        nextC = []
        @transformComponentX leftOp[k], rightComponent, newLeftOp, nextC
        k++

        if nextC.length == 1
          rightComponent = nextC[0]
        else if nextC.length == 0
          @append newLeftOp, l for l in leftOp[k..]
          rightComponent = null
          break
        else
          # Recurse.
          [l_, r_] = transformX leftOp[k..], nextC
          @append newLeftOp, l for l in l_
          @append newRightOp, r for r in r_
          rightComponent = null
          break
    
      @append newRightOp, rightComponent if rightComponent?
      leftOp = newLeftOp
    
    [leftOp, newRightOp]
  
  transform: (op, otherOp, type) ->
    throw new Error "type must be 'left' or 'right'" unless type == 'left' or type == 'right'

    return op if otherOp.length == 0

    # TODO: Benchmark with and without this line. I _think_ it'll make a big difference...?
    return @transformComponent [], op[0], otherOp[0], type if op.length == 1 and otherOp.length == 1

    if type == 'left'
      [left, _] = @transformX op, otherOp
      left
    else
      [_, right] = @transformX otherOp, op
      right

if WEB?
  exports.types ||= {}
  exports.types.xmlclass = XMLClass
else
  module.exports = XMLClass

