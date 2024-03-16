module Liberalitas

macro class(name, slots)
    if isdefined(__module__, name)
        class_type = getfield(__module__, name)
        classversion = getfield(__module__, :classversion)
        version = classversion(class_type) + 1
    else
        version = 1
    end

    if slots isa Symbol
        # there is only one slot
        slots = Expr(:tuple, slots)
    end

    struct_name = Symbol(name, "__v", version)
    struct_head = Expr(:(<:), struct_name, name)
    struct_class = Expr(:struct, true, struct_head, Expr(:block, slots.args...))

    esc(quote
        abstract type $name end
        $struct_class

        global $name(args...) = $struct_name(args...)
        global classversion(::Type{$name}) = $version
        global classof(::$name) = $name

        $name
    end)
end

macro class(name)
    esc(:(@class $name ()))
end

export @class

end
