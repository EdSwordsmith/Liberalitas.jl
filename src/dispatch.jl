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

function apply_methods(methods::Vector{Instance}, args, kwargs)
    next = () -> apply_methods(methods[2:end], args, kwargs)
    # TODO: handle no applicable method
    methods[1].proc(next, args...; kwargs...)
end

(em::EffectiveMethod)(args, kwargs) = apply_methods(em.methods, args, kwargs)

# Generic function call
function (e::Entity)(args...; kwargs...)
    args_types = map(classof, args)
    effective_method = if haskey(e.cache, args_types)
        e.cache[args_types]
    else
        methods = collect(values(e.methods))
        compatible_methods = filter(method -> compatible_args(args_types, method.types), methods)
        # Compute effective method
        sort_methods = (methods) -> sort(methods, lt=(x, y) -> args_more_specific(x, y, args_types), by=method -> method.types)
        around_methods = sort_methods(filter(method -> method.qualifier == :around, compatible_methods))
        primary_methods = sort_methods(filter(method -> method.qualifier == :primary, compatible_methods))
        @assert !isempty(primary_methods) # TODO: throw error with message when there are no applicable primary methods
        e.cache[args_types] = EffectiveMethod([around_methods; primary_methods])
    end

    effective_method(args, kwargs)
end
