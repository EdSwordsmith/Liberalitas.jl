# single inheritance
@class SingleInheritanceClass(Class) (name, dslots, slots, dsupers, cpl)

@method initialize(class::SingleInheritanceClass; name, dsupers=(Object,), slots=()) = begin
    next()

    if length(class.dsupers) > 1
        error(class, " cannot be a subclass of more than one class as it only supports single inheritance.")
    end

    class.dslots = slots
    class.slots = (union(class.dsupers[1].slots, slots)...,)
    class.cpl = compute_cpl(class)
end

# multiple inheritance
@class MultipleInheritanceClass(Class) (name, dslots, slots, dsupers, cpl)

@method initialize(class::MultipleInheritanceClass; name, dsupers=(Object,), slots=()) = begin
    next()
    class.dslots = slots
    class.slots = (union(slots, map(super -> super.slots, class.dsupers)...)...,)
    class.cpl = compute_cpl(class)
end
