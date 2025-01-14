-- Usage:
-- This library is largely a static template generator.
-- By default it provides the following utilities:
	-- structname(...) instantiation syntax
	-- tiny stack implementation (legacy feature from early memory management implementation)
		-- lib.stack() -- returns a new stack instance
		-- stack.push(v)
		-- stack.pop()
		-- stack.clear()
		-- stack.c() -- stack count, more efficient than #stack
	-- queue-based object pooling (see structname.pool)
		-- lib.que() -- returns a new dequeue instance, the same as a struct's pool
		-- pool.push(v)
		-- pool.pushFirst(v)
		-- pool.pop()
		-- pool.popLast()
		-- pool.peek()
		-- pool.peekLast()
		-- pool.clear()
		-- #pool
		-- for obj, val in pairs(pool) do ... end -- obj, in this case, is the container table with members "prev", "next", and "val". Reliably iterates in order.
	-- object disposal with recycling: instance:del()
	-- properties (instance.var = val) and (val = instance.var)
	-- struct as instance index metamethod
-- In order to be as lightweight as possible, inheritance is not implemented.
-- When the returned lib is called, a fresh template is generated using the lib.new function
-- (which can also be called directly.)
-- It will apply the template on top of the existing values to the supplied table,
-- allowing declaration of a struct within the method call.
-- The struct declaration should include a method called "new."
-- This is the constructor method. The intended pattern is this:

-- newstruct = struct {
	-- new = function(static, this, param1, param2, etc)
		-- this.param1 = param1
		-- this.param2 = param2
		-- this.etc = etc
	-- end
-- }

-- The first two arguments are, in order:
	-- The structure table itself, for access to static information ("static")
	-- The new object table ("this")
-- The new table instance is automatically pulled from the object pool if one is available.
-- Therefore, garbage data may be left over from the old instance.
-- To automatically clean this data, simply set either of the following static values to true:
	-- struct.cleanOnConstruct = true
	-- struct.cleanOnDispose = true
-- Note that the destructor can also be overridden by including a struct.del(this) function.
-- If included, it will be wrapped and called before the default destructor.
-- Although it is not thread safe and requires extra thought, cleanOnConstruct
-- defers data removal so that an instance can technically be used after deletion.
-- This can be used to ensure that an instance is recycled cleanly after operation,
-- avoiding GC lag.

-- With the structure itself defined, defining methods is simple:
	-- function newstruct.method(this, args)
			-- dostuff
	-- end
-- These methods can be called both statically or from an instance,
-- so it may be wise to mark methods intended for static usage separately.
-- Additionally, the struct can have abstractions for accessing its variables,
-- called properties.
-- Functions added to the structname.props table will be called when
-- assignment or indexing of a variable with that name is attempted.

-- function newstruct.props.a(this, value)
	-- if value then
		-- -- write
		-- this.b = value
	-- else
		-- -- read
		-- return this.b
	-- end
-- end

-- The following methods are wrapped on declaration:
-- struct.new
-- struct.del
-- The following methods are overridden on declaration:
-- struct.classmeta.__call
-- struct.meta.__index
-- struct.meta.__newindex
-- struct.meta.__close
-- The metatable is set to struct.meta
-- struct.prototype and struct.meta.__proto are set to the struct prototype,
-- if they are not otherwise occupied.

-- ==========================================

-- EXAMPLE: struct declaration and demonstration code

-- local struct = require("RFXLua.struct")
-- local structname = struct {
-- 	staticCount = 0
-- 	new = function(struct, this, i)
-- 		this.val = i
-- 		struct.staticCount = struct.staticCount + 1
-- 	end,
-- 	printI = function(this)
-- 		print(this.val)
-- 	end,
-- 	printStatic = function()
-- 		print("Hello, world!")
-- 	end,
-- 	props = {
-- 		nextI = function(this, val)
-- 			if val then
-- 				this.val = val - 1
-- 			else
-- 				return this.val + 1
-- 			end
-- 		end
-- 	},
-- 	meta = {
-- 		__add = function(a, b)
-- 			return a.prototype(a.val + b.val)
-- 		end
-- 	}
-- }
-- local test = structname(4)
-- test:printI()
-- print(test.nextI)
-- print((test + test).val)
-- test:del()

-- Final note: in some cases it may be necessary to access the prototype from static methods.
-- The original convention is:

-- local structname = struct { ... }
-- function structname.doSomething()
-- 	structname.foo = "bar"
-- end

-- However, if adding methods outside of the prototype declaration is unsatisfactory,
-- this works just as well:

-- local structname
-- structname = struct { ... }

-- ==========================================

-- Le code

local lib = {}

local type, pairs = type, pairs
local rawset, rawget = rawset, rawget
local setmetatable = setmetatable

-- Tiny array-backed stack
local function stack()
	local stack = {}
	local c = 0
	function stack.push(v)
		c = c + 1
		stack[c] = v
		return v
	end
	function stack.pop()
		if c > 0 then
			local ret = stack[c]
			stack[c] = nil
			c = c - 1
			return ret
		end
	end
	function stack.clear()
		for i = c, 1, -1 do
			stack[i] = nil
		end
		c = 0
	end
	function stack.c()
		return c
	end
	return stack
