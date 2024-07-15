function merge_initargs(class, initargs)
    filtered = filter(slot -> slot ∉ class.slots, initargs)
    (union(filtered, class.initargs)...,)
end

function merge_initforms(class, initforms)
    removekeys(::Tuple, _) = ()
    removekeys(nt::NamedTuple{names}, keys) where names =
        NamedTuple{filter(x -> x ∉ keys, names)}(nt)

    filtered = removekeys(initforms, class.slots)
    (;filtered..., class.initforms...)
end

# single inheritance
@class SingleInheritanceClass(Class) [
    name
    [dslots :initform => ()]
    [slots :initform => ()]
    [dsupers :initform => (Object,)]
    [cpl :noinitarg]
    [initargs :initform => ()]
    [initforms :initform => NamedTuple()]
]

@method initialize(class::SingleInheritanceClass; initargs...) = begin
    next()

    if length(class.dsupers) > 1
        error(class, " cannot be a subclass of more than one class as it only supports single inheritance.")
    end

    super = class.dsupers[1]
    class.dslots = class.slots
    class.initargs = merge_initargs(class, super.initargs)
    class.initforms = merge_initforms(class, super.initforms)
    class.slots = (union(super.slots, class.slots)...,)
end

# multiple inheritance
@class MultipleInheritanceClass(Class) [
    name
    [dslots :initform => ()]
    [slots :initform => ()]
    [dsupers :initform => (Object,)]
    [cpl :noinitarg]
    [initargs :initform => ()]
    [initforms :initform => NamedTuple()]
]

@method initialize(class::MultipleInheritanceClass; initargs...) = begin
    next()
    class.dslots = class.slots

    # Classes with higher precedence have priority when solving conflicts
    sorted_classes = intersect(class.cpl, (class.dsupers..., class))
    class.initargs = foldr(merge_initargs, sorted_classes, init=())
    class.initforms = foldr(merge_initforms, sorted_classes, init=NamedTuple())
    class.slots = (union(map(super -> super.slots, class.dsupers)..., class.slots)...,)
end
