"""
    generate_gradient(E, ::Type{T})

Generate the statements for the evaluation of the polynomial with exponents `E`.
This assumes that E is in reverse lexicographic order.
"""
function generate_gradient(E, ::Type{T}) where T
    exprs = []
    values = generate_gradient!(exprs, E, T, size(E, 1), 1, true)
    out = :($(values[1]), SVector($(values[2:end]...)))

    Expr(:block, exprs..., out)
end

function generate_gradient!(exprs, E, ::Type{T}, nvar, nterm, final=false) where T
    m, n = size(E)

    if n == 1
        val, dvals = monomial_product_with_derivatives(T, E[:,1], :(c[$nterm]))

        @gensym c
        push!(exprs, :($c = $val))

        cs = [c]
        for dval in dvals
            @gensym c
            push!(cs, c)
            push!(exprs, :($c = $dval))
        end

        return cs
    end

    if m == 1
        coeffs = [:(c[$j]) for j=nterm:nterm+n]
        val, dval = evalpoly_derivative!(exprs, T, E[1,:], coeffs, x_(nvar))
        return [val, dval]
    end

    # Recursive
    degrees, submatrices = degrees_submatrices(E)
    # For each coefficient we have the actual coefficent plus each partial derivative
    # of the other variables
    coeffs = Matrix{Symbol}(undef, length(submatrices), m)
    for (k, E_d) in enumerate(submatrices)
        coeffs[k, :] = generate_gradient!(exprs, E_d, T, nvar - 1, nterm)
        nterm += size(E_d, 2)
    end

    # Now we have to evaluate polynomials
    # for our current variable we need our new partial derivative
    val, dval = evalpoly_derivative!(exprs, T, degrees, coeffs[:, 1], x_(nvar))
    values = [val]
    for k=2:m
        @gensym c
        push!(exprs, :($c = $(evalpoly(T, degrees, coeffs[:, k], x_(nvar)))))
        push!(values, c)
    end
    push!(values, dval)

    return values
end