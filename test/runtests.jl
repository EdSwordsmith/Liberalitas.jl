using Liberalitas
using Test

@class Z()
@class O()
@class D(O)
@class B(Z)
@class C(B)
@class A(B, C, D)

@method myfn(n::Int) = n
@method myfn(_) = "Not an Int"

@testset "Liberalitas.jl" begin
    @test A.cpl == (A, C, B, Z, D, O, Object, Top)
    @test classof(make(A)) == A

    @test myfn(10) == 10
    @test myfn("") == "Not an Int"
end
