RFXLua
---

RFXLua is a collection of the most essential libraries - vectors, lines, math, etc - for game development in Lua.
It is largely out of active use, but may be expanded and refined over time. My primary motives are usability and effective memory management, mainly avoiding GC lag.

Struct.lua
---

Struct.lua is a simple, robust prototyping implementation optimized for frequent creation and discarding of instances.

By default it provides the following utilities:
>* (`structname(...)`) instantiation syntax
>* tiny stack implementation (*legacy feature from early memory management implementation*)
	>* `lib.stack()` returns a new stack instance
	>* `stack.push(v)` appends a new item to the top of the stack
	>* `stack.pop()` removes and returns the most recently added item
	>* `stack.clear()` removes all elements from the stack
	>* `stack.c()` returns stack count; more efficient than `#stack`
>* A linked list double-ended queue used in object pooling (see `structname.pool`)
	>* `lib.que()` returns a new dequeue instance, the same as a struct's pool
	>* `pool.push(v)` appends a new item to the back of the que, replacing the current last item
	>* `pool.pushFirst(v)` pushes a new item to the front of the que, replacing the current first item
	>* `pool.pop()` removes and returns the first item from the que (typically the oldest item, if added by `pool.push(v)`)
	>* `pool.popLast()` removes and returns the last item from the que
	>* `pool.peek()` returns the first item in the que without removing it
	>* `pool.peekLast()` returns the last item in the que without removing it
	>* `pool.clear()` clears all entries from the pool and recycles all linked list containers
	>* `#pool` returns the number of items in the pool (note: based only on push and pop operations. Manual linked list modification will not be accounted for correctly.)
	>* `for obj, val in pairs(pool) do ... end` obj, in this case, is the container table with members "prev", "next", and "val". Reliably iterates in order.
>* object disposal with recycling: instance:del()
>* properties: (`instance.var = val`) and (`val = instance.var`)
>* struct as instance index metamethod

In order to be as lightweight as possible, inheritance is not implemented.
When the returned lib is called, a fresh template is generated using the lib.new function
(which can also be called directly.)

It will apply the template on top of the existing values to the supplied table,
allowing declaration of a struct within the method call.
The struct declaration should include a method called "new."
This is the constructor method. The intended pattern is this:

```lua
newstruct = struct {
	new = function(static, this, param1, param2, etc)
		this.param1 = param1
		this.param2 = param2
		this.etc = etc
	end
}
```

The first two arguments are, in order:
>* The structure table itself, for access to static information ("static")
>* The new object table ("this")
The new table instance is automatically pulled from the object pool if one is available.
Therefore, garbage data may be left over from the old instance.
To automatically clean this data, simply set either of the following static values to true:

>* `struct.cleanOnConstruct = true`
>* `struct.cleanOnDispose = true`

*Note that the destructor can also be overridden by including a `struct.del(this)` function.*
*If included, it will be wrapped and called before the default destructor.*

Although it is not thread safe and requires extra thought, cleanOnConstruct
defers data removal so that an instance can technically be used after deletion.
This can be used to ensure that an instance is recycled cleanly after operation,
avoiding GC lag.

With the structure itself defined, defining methods is simple:

```lua
function newstruct.method(this, args)
	-- dostuff
end
```

These methods can be called both statically or from an instance,
so it may be wise to mark methods intended for static usage separately.
Additionally, the struct can have abstractions for accessing its variables,
called properties.
Functions added to the `structname.props` table will be called when
assignment or indexing of a variable with that name is attempted.

```lua
function newstruct.props.a(this, value)
	if value then
		-- write
		this.b = value
	else
		-- read
		return this.b
	end
end
```

The following methods are wrapped on declaration:
>* `struct.new`
>* `struct.del`
>* 
The following methods are overridden on declaration:
>* `struct.classmeta.__call`
>* `struct.meta.__index`
>* `struct.meta.__newindex`
>* `struct.meta.__close`

