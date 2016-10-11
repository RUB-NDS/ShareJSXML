# Tests for XML OT type. (src/types/xml.coffee)

nativetype = require '../../src/types/xml'

randomWord = require './randomWord'

util = require 'util'
p = util.debug
i = util.inspect

genTests = (type) ->
  sanity:
    'name is xml': (test) ->
      test.strictEqual type.name, 'xml'
      test.done()

    'create() returns null': (test) ->
      test.deepEqual type.create(), null
      test.done()
      
  path:
    'paths are correctly parsed': (test) ->
      sampleXML = '<foo>abc<p>123</p>def<p>456</p></foo>'
      type.apply(sampleXML, [{p:[0,0], td:''}]) # accesses "abc"
      type.apply(sampleXML, [{p:[1,0,1], td:''}]) # points into "123"
      type.apply(sampleXML, [{p:[2,1], td:''}]) # points into "def"
      
      try
        type.apply(sampleXML, [{p:[Number.NaN], td:''}]) # evil check ;)
        test.fail()
      catch error
        test.strictEqual(error.message, 'Path contains something that is no number')
      
      try
        type.apply(sampleXML, [{p:['foo'], td:''}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Path contains something that is no number')
      
      try
        type.apply(sampleXML, [{p:[4,0], td:''}]) # there is no fifth child
        test.fail()
      catch error
        test.strictEqual(error.message, 'Path invalid')
      
      try
        type.apply(sampleXML, [{p:[-1,0], td:''}]) # negative is bad
        test.fail()
      catch error
        test.strictEqual(error.message, 'Path invalid')
      
      test.done()
    
    'path matching': (test) ->
      test.strictEqual(true, type.pathMatches([], []))
      test.strictEqual(true, type.pathMatches([1], [1]))
      test.strictEqual(true, type.pathMatches([1,2,3], [1,2,3]))
      test.strictEqual(false, type.pathMatches([1,2,3], [1,3,2]))
      test.strictEqual(false, type.pathMatches([1,2,3], [1,2]))
      test.strictEqual(false, type.pathMatches([1], []))
      
      test.done()

    'compose ad,as --> ad+as': (test) ->
      test.deepEqual [{p:['foo'], ad:1, as:2}], type.compose [{p:['foo'],ad:1}],[{p:['foo'],as:2}]
      test.deepEqual [{p:['foo'], ad:1},{p:['bar'], as:2}], type.compose [{p:['foo'],ad:1}],[{p:['bar'],as:2}]
      test.done()

    'transform returns sane values': (test) ->
      t = (op1, op2) ->
        test.deepEqual op1, type.transform op1, op2, 'left'
        test.deepEqual op1, type.transform op1, op2, 'right'

      t [], []
      t [{p:['foo'], as:1}], []
      t [{p:['foo'], as:1}], [{p:['bar'], as:2}]
      test.done()

  # Text handling
  text:
    'Apply works': (test) ->
      test.deepEqual '<body>abczzz<p>123</p>def<p>456</p></body>', type.apply('<body>abc<p>123</p>def<p>456</p></body>', [{p:[0,3], ti:'zzz'}])
      test.deepEqual '<body>abc<p>123</p>defzzz<p>456</p></body>', type.apply('<body>abc<p>123</p>def<p>456</p></body>', [{p:[2,3], ti:'zzz'}])
      test.deepEqual '<body>abc<p>123</p>def<p>4</p></body>', type.apply('<body>abc<p>123</p>def<p>456</p></body>', [{p:[3,0,1], td:'56'}])
      test.deepEqual '<body>abc<p>123</p>def<p></p></body>', type.apply('<body>abc<p>123</p>def<p>456</p></body>', [{p:[3,0,0], td:'456'}])        
      
      try
        type.apply('<body><p>123</p></body>', [{p:[0,0], ti:''}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Cannot insert text into a non-text-node')
        
      try
        type.apply('<body><p>123</p></body>', [{p:[0,0], td:''}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Cannot delete text from a non-text-node')
      
      try
        type.apply('<body>123</body>', [{p:[0,0], td:'abc'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Deleted string does not match')

      test.deepEqual '<body>abc</body>', type.apply('<body></body>', [{p:[0], ei:'>abc'}])
      test.deepEqual '<body><p>abc</p></body>', type.apply('<body><p></p></body>', [{p:[0,0], ei:'>abc'}])
      test.deepEqual '<body><p/>abc<p/></body>', type.apply('<body><p/><p/></body>', [{p:[1], ei:'>abc'}])
      test.deepEqual '<body id="1"/>', type.apply('<body></body>',[{p:["id"],as:"1"}])
      
      test.deepEqual '<body id="1"/>', type.apply('', [{ei:'<body></body>',p:[]},{p:["id"],as:"1"}])
      

      test.done()
    
    'transform splits deletes': (test) ->
      test.deepEqual type.transform([{p:[0], td:'ab'}], [{p:[1], ti:'x'}], 'left'), [{p:[0], td:'a'}, {p:[1], td:'b'}]
      test.done()
    
    'deletes cancel each other out': (test) ->
      test.deepEqual type.transform([{p:['k', 5], td:'a'}], [{p:['k', 5], td:'a'}], 'left'), []
      test.done()

    'blank inserts do not throw error': (test) ->
      test.deepEqual type.transform([{p: ['k', 5], ti:''}], [{p: ['k', 3], ti: 'a'}], 'left'), []
      test.done()
      
  element:
    'Apply sanity checks': (test) ->
      test.deepEqual '<body/>', type.apply('', [{ei:'<body/>'}])
      test.deepEqual '<body><p>123</p></body>', type.apply('<body></body>', [{p:[0], ei:'<p>123</p>'}])
      test.deepEqual '<body><p>456</p><p>123</p></body>', type.apply('<body><p>123</p></body>', [{p:[0], ei:'<p>456</p>'}])
      
      test.deepEqual '<body><p>456</p><p>123</p></body>', type.apply('<body></body>', [{p:[0], ei:'<p>123</p>'},{p:[0], ei:'<p>456</p>'}])
      
      try
        type.apply('<body></body>', [{p:[1], ei:'<p>123</p>'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Position invalid, cannot insert element at pos 1')
        
      # Tests with namespaces
      sampleXML = '<html:body xmlns:html="http://a.ns">abc<html:p>123</html:p>def<html:p>456</html:p></html:body>'
      test.deepEqual '<html:body xmlns:html="http://a.ns">abc<html:p>123</html:p>def<html:p>456</html:p><html:p>789</html:p></html:body>', type.apply(sampleXML, [{p:[4], ei:'<html:p>789</html:p>'}])
      
      # Test deletes
      test.deepEqual '<body><p>123</p></body>', type.apply('<body><p>456</p><p>123</p></body>', [{p:[0], ed:'p'}])
      test.deepEqual '<body><p>456</p></body>', type.apply('<body><p>456</p><p>123</p></body>', [{p:[1], ed:'p'}])
      
      try
        type.apply('<body><p>456</p></body>', [{p:[-1], ed:'p'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Position invalid')
      
      try
        type.apply('<body><p>456</p></body>', [{p:[0], ed:'a'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Name of element to delete does not match')

      test.done()
      
    'Replacing elements works': (test) ->
      test.deepEqual '<body><bar>foo</bar></body>', type.apply('<body><p>456</p></body>', [{p:[0], ed:'p', ei:'<bar>foo</bar>'}])
      test.deepEqual '<body>123</body>', type.apply('<body><p>456</p></body>', [{p:[0], ed:'p', ei:'>123'}])
      test.deepEqual '<body>abc<p>123</p>def<bar>foo</bar>zzz</body>', type.apply('<body>abc<p>123</p>def<p>456</p>zzz</body>', [{p:[3], ed:'p', ei:'<bar>foo</bar>'}])
    
      try
        type.apply('<body><p>456</p></body>', [{p:[0], ed:'a', ei:'<bar>foo</bar>'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Name of element to replace does not match')
        
      try
        type.apply('<body><p>456</p></body>', [{p:[1], ed:'p', ei:'<bar>foo</bar>'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Position invalid, cannot replace element at pos 1')
    
      test.done()
      
    'Moving elements works': (test) ->
      test.deepEqual '<body><p>123</p><p>456</p></body>', type.apply('<body><p>456</p><p>123</p></body>', [{p:[1], em:0}])
      test.deepEqual '<body><p>123</p><p>456</p></body>', type.apply('<body><p>456</p><p>123</p></body>', [{p:[0], em:1}])
      test.deepEqual '<body><p>123</p><p>456</p></body>', type.apply('<body><p>123</p><p>456</p></body>', [{p:[0], em:0}])
      test.deepEqual '<body>abcdef<p>123</p><p>456</p>zzz</body>', type.apply('<body>abc<p>123</p>def<p>456</p>zzz</body>', [{p:[2], em:1}])
      test.deepEqual '<body>abcdefzzz<p>123</p><p>456</p></body>', type.apply('<body>abc<p>123</p>def<p>456</p>zzz</body>', [{p:[2], em:1}, {p:[4], em:2}])
      test.deepEqual '<body><p>123</p>abcdef<p>456</p>zzz</body>', type.apply('<body>abc<p>123</p>def<p>456</p>zzz</body>', [{p:[0], em:1}])
      test.deepEqual '<body>abcdef<p>456</p><p>123</p>zzz</body>', type.apply('<body>abc<p>123</p>def<p>456</p>zzz</body>', [{p:[1], em:3}])
      
      test.done()

    'Ops on deleted elements become noops': (test) ->
      test.deepEqual [], type.transform [{p:[1, 0], ti:'hi'}], [{p:[1], ed:'x'}], 'left'
      test.deepEqual [], type.transform [{p:[9],ti:"bite "}], [{p:[],ad:"agimble s",as:null}], 'right'
      test.done()
    
    'Ops on replaced elements become noops': (test) ->
      test.deepEqual [], type.transform [{p:[1, 0], ti:'hi'}], [{p:[1], ad:'x', as:'y'}], 'left'
      test.done()
    
    'If two inserts are simultaneous, the lefts insert will win': (test) ->
      test.deepEqual [{p:['i'], as:'a', ad:'b'}], type.transform [{p:['i'], as:'a'}], [{p:['i'], as:'b'}], 'left'
      test.deepEqual [], type.transform [{p:[1], as:'b'}], [{p:[1], as:'a'}], 'right'
      test.done()

    'parallel ops on different keys miss each other': (test) ->
      test.deepEqual [{p:['a'], as: 'x'}], type.transform [{p:['a'], as:'x'}], [{p:['b'], as:'z'}], 'left'
      test.deepEqual [{p:['a'], as: 'x'}], type.transform [{p:['a'], as:'x'}], [{p:['b'], ad:'z'}], 'left'
      test.deepEqual [{p:["in","he"],as:{}}], type.transform [{p:["in","he"],as:{}}], [{p:["and"],ad:{}}], 'right'
      test.deepEqual [{p:['x',0],ti:"his "}], type.transform [{p:['x',0],ti:"his "}], [{p:['y'],ad:0,as:1}], 'right'
      test.done()

    'replacement vs. deletion': (test) ->
      test.deepEqual [{p:[],as:{}}], type.transform [{p:[],ad:[''],as:{}}], [{p:[],ad:['']}], 'right'
      test.done()

    'replacement vs. replacement': (test) ->
      test.deepEqual [],                     type.transform [{p:[],ad:['']},{p:[],as:{}}], [{p:[],ad:['']},{p:[],as:null}], 'right'
      test.deepEqual [{p:[],ad:null,as:{}}], type.transform [{p:[],ad:['']},{p:[],as:{}}], [{p:[],ad:['']},{p:[],as:null}], 'left'
      test.deepEqual [],                     type.transform [{p:[],ad:[''],as:{}}], [{p:[],ad:[''],as:null}], 'right'
      test.deepEqual [{p:[],ad:null,as:{}}], type.transform [{p:[],ad:[''],as:{}}], [{p:[],ad:[''],as:null}], 'left'

      test.done()
    
    'An attempt to re-delete a key becomes a no-op': (test) ->
      test.deepEqual [], type.transform [{p:['k'], ad:'x'}], [{p:['k'], ad:'x'}], 'left'
      test.deepEqual [], type.transform [{p:['k'], ad:'x'}], [{p:['k'], ad:'x'}], 'right'
      test.done()

  attribute:
    'Apply sanity checks': (test) ->
      test.deepEqual '<body id="bla"/>', type.apply('<body></body>', [{p:['id'], as:'bla'}])
      test.deepEqual '<body id="bla"/>', type.apply('<body id="z"></body>', [{p:['id'], as:'bla'}])
      test.deepEqual '<body>abc<p id="bla">123</p>def<p>456</p>zzz</body>', type.apply('<body>abc<p>123</p>def<p>456</p>zzz</body>', [{p:[1,'id'], as:'bla'}])
      
      try
        type.apply('<body></body>', [{p:[0], as:'bla'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Attribute data not strings (it was [number,string])')
        
      try
        type.apply('<body></body>', [{p:['id'], as:1}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Attribute data not strings (it was [string,number])')
      
      test.deepEqual '<body/>', type.apply('<body id="z"></body>', [{p:['id'], ad:'z'}])
      test.deepEqual '<body>abc<p>123</p>def<p>456</p>zzz</body>', type.apply('<body>abc<p id="bla">123</p>def<p>456</p>zzz</body>', [{p:[1,'id'], ad:'bla'}])
      
      try
        type.apply('<body id="z"/>', [{p:[0], ad:'z'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Attribute data not strings (it was [number,string])')
        
      try
        type.apply('<body id="z"/>', [{p:['id'], ad:0}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Attribute data not strings (it was [string,number])')
        
      try
        type.apply('<body id="z"></body>', [{p:['id'], ad:'x'}])
        test.fail()
      catch error
        test.strictEqual(error.message, 'Value of attribute to delete does not match')
      
      test.done()

exports.node = genTests nativetype
exports.webclient = genTests require('../helpers/webclient').types.xml
