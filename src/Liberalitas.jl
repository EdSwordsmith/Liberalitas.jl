module Liberalitas
export classof, getslot, issubclass, toclass
export Instance, LibObj, BuiltIn, Entity, EffectiveMethod
export Class, Top, Object, JuliaType, PrimitiveClass, EntityClass, GenericFunction, MultiMethod
export @class, @method, @generic
include("boot.jl")

export compatible_args, args_more_specific, findclass, apply_methods
include("dispatch.jl")

export make, add_method, print_object, compute_cpl, compatible_metaclasses, initialize, allocate_instance
include("generics.jl")

export SingleInheritanceClass, MultipleInheritanceClass
include("extras.jl")
end