>* The metatable is set to struct.meta
>* struct.prototype and struct.meta.__proto are set to the struct prototype, if they are not otherwise occupied.

---

EXAMPLE: struct declaration and demonstration code

```lua
local struct = require("RFXLua.struct")
local structname = struct {
	staticCount = 0
	new = function(struct, this, i)
		this.val = i
		struct.staticCount = struct.staticCount + 1
	end,
	printI = function(this)
		print(this.val)
	end,
	printStatic = function()
		print("Hello, world!")
	end,
	props = {
		nextI = function(this, val)
			if val then
				this.val = val - 1
			else
				return this.val + 1
			end
		end
	},
	meta = {
		__add = function(a, b)
			return a.prototype(a.val + b.val)
		end
	}
}

local test = structname(4) -- construct an instance of "structname"
test:printI() -- call instance method
print(test.nextI) -- access a property
test.nextI = 3 -- write to a property
print(test.nextI)
print((test + test).val) -- call addition metamethod, creating a new temporary instance
	-- note that this instance will likely not be recycled correctly in this case. Alternatives and workarounds are advised.
test:del() -- recycle instance
```

Final note: in some cases it may be necessary to access the prototype from static methods.
The original convention is:

```lua
local structname = struct { ... }
function structname.doSomething()
	structname.foo = "bar"
end
```

However, if adding methods outside of the prototype declaration is unsatisfactory,
this works just as well:

```lua
local structname
structname = struct { ... }
```

Vec.lua
---

Vec.lua is a vector class library for game development. It is designed to be loaded like so:

```lua
local Vec = require("Vec")(VECTOR)
```

The function returned by `Vec` returns a local vector lib object, assigns the vector lib object to any variable arguments, and assigns the vector lib object to global context items to locations defined by any string arguments. This vector lib object can then be used to define new vector objects, like so:

```lua
local vec = Vec(0,0)
```

The new vector has an x component of 0 and a y component of 0. The local variable foo becomes the new vector object, and can now be used as such.
The vector library currently supports the following operations through metamethods:

