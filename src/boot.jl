# If a type implements this trait, then the type can act as the instance of an object
# Right now the required methods are classof and getslot
abstract type MaybeInstance end
struct IsInstance <: MaybeInstance end
struct IsNotInstance <: MaybeInstance end
MaybeInstance(::Type) = IsNotInstance()

classof(obj::T) where {T} = classof(MaybeInstance(T), obj)
classof(::IsInstance, obj) = error("classof not implemented for ", typeof(obj))
classof(::IsNotInstance, obj) = BuiltIn(typeof(obj))

getslot(obj::T, ::Symbol) where {T} = classof(MaybeInstance(T), obj)
getslot(::IsInstance, obj, ::Symbol) = error("getslot not implemented for ", typeof(obj))
getslot(::IsNotInstance, obj, ::Symbol) = error("getslot not available for ", typeof(obj))

# Need a parent abstract type to implement generic methods for Julia stuff like Base.show and getproperty
# Any type subtyping this will implement the MaybeInstance trait
abstract type Instance end
MaybeInstance(::Type{<:Instance}) = IsInstance()

function Base.getproperty(obj::Instance, slot::Symbol)
    @assert slot in getslot(classof(obj), :slots)
    getslot(obj, slot)
end

# Generic object struct, which can be used as an instance
# Similar to how Tiny CLOS uses the swindleobj struct to represent instances
mutable struct LibObj <: Instance
    class
    slots
end

classof(obj::LibObj) = getfield(obj, :class)
getslot(obj::LibObj, slot::Symbol) = getfield(getfield(obj, :slots), slot)

function Base.setproperty!(obj::LibObj, slot::Symbol, value)
    @assert slot in getslot(classof(obj), :slots)
    slots = (; getfield(obj, :slots)..., slot => value)
    setfield!(obj, :slots, slots)
end

# Support for builtin types
struct BuiltIn{T} <: Instance end
BuiltIn(T) = BuiltIn{T}()

classof(::BuiltIn) = PrimitiveClass
getslot(obj::BuiltIn, slot::Symbol) = getslot(obj, Val(slot))
getslot(::BuiltIn, ::Val{:dsupers}) = (JuliaType,)
getslot(obj::BuiltIn, ::Val{:cpl}) = (obj, JuliaType, Top)
getslot(::BuiltIn, ::Val{:slots}) = ()
getslot(::BuiltIn{T}, ::Val{:name}) where {T} = Symbol(T)

issubclass(::BuiltIn{T1}, ::BuiltIn{T2}) where {T1,T2} = T1 <: T2
issubclass(c1::Instance, c2::Instance) = c2 in c1.cpl
toclass(t::Type) = BuiltIn(t)
toclass(x) = x

# This struct is used to represent instances of generic functions
# TODO: better name for Entity struct
mutable struct Entity <: Instance
    class
    methods
    cache
    combination

    Entity(class, combination) = new(class, Dict{Tuple,Instance}(), Dict{Tuple, Any}(), combination)
end

classof(obj::Entity) = getfield(obj, :class)
getslot(obj::Entity, slot::Symbol) = getfield(obj, slot)

function Base.setproperty!(obj::Entity, slot::Symbol, value)
    @assert slot in getslot(classof(obj), :slots)
    setfield!(obj, slot, value)
end


# Bootstrap the Class object and set its class to itself
Class = LibObj(missing, (name=:Class, slots=(:name, :slots, :dsupers, :cpl)))
setfield!(Class, :class, Class)

make = function (class; slots...)
    if class == Class || class == EntityClass
        class_name = get(slots, :name, missing)
        class_slots = get(slots, :slots, ())
        class_dsupers = get(slots, :dsupers, ())
        instance = LibObj(class, missing)
        class_cpl = isempty(class_dsupers) ? (instance,) : (instance, class_dsupers[1].cpl...)
        setfield!(instance, :slots, (name=class_name, slots=class_slots, dsupers=class_dsupers, cpl=class_cpl))
        instance
    elseif class == MultiMethod
        types = get(slots, :types, missing)
        proc = get(slots, :proc, missing)
        qualifier = get(slots, :qualifier, missing)
        LibObj(class, (types=types, proc=proc, qualifier=qualifier))
    elseif class == GenericFunction
        Entity(class, get(slots, :combination, missing))
    end
end

add_method = function (gf, method)
    for types in keys(gf.cache)
        if compatible_args(types, method.types)
            delete!(gf.cache, types)
        end
    end
    gf.methods[(method.types, method.qualifier)] = method
end


macro class(head, slots=Expr(:tuple))
    class_slots = Expr(:tuple, map(QuoteNode, slots.args)...)
    explicit_metaclass = head.args[1] == :isa
    metaclass = explicit_metaclass ? head.args[3] : :Class
    class_head = explicit_metaclass ? head.args[2] : head
    class_name = class_head.args[1]

    class_supers = class_head.args[2:end]
    if isempty(class_supers) && class_name != :Top
        push!(class_supers, :Object)
    end
    supers = Expr(:tuple, class_supers...)

    esc(quote
        $class_name = make($metaclass, name=$(QuoteNode(class_name)), dsupers=$supers, slots=$class_slots)
    end)
end

macro generic(head)
    name = head isa Symbol ? head : head.args[1]
    combination = head isa Symbol ? :simple_method_combination : head.args[2]
    esc(:($name = make(GenericFunction, combination=$combination)))
end

macro method(form)
    # TODO: validate syntax?
    @assert form.head == :(=)
    head = form.args[1]
    body = form.args[2]
    args = head.args[2:end]

    arg_type(::Symbol) = :Top
    arg_type(arg::Expr) = arg.args[end]
    arg_name(arg::Symbol) = arg
    arg_name(arg::Expr) = length(arg.args) > 1 ? arg.args[1] : :_
    isparams(::Symbol) = false
    isparams(arg::Expr) = arg.head == :parameters
    isnotparams(arg) = !isparams(arg)

    generic = head.args[1] isa Symbol ? head.args[1] : head.args[1].args[1]
    qualifier = head.args[1] isa Symbol ? QuoteNode(:primary) : QuoteNode(head.args[1].args[2])

    required_args = filter(isnotparams, args)
    params = filter(isparams, args)
    types = Expr(:tuple, map(arg_type, required_args)...)
    names = Expr(:tuple, params..., :next, map(arg_name, required_args)...)
    proc = Expr(:function, names, body)

    esc(quote
        if !isdefined(@__MODULE__, $(QuoteNode(generic)))
            @generic $generic
        end

        let method = make(MultiMethod, types=map(toclass, $types), qualifier=$qualifier, proc=$proc)
            add_method($generic, method)
        end
    end)
end

# Declare the default classes of the object system
@class Top()
@class Object(Top)

# Set Class's dsupers and cpl
Class.dsupers = (Object,)
Class.cpl = (Class, Object.cpl...)

@class JuliaType(Top)
@class PrimitiveClass(Class) (name, slots, dsupers, cpl)

@class EntityClass(Class) (name, slots, dsupers, cpl)
@class GenericFunction() isa EntityClass (methods, cache, combination)
@class MultiMethod() (types, proc, qualifier)
