--!strict
local ValueWrapper = {}
ValueWrapper.__index = ValueWrapper

local ReplicatedStorage = game:WaitForChild("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")

local Classes = Modules:WaitForChild("Classes")
local Destructor = require(Classes:WaitForChild("Destructor"))

type Predicate<Value> = (value: Value) -> boolean

type ValueWrapperProperties<Value> = {
	_Destructor: Destructor.Destructor,
	_Destructing: BindableEvent,
	_Changed: BindableEvent,
	Value: Value,
	Changed: RBXScriptSignal,
	Predicates: {[string]: Predicate<Value>},
	Destructing: RBXScriptSignal
}

export type ValueWrapper<Value> = typeof(
	setmetatable(
		{} :: ValueWrapperProperties<Value>,
		ValueWrapper
	)
)

--[=[
	Returns a <strong>boolean</strong> indicating whether <code>Value</code> is a <strong>dictionary</strong> of <strong>functions</strong> indexed by <strong>strings</strong>.
]=]
local function IsDictionaryOfFunctionsIndexedByStrings(value: any): boolean
	if type(value) ~= "table" then
		return false
	end

	for key, value in value do
		if type(key) ~= "string" or type(value) ~= "function" then
			return false
		end
	end

	return true
end

function ValueWrapper.__tostring<Value>(self: ValueWrapper<Value>): string
	return tostring(self.Value)
end

--[=[
	Returns a <strong>boolean</strong> indicating whether <code><strong>self</strong>.Predicates</code> is a <strong>dictionary</strong> of <strong>functions</strong> returning <strong>true</strong>.
]=]
function ValueWrapper._Predicate<Value>(self: ValueWrapper<Value>, value: Value): boolean
	local pass = true

	for _, predicate in self.Predicates do
		local _, result = xpcall(predicate, function(message: string)
			warn(debug.traceback(message))
		end, value)

		task.spawn(assert, type(result) == "boolean", `Called method '{debug.info(2, "n")}' of ValueWrapper on {self} while property 'Predicates' is {self.Predicates} and not a dictionary of functions returning booleans.`)

		if result == false then
			pass = false

			break
		end
	end

	return pass
end

function ValueWrapper.IsValueWrapper(value: any): boolean
	return type(value) == "table" and getmetatable(value) == ValueWrapper
end

--[=[
	Returns a new <strong>ValueWrapper</strong> object with optional <code>Value</code> and <code>Predicates</code>.
]=]
function ValueWrapper.new<Value>(value: Value?, predicates: {[string]: Predicate<Value>}?): ValueWrapper<Value>
	assert(predicates == nil or IsDictionaryOfFunctionsIndexedByStrings(predicates), `Argument 'Predicates' to constructor 'new' of ValueWrapper is {predicates} and not nil or a dictionary of functions indexed by strings.`)

	local self = setmetatable({} :: ValueWrapperProperties<any>, ValueWrapper)

	self._Destructor = Destructor.new()

	self._Destructing = self._Destructor:Add(Instance.new("BindableEvent"))

	self._Destructor:Add(self._Destructing.Fire, self._Destructing)

	self._Changed = self._Destructor:Add(Instance.new("BindableEvent"))

	self.Value = value
	self.Changed = self._Changed.Event

	self.Predicates = predicates or {}

	self.Destructing = self._Destructing.Event

	return self
end

--[=[
	Destroys <code><strong>self</strong></code>.
]=]
function ValueWrapper.Destruct<Value>(self: ValueWrapper<Value>)
	self._Destructor:Destruct()
end

--[=[
	Sets the value of <code><strong>self</strong></code> to <code>Value</code> if <code>_BypassPredicates</code> is <strong>true</strong> or each <strong>function</strong> in <code><strong>self</strong>.Predicates</code> returns <strong>true</strong>.
]=]
function ValueWrapper.Set<Value>(self: ValueWrapper<Value>, value: Value, _bypassPredicates: boolean?)
	if value ~= self.Value and (_bypassPredicates or self:_Predicate(value)) then
		self.Value = value
		self._Changed:Fire(value)
	end
end

return ValueWrapper