>* (`+`) addition
>* (`-`) subtraction
>* (`*`) multiplication
>* (`/`) division
>* (`%`) modulus
>* (`^`) power *(this is done vie lua's core ^ operator, which may function differently depending on the implementation)*
>* (`..`) dot product
>* (`==`) equality check
>* (`>`/`<`) greater-than/less-than check
>* (`>=`/`<=`) greater-than-or-equal-to/less-than-or-equal-to check
>* (`tostring()`) `tostring` function usage

All the math operations return a new vector with the result, thus potentially impacting performance.
The following functions and properties are also supported:

>* `vec.type` returns "vector" (set)
>* `vec.a` returns the angle of the vector from the origin *(`math.atan2(vec.y,vec.x)`)*
>* `vec.l` returns the length of the vector *(can be slow when used repeatedly due to use of `math.sqrt()`)*
>* `vec.n` returns a unit vector of the same angle *(make suse of `vec.l`, beware!)*
>* `vec.max` returns the largest component of the vector *(uses `>`, so negative numbers are considered smaller)*
>* `vec.min` returns the smallest component of the vector *(uses `<`, so negative numbers are considered smaller)*
>* `vec.r` returns a vector with the components reversed
>* `vec.abs` returns a vector with absolute values of the components

>* `vec:dist(vec2)` returns the distance between the vectors
>* `vec:copy(dx,dy)` `vec:copy(dv)` copies vec, adding either the delta x and y or the delta vector.
>* `vec:dec(vec2)` garbageless shorthand for `vec = vec - vec2`
>* `vec:inc(vec2)` garbageless shorthand for `vec = vec + vec2`
>* `vec:mul(vec2)` garbageless shorthand for `vec = vec * vec2`
>* `vec:div(vec2)` garbageless shorthand for `vec = vec / vec2`
>* `vec:mod(vec2)` garbageless shorthand for `vec = vec % vec2`.
>* `vec:set(vec2)` copies the values of vec2 into vec
>* `vec:unpack()` returns the x and y components of the vector

>* `vec:del()` garbage recycling for vec; pushes vec onto the reuse stack for future vectors to save RAM. Returns the deleted vector, which is safe to use UNTIL another vector is created.

A relatively recent feature, Volatiles, adds the ability to automatically queue vectors for recycling at a controlled time, thus mitigating the garbage pileup from struct math.
(*`_VECTOR` refers to the library object itself*)

>* `_VECTOR.volMode` A boolean setting. Default false. If true, all vectors are automatically marked as 'volatile' upon creation.
>* `_VECTOR.volMath` A boolean setting. Default false. If true, all results of vector math are marked as 'volatile' upon creation.
>* `_VECTOR.crunch()` Recycles all volatile vectors into the delqueue.
>* `_VECTOR.stepCrunch()` Slower per item than crunch(), but deletes only one item at a time. Should be safe for coroutines.
>* `vec:vol()` adds vec to the volatile queue.
>* `vec:unVol()` Removes vec from volatile queue. Searches from end to beginning, thus making it faster the fewer volatiles are created after vec. Will search entire queue if vec is not volatile, but will not cause any further problems.
>* `vec:QUVol()` Only use if you're certain no volatile vectors have been created since vec. Will simply pop the most recent item out of volatiles. Will do nothing if top item is not vec. (*i.e. if vec is not a volatile, or is not the last volatile created*)

An example usage of volatility:
(note: for this application, I would normally recommend use of garbageless functions rather than volatility)

```lua
local Vec = require("Vec")()
local pos,vel,grav = Vec(0,0),Vec(0,0),Vec(0,9.4)
Vec.volMath = true

local intertime = 0.01
local last

function update(dt)
	vel = (vel:del()+grav*dt):QUVol()
	pos = (pos:del()+vel*dt):QUVol()
	last = os.clock()

	while os.clock()-last<intertime do
		Vec.stepCrunch()
	end
end
```

In this example, assuming "update" is called every frame with a delta time argument in seconds (as in such platforms as LOVE), the object represented by "pos" would accelerate at 9.4 "meters" per second, updating both velocity and position. The previous versions of these vectors are deleted, and the garbage generated by mathematics is crunched at a comfortable rate in the time between updates - a hundredth of a second, roughly, as defined by "intertime."

Do still note that this particular case could be accomplished via use of garbageless functions with ease, making it far more efficient, but that such optimization is not always feasible or convenient - i.e. in the case of complex or staged math, or when the result is a separate item.

Rec.lua
---

Rec.lua is a rectangle class library which functions very similarly to Vec.lua, and in fact requires Vec.lua to work. Upon load, it will attempt to load Vec from multiple sources, or use it if there's already a global \_VECTOR variable defined.
Rec.lua is loaded the same as Vec.lua

The constructor is also similar:

```lua
local rec = Rec(0,0,10,10)
```

This creates an axis-aligned rectangle object with its top left corner (bottom left if you're not using inverted y coords) at 0,0 and a width and height of 10 and 10.
These components can be accessed as `rect.x`, `rect.y`, `rect.w`, and `rect.h` respectively.

Rectangle objects support the following properties, which can be both read and written, having operations for both:

>* `rec.type` returns "rectangle" (set)
>* `rec.l` the left side of the rectangle - returns x, sets x
>* `rec.r` the right side of the rectangle - returns x + w, sets x (with offset of w)
>* `rec.t` the top side of the rectangle (in inv y) - returns y, sets y
>* `rec.b` the bottom side of the rectangle (in inv y) - returns y + h, sets y (with offset of h)
>* `rec.mx` the middle x coordinate of the rectangle - returns x + w/2, sets x (with offset of w/2)
>* `rec.my` the middle y coordinate of the rectangle - returns y + h/2, sets y (with offset of h/2)
>* `rec.pos` the top left vector of the rectangle (in inv y)
>* `rec.pos1` the top left vector of the rectangle (in inv y)
>* `rec.pos2` the top right vector of the rectangle (in inv y)
>* `rec.pos3` the bottom right vector of the rectangle (in inv y)
>* `rec.pos4` the bottom left vector of the rectangle (in inv y)
>* `rec.pos5` the middle vector of the rectangle
>* `rec.dims` the dimensions of the rectangle in vector form

*Note: the 'pos' components should support slope directions, though it will result in some duplicates. For non duplicate positions, see sPos*
The following methods are, of course, read-only:

>* `rec:intersect(rec2)` AABB true/false intersection check
>* `rec:relate(rec2)` AABB distances - all negative for intersection, returns: left, right, up, down
>* `rec:fullIntersect(rec2)` returns true/false intersection and results from relate
>* `rec:intersection(rec2)` *should* return a rectangle representing the intersected area between the two rectangles.
>* `rec:expelDir(rec2)` returns direction for AABB expulsion - 1,2,3 or 4 for left, right, up, and down respectively.
>* `rec:expel(rec2)` pushes rec out of rec2 in basic AABB manner (nearest side expulsion)
>* `rec:fit(rec2, true)` trims rec to fit inside rec2 - if second arg is true, will return a *copy* of rec rather than change the original
>* `rec:copy(dx,dy,dw,dh,mod)` copies rec. Will apply deltas if given, will copy unofficial values into `mod` if given a table, and will use the `mod` table rather than create or recycle a new one.
>* `rec:multiply(val)` multiplies all values in rec by val, returns a new rectangle with the result.
>* `for v in rec:iter(rec2)` iterates rec2 through rec in "stamp" fashion. Developed for use in grid/list-style menus. V is the rectangle representing the current space.
>* `rec:sPos(i)` returns corner vector `i` with slope support - i being an integer from 1 to 3
>* `rec:sPosList()` returns a list of the corner vectors with slope support
>* `rec:aPos(i)` returns the corner vector `i` with slope *and* basic support
>* `rec:corner(i)` returns the `i`th corner of the rectangle without slope support.
>* `rec:corners()` returns a list of the corners of the rectangle without slope support.
>* `rec:SATIntersect(other)` returns whether or not the two rectangles are intersecting using the Separating Axis Theorem.
>* `rec:SATNearest(other,getDelta,getImpact)` returns basic information for SAT physics between slopes: isIntersecting, nearestSideIndex, nearestPointIndex, nearestDistance, Delta/Impact, Impact/nil (the last two dependant on the given arguments)
>* `rec:SATExpel(other,getDelta)` expels rec from other with slope and basic support. If getDelta is true, returns delta of SATNearest.
>* `rec:regressB(vec)` regresses the given position - returns the integer index of the position on that row.
>* `rec:regress(rec2,vec)` regresses the given position, using the rectangle to define cell size.
>* `rec:unpack()` returns the top left x, top left y, width, and height of the box.

>* `rec:del()` recycles rec in similar fashion to the Vec library

The library is designed to natively support basic slopes for tiles, considering the component `rec.dir` - an enum with the four possible states of `"tl"`, `"tr"`, `"br"`, and `"bl"` - to be generally reserved and reset after recycling. However, it cannot be set in the constructor without a properties table. An example of both options:

```lua
local A = rec(10,20,30,40,{dir = "tl"}) -- A top-left facing slope.
local B = rec(10,20,30,40) -- A basic rectangle...
B.dir = "tl" -- ...with a top-left facing slope.
```

Both are roughly equivalent, though the first form will create a new table for every slope, while the second will attempt to make use of the recycling cache.

Rec.lua can also integrate Line.lua for some added features. It will automatically require/load Line if available; however, it is also possible to manually load Line.lua later:

>* `rec.loadLine(_LINE)` the library object or any returned rectangle contain this function.

This unlocks the following function:

>* `rec.slope` returns a line representation of a slope, or nil if it is not a slope.

Line.lua
---

Line.lua is a line class library designed in the fashion of Vec and Rec. It requires Vec to work, the same way Rec does. Line is designed to provide basic utilities for line segments, such as intersection, extension, extracting slopes, rotation, etc.

It is instantiated more or less as standard:

```lua
local line = Line(0,0,10,10)
local line = Line(Vec(0,0),Vec(10,10))
```

Either of these methods will produce a line segment from (0,0) to (10,10)
The components of the line are A and B, respectively.

The line supports the following properties, similarly to the rectangle:

>* `line.type` returns "line" (set)
>* `line.x` returns the minimum x coordinate of the line (set)
>* `line.x1` alias of x
>* `line.y` returns the minimum y coordinate of the line (set)
>* `line.y1` alias of y
>* `line.x2` returns the maximum x coordinate of the line (set)
>* `line.y2` returns the maximum y coordinate of the line (set)
>* `line.l` returns the leftmost vector of the line (set)
>* `line.r` returns the rightmost vector of the line (set)
>* `line.u` returns the uppermost vector of the line (set)
>* `line.d` returns the bottommost vector of the line (set)
>* `line.dx` returns the width of the line (b-a, thus negative if B is left of A) (shifts b)
>* `line.dy` returns the height of the line (b-a, thus negative if B is above A) (shifts b)
>* `line.m` returns the slope of the line, calculated sensibly (read only)
>* `line.yInt` returns the y intercept of the line (moves line)
>* `line.mx` returns the middle x coordinate of the line (moves line)
>* `line.my` returns the middle y coordinate of the line (moves line)
>* `line.mid` returns a vector for the middle of the line (moves line)
>* `line.angle` returns the angle from A to B (`math.atan2(dy,dx)`) (read only)
>* `line.length` returns the distance from A to B (moves B)

The following methods are also supported:

>* `line:solveY(x)` returns the y value for the given x
>* `line:solveX(y)` returns the x value for the given y
>* `line:hasX(x)` returns true if the line extends through (or ends at) the given x
>* `line:hasY(y)` returns true if the line extends through (or ends at) the given y
>* `line:hasPoint(x,y)` returns true if the line includes or ends at the given coordinates
>* `line:isVert()` returns true if the line is vertical
>* `line:isHoriz()` returns true if the line is horizontal
>* `line:parallel(line2)` returns true if the lines' slopes are equal
>* `line:intersectX(line2)` Apparently returns the x coordinate of intersection *if* there is a proper intersection; I have no memory, TODO.
>* `line:intersect(line2)` returns true if intersecting, then x and y of intersection.
>* `line:normal(dir,dist)` returns a right normal with a distance of one by default. If dir is 'l', will return a left normal. If dist is supplied, will use that.
>* `line:mir(x,y)` `line:mir(vec)` reflects the coordinates about the line. Returns type in kind with input.
>* `line:perpA()` returns a perpendicular line intersecting on A.
>* `line:perpB()` returns a perpendicular line intersecting on B.
>* `line:perpM()` returns a perpendicular line intersecting in the middle.
>* `line:projVec(v,getVec)` projects the given vector onto the line, returns distance and, if getVec is true, the vector of the projected location.
>* `line:projNormA(v,getVec,left)` projects onto the right normal of the line (at line.a) by default, left normal if left is true.
>* `line:projNormB(v,getVec,left)` projects onto the right normal of the line (at line.b) by default, left normal if left is true.
>* `line:projNormM(v,getVec,left)` projects onto the right normal of the line (at line.mid) by default, left normal if left is true.
>* `line:solveDist(v)` solves for the point at a distance of `v` along the line, returns the vector location.
>* `line:solveNormADist(v,left)` solves for the point at a distance of `v` along the A normal of the line - right by default, left when given arg.
>* `line:solveNormBDist(v,left)` solves for the point at a distance of `v` along the B normal of the line - right by default, left when given arg.
>* `line:solveNormMDist(v,left)` solves for the point at a distance of `v` along the middle normal of the line - right by default, left when given arg.
>* `line:SATPoint(v,left)` returns true if the sent vector is behind the line (negative on right normal, unless 'left' is true) and the distance on the projection.
>* `line:SATPoints(points,left)` returns true if the minimum point is behind the line, then the minimum index and value. `points` should be an array of vectors.
>* `line:SATPointsRec(rectangle,left)` returns SAT data of a rectangle's points. Returns intersecting, nearestPointIndex, nearestDistance.
>* `line:unpack()` returns ax, ay, bx, by.
>* `line.fromRec(rec)` returns sides of a rectangle - top, right, bottom, left - as lines.
>* `line.fromRecI(rec,i)` returns the `i`th side of a rectangle as a line.

>* `line:del()` recycles the line as above.

Poly.lua
---

Poly.lua is a polygon class library designed in the fashion of Vec and Line. It requires Vec and Line to work, in the same fashion as Line and Rec. Poly is designed to provide basic utilities for general shapes, such as intersection, combination, subtraction, rotation, and even some raycasting utilities.
It should be noted that polygon is designed primarily for 2d convex polygons, though it will include functions for decomposing concave 2d polygons.
Complex or composite polygons, however - i.e. those with holes punched in the middle - are unlikely to be well-supported.

It is instantiated more or less as standard:

```lua
local poly = Poly(0,0,10,10,0,10)
local poly = Line(Vec(0,0),Vec(10,10),Vec(0,10))
```

Either of these methods will produce a right 45-degree triangle with leg lengths of 10.

Warning: Poly.lua is entirely new and still WIP. Precise documentation will not be included until a baseline functionality is achieved - however, the library will be accessible and will almost always at least compile during this time, though nothing is guaranteed.

The polygon supports the following properties, similarly to the rectangle:

>* `poly.type` returns "polygon" (set)
>* `poly.x` returns the minimum x coordinate of the polygon (set)
>* `poly.x1` alias of x
>* `poly.y` returns the minimum y coordinate of the polygon (set)
>* `poly.y1` alias of y
>* `poly.x2` returns the maximum x coordinate of the polygon (set)
>* `poly.y2` returns the maximum y coordinate of the polygon (set)

The following methods are also supported:

~~>* `poly:order()` sorts the vertices in clockwise order for convex polygons.~~
> badly broken, working on a fix.
>* `poly:add(...)` Adds a vertex (or vertices) to the polygon - identical behavior to construction.
>* `poly:rem(i)` Removes a vertex from the polygon and returns it; without an index, removes last.

>* `poly:del()` recycles the polygon as above.

OLoad.lua
---

OLoad.lua is a super simple function for creating function overloads. It's not the best in any regards, but it's there.
Usage is as follows:

```lua
local overLoad = require("OLoad")

-- create an overloadable function:
local overLoadedFunction = overLoad(
	-- a function overload
	function(a,b,c)
		return "number","string","table"
	end,
	-- the arguments for the previous overload
	{"number","string","table"},
	-- repeat for every initial overload
)

-- add a version to an overloaded function:
overLoadedFunction:add(
	function(a,b,c)
		return "string", "table", "number"
	end,
	{"string","table","number"}
	-- 'add' can handle multiple functions, simply repeat this pattern for each.
)

-- add a default version to the overloaded function:
overLoadedFunction:add(
	function(...)
		local out = {}
		for i,v in ipairs({...}) do
			out[i] = type(v)
		end
		return unpack(out)
	end
)

-- execute an overloaded function:
print(
	overLoadedFunction(1,"str",{}) -- calls the correct version of the function for the given arg types
) -- prints "number	string	table"
```
