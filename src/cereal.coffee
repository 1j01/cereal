
isPrimitive = (obj)-> obj isnt Object obj

randomString = (length)-> Math.round((Math.pow(36, length + 1) - Math.random() * Math.pow(36, length))).toString(36).slice(1)

undef  = 0
nu     = 1
prim   = 2
object = 3
array  = 4
ref    = 5
unserialisable = 9

unserialisableReferences = {}


class Unserialisable
	clientID = randomString 30
	counter = 0
	@getID = -> "#{clientID}-#{++counter}"
	constructor: (@id)->
	toString: -> "(unserialisable ##{@id})"

generateEncodeWork = (obj, target)->
	names = Object.keys(obj)
	for name in names
		target[name] = []
		[target[name], obj[name]]

jsonify = (obj)->
	root = []
	seen = []
	seenIdx = 0
	worklist = [[root, obj]]
	
	while worklist.length > 0
		item = worklist.shift()
		target = item[0]
		obj = item[1]
		if obj is undefined
			target[0] = undef
		else if obj is null
			target[0] = nu
		else if typeof obj is 'function'
			id = Unserialisable.getID()
			unserialisableReferences[id] = obj
			target[0] = unserialisable
			target[1] = id
		else if obj instanceof Unserialisable
			target[0] = unserialisable
			target[1] = obj.id
		else if isPrimitive obj
			target[0] = prim
			target[1] = obj
		else
			refIdx = seen.lastIndexOf obj
			if refIdx is -1
				refIdx = seenIdx
				seenIdx += 1
				seen[refIdx] = obj # store original obj, not result of obj.cerealise
				target[1] = refIdx
				target[2] = {} # always use an object to placate JSON itself
				if 'cerealise' of obj and typeof obj.cerealise is 'function'
					obj = obj.cerealise()
				
				if Object::toString.apply(obj) is '[object Array]'
					target[0] = array
				else
					target[0] = object
				
				worklist = (generateEncodeWork obj, target[2]).concat(worklist)
			else
				target[0] = ref
				target[1] = refIdx
	
	root

generateDecodeWork = (obj, target)->
	names = Object.keys(obj)
	for name in names
		obj[name].unshift(name)
		obj[name].unshift(target)
		obj[name]

dejsonify = (obj)->
	root = {}
	seen = []
	worklist = [obj]
	obj.unshift('value')
	obj.unshift(root)
	
	while worklist.length > 0
		item = worklist.shift()
		target = item[0]
		field = item[1]
		switch item[2]
			when undef
				target[field] = undefined
			when nu
				target[field] = null
			when prim
				target[field] = item[3]
			when object
				target[field] = {}
				seen[item[3]] = target[field]
				worklist = (generateDecodeWork item[4], target[field]).concat(worklist)
			when array
				target[field] = []
				seen[item[3]] = target[field]
				worklist = (generateDecodeWork item[4], target[field]).concat(worklist)
			when ref
				target[field] = seen[item[3]]
				if target[field] is undefined
					throw new Error "Decoding error: referenced object not found"
			when unserialisable
				target[field] = unserialisableReferences[item[3]]
				# if target[field] is undefined
				# 	throw new Error "Decoding error: referenced unserialisable object (function) not found"
				# console.log "got unserialisable", item
				target[field] ?= new Unserialisable item[3]
				# console.log "unserialisable", target[field], target[field] instanceof Unserialisable
			else
				throw new Error "Decoding error: unhandled object type code #{item[2]}"
	
	root.value

@Cereal =
	stringify: (obj)-> JSON.stringify jsonify obj
	parse: (str)-> dejsonify JSON.parse str
	UnserialisableFunction: Unserialisable

module?.exports = @Cereal
