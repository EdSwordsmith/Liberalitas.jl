module Liberalitas
export classof, getslot, issubclass, Instance
export Class, Top, Object, JuliaType, PrimitiveClass, EntityClass, GenericFunction, MultiMethod
export @class, @method, @generic
include("boot.jl")

export sort_methods
export simple_method_combination, collect_method_combination, sum_method_combination, vcat_method_combination
include("dispatch.jl")

export make, add_method, print_object, compute_cpl, compatible_metaclasses, initialize, allocate_instance
include("generics.jl")

export SingleInheritanceClass, MultipleInheritanceClass
include("extras.jl")
end
