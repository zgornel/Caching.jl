# Hash all input arguments and return a final hash
function arghash(args...; kwargs...)
    _h1 = hash(hash(arg)+hash(typeof(arg)) for arg in args)
    _h2 = hash(hash(kwarg) for kwarg in kwargs)
    return hash(_h1 + _h2)
end
