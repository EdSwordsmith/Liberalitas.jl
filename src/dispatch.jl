function compatible_args(classes1, classes2)
    if length(classes1) != length(classes2)
        return false
    end

    pairs = zip(classes1, classes2)
    all((pair) -> issubclass(pair[begin], pair[end]), pairs)
end

function args_more_specific(m1_classes::Tuple, m2_classes::Tuple, provided_classes::Tuple)
    if m1_classes[1] == m2_classes[1]
        args_more_specific(m1_classes[2:end], m2_classes[2:end], provided_classes[2:end])
    else
        idx1 = findclass(provided_classes[1], m1_classes[1])
        idx2 = findclass(provided_classes[1], m2_classes[1])
        return idx1 < idx2
    end
end

function findclass(provided_class, arg_class)
    for (k, v) in enumerate(provided_class.cpl)
        if v == arg_class
            return k
        end
    end
end

function sort_methods(args_types, methods)
    sort(methods, lt=(x, y) -> args_more_specific(x, y, args_types), by=method -> method.types)
end

function apply_methods(methods, args, kwargs)
    next = () -> apply_methods(methods[2:end], args, kwargs)
    # TODO: handle no applicable method
    getslot(methods[1], :proc)(next, args...; kwargs...)
end

# Effective method for simple method combination (around + primary methods)
struct SimpleEffectiveMethod
    methods
end

(em::SimpleEffectiveMethod)(args, kwargs) = apply_methods(em.methods, args, kwargs)

function simple_method_combination(args_types, methods)
    @assert !isempty(methods) "There is no applicable method for the generic function when called with these arguments."
    around_methods = sort_methods(args_types, filter(method -> method.qualifier == :around, methods))
    primary_methods = sort_methods(args_types, filter(method -> method.qualifier == :primary, methods))
    @assert !isempty(primary_methods) "There is no primary method for the generic function when called with these arguments."
    SimpleEffectiveMethod([around_methods; primary_methods])
end

# Operator method combinations
struct OperatorEffectiveMethod
    operator
    methods
end

(em::OperatorEffectiveMethod)(args, kwargs) =
    let next = () -> error("next cannot be called in operator method combinations.")
        em.operator(map((m) -> m.proc(next, args...; kwargs...), em.methods))
    end

function collect_method_combination(args_types, methods)
    primary_methods = sort_methods(args_types, filter(method -> method.qualifier == :primary, methods))
    OperatorEffectiveMethod(collect, primary_methods)
end

function sum_method_combination(args_types, methods)
    primary_methods = sort_methods(args_types, filter(method -> method.qualifier == :primary, methods))
    OperatorEffectiveMethod(sum, primary_methods)
end

function vcat_method_combination(args_types, methods)
    primary_methods = sort_methods(args_types, filter(method -> method.qualifier == :primary, methods))
    OperatorEffectiveMethod((results) -> vcat(results...), primary_methods)
end

# Generic function call
function (e::Entity)(args...; kwargs...)
    args_types = map(classof, args)
    effective_method = if haskey(e.cache, args_types)
        e.cache[args_types]
    else
        methods = collect(values(e.methods))
        compatible_methods = filter(method -> compatible_args(args_types, method.types), methods)
        e.cache[args_types] = e.combination(args_types, compatible_methods)
    end

    effective_method(args, kwargs)
end