end
lib.stack = stack -- Accessible to users, should they wish.

-- Cruder queue used for memory management
local function rawque()
	local que = {}
	local c = 0
	function que.push(v)
		if que.last then
			que.last.next = v
			v.prev = que.last
			que.last = v
		else
			que.first = v
			que.last = v
			v.prev = nil
			v.next = nil
		end
		c = c + 1
	end
	function que.peek()
		return not not que.first
	end
	function que.pop()
		local ret = que.first
		if ret then
			que.first = ret.next
			if not que.first then
				que.last = nil
			end
			c = c - 1
		else
			ret = {}
		end
		return ret
	end
	return que
end
-- Tiny doubly linked list dequeue
-- Unspecified pushes to end, pops from start
local function que()
	local que = {}
	local c = 0
	local pool = rawque()
	que.pool = pool
	function que.push(v)
		local t = pool.pop()
		t.prev = nil
		t.next = nil
		t.val = v
		if que.last then
			que.last.next = t
			t.prev = que.last
			que.last = t
		else
			que.first = t
			que.last = t
		end
		c = c + 1
		return v
	end
	function que.pushFirst(v)
		local t = pool.pop()
		t.prev = nil
		t.next = nil
		t.val = v
		if que.first then
			que.first.prev = t
			t.next = que.first
			que.first = t
		else
			que.first = t
			que.last = t
		end
		c = c + 1
		return v
	end
	function que.pop()
		local ret = que.first
		if ret then
			if ret.next then
				ret.next.prev = nil
				que.first = ret.next
			else
				que.first = nil
				que.last = nil
			end
			c = c - 1
			pool.push(ret)
			return ret.val
		end
	end
	function que.popLast()
		local ret = que.last
		if ret then
			if ret.prev then
				ret.prev.next = nil
				que.last = ret.prev
			else
				que.first = nil
				que.last = nil
			end
			c = c - 1
			pool.push(ret)
			return ret.val
		end
	end
	function que.peek()
		return que.first and que.first.val
	end
	function que.peekLast()
		return que.last and que.last.val
	end
	function que.clear()
		local v = que.first
		if v then
			local nextv
			repeat
				nextv = v.next
				pool.push(v)
				v = nextv
			until not v
		end
		que.first = nil
		que.last = nil
		que.c = 0
		return que
	end

	local function next(t, state)
		if state then
			return state.next, (state.next and state.next.val)
		else
			return t.first, t.first.val
		end
	end
	return setmetatable(que, {
		__len = function(t)
			return c
		end,
		__pairs = function(t)
			return next, que
		end
	})
end
lib.que = que -- Accessible to users, should they wish.

-- ==========================================

-- Cleanup function used on recycled instance data
local function cleanup(t, full)
	if t then
		setmetatable(t, nil)
		if full then
			for k,v in pairs(t) do
				t[k] = nil
			end
		end
	end
	return t
end

-- Heavy lifter; constructs an entire struct prototype and returns it
function lib.new(t)
	local struct = t or {}

	-- Ensure default components
	struct.classmeta = struct.classmeta or {}
	struct.meta = struct.meta or {}
	struct.props = struct.props or {}
	struct.pool = struct.pool or que()
	struct.prototype = struct.prototype or struct
	struct.meta.__proto = struct.meta.__proto or struct
	-- Localize access for performance
	local classmeta = struct.classmeta
	local meta = struct.meta
	local props = struct.props
	local pool = struct.pool

	-- Constructor wrapping
	local constructor = struct.new
	function struct.new(...)
		-- Object pool recycling when possible
		local ret = cleanup(pool.pop(), struct.cleanOnConstruct) or {}
		constructor(struct, ret, ...)
		return setmetatable(ret, meta)
	end

	-- Enable class() constructor syntax
	function classmeta.__call(struct, ...)
		return struct.new(...)
	end

	-- Recycles an instance to its object pool.
	local destructor = struct.del
	function struct.del(this)
		if destructor then destructor(this) end
		if struct.cleanOnDispose then
			cleanup(this, true)
		end
		pool.push(this)
		return this
	end

	-- Instance __index override. Reads from struct values first,
	-- then invokes dynamic properties if nothing is found.
	function meta.__index(this, k)
		local ret = struct[k]
		if ret then return ret end
		ret = props[k]
		if ret then
			return ret(this)
		end
		return nil
	end
	-- Instance __newindex override. Intercepts assignments to invoke dynamic properties first,
	-- otherwise assigns the value to the instance as expected.
	function meta.__newindex(this, k, v)
		local tgt = props[k]
		if tgt then
			return tgt(this, v)
		end
		return rawset(this, k, v)
	end
	-- Memory management feature
	-- Lua 5.4+
	function meta.__close(this)
		this:del()
	end

	return setmetatable(struct, classmeta)
end

return setmetatable(lib, {__call = function(this, ...) return lib.new(...) end})