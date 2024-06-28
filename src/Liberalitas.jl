module Liberalitas
export classof, getslot, issubclass, toclass
export compatible_args, args_more_specific, findclass, apply_methods
export Instance, LibObj, BuiltIn, Entity, EffectiveMethod
export Class, Top, Object, JuliaType, PrimitiveClass, EntityClass, GenericFunction, MultiMethod, SingleInheritanceClass, MultipleInheritanceClass
export make, add_method, print_object, compute_cpl, compatible_metaclasses, initialize, allocate_instance
export @class, @method, @generic

include("boot.jl")
include("generics.jl")
include("extras.jl")
end
