@method print_object(io, class::Class; compact=false) =
    if compact
        print(io, class.name)
    else
        print(io, class.name, " (class instance of ", classof(class).name, ")")
        print(io, "\n slots: ", class.slots)
        print(io, "\n direct supers: ", class.dsupers)
    end

@method print_object(io, obj::Object; compact=false) =
    begin
        print(io, classof(obj).name, "(")
        slots = classof(obj).slots
        if length(slots) > 0
            print(io, slots[begin], "=", getslot(obj, slots[begin]))
            for slot in slots[begin+1:end]
                print(io, ", ", slot, "=", getslot(obj, slot))
            end
        end
        print(io, ")")
    end

@method print_object(io, method::MultiMethod; compact=false) =
    print(io, classof(method).name, method.types)

@method print_object(io, gf::GenericFunction; compact=false) =
    begin
        count = length(gf.methods)
        print(io, classof(gf).name, " with ", count, " ")
        if count != 1
            print(io, "methods")
        else
            print(io, "method")
        end

        if !compact && count > 0
            print(io, ":")
            foreach(p -> print(io, "\n ", p[1]), gf.methods)
        end
    end

function Base.show(io::IO, obj::Instance)
    compact = get(io, :compact, true)
    print_object(io, obj; compact=compact)
end

function Base.show(io::IO, ::MIME"text/plain", obj::Instance)
    compact = get(io, :compact, false)
    print_object(io, obj; compact=compact)
end

@method compatible_metaclasses(class::Class, super::Class) = issubclass(classof(class), classof(super))

@method allocate_instance(class::Class) = LibObj(class, NamedTuple{class.slots}(ntuple(_ -> missing, length(class.slots))))
@method allocate_instance(class::EntityClass) = Entity(class, missing)

@method compute_cpl(class::Class) = begin
    visited = Set{Instance}()
    visiting = Set{Instance}()
    cpl = Vector{Instance}()

    function topological(class)
        if class in visited
            return
        elseif class in visiting
            error("Cannot have circular dependencies in class hierarchies")
        end

        push!(visiting, class)

        for super in reverse(class.dsupers)
            topological(super)
        end

        pop!(visiting, class)
        push!(visited, class)
        pushfirst!(cpl, class)
    end

    topological(class)
    tuple(cpl...)
end

@method initialize(object::Object; initargs...) = begin
    for slot in classof(object).slots
        setproperty!(object, slot, get(initargs, slot, missing))
    end
end

@method initialize(gf::GenericFunction; combination, initargs...) = begin
	gf.combination = combination
end

@method initialize(class::Class; name, initargs...) = begin
    class.name = name
    class.dsupers = get(initargs, :dsupers, (Object,))
    class.slots = get(initargs, :slots, ())
    class.cpl = compute_cpl(class)

    compatible = (super) -> compatible_metaclasses(class, super)
    incompatible_supers = filter(!compatible, class.dsupers)
    if !isempty(incompatible_supers)
        error(
            class, " cannot be a subclass of ", join(incompatible_supers, ", ", " or "), " as its metaclass ",
            classof(class), " isn't compatible with ", join(unique(map(classof, incompatible_supers)), ", ", " and "),
            ". Define a method for compatible_metaclasses to override this."
        )
    end
end

make = begin
    local make_gf

    @method make_gf(class::Class; initargs...) =
        let instance = allocate_instance(class)
            initialize(instance; initargs...)
            instance
        end

    make_gf
end

add_method = begin
    local add_method_gf

    @method add_method_gf(gf::GenericFunction, method::MultiMethod) = begin
        for types in keys(gf.cache)
            if compatible_args(types, method.types)
                delete!(gf.cache, types)
            end
        end
        gf.methods[(method.types, method.qualifier)] = method
    end

    add_method_gf
end
