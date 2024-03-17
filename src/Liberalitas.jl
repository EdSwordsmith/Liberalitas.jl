module Liberalitas

macro class(name, slots, metaclass)
    if isdefined(__module__, name)
        class_type = getfield(__module__, name)
        classversion = getfield(__module__, :classversion)
        version = classversion(class_type) + 1
    else
        version = 1
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

        let instance = $metaclass()
            global metaclass(::Type{$name}) = instance
        end

        $name
    end)
end

@class StandardClass () StandardClass

macro class(name, slots)
    esc(:(@class $name $slots StandardClass))
end

macro class(name)
    esc(:(@class $name ()))
end

export @class, StandardClass

end
