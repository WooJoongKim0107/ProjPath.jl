module JPath

export jpath, @j_str, @jinclude
export set_root!, add_proj_dir!, add_other_dir!, set_proj_dirs!, set_other_dirs!

const _PROJ_DIRS_ = Dict{String,String}()
const _OTHER_DIRS_ = Dict{String,String}()
const _ROOT_ = Ref{String}("")

"""
    set_root!(path)

Set the project root directory used by [`jpath`](@ref). Overrides the
`JPATH_ROOT` environment variable.

Typically called in `~/.julia/config/startup.jl`:
```julia
using JPath
JPath.set_root!("~/Projects/MyProject.jl")
```
"""
function set_root!(path::AbstractString)
    _ROOT_[] = String(path)
end

"""
    add_proj_dir!(key, relpath)

Register a project-relative directory alias so that `j"key/file"` resolves to
`joinpath(root, relpath, "file")`.
"""
function add_proj_dir!(key::AbstractString, relpath::AbstractString)
    _PROJ_DIRS_[String(key)] = String(relpath)
end

"""
    add_other_dir!(key, abspath)

Register an absolute path alias so that `j"key/file"` resolves to
`joinpath(expanduser(abspath), "file")`.
"""
function add_other_dir!(key::AbstractString, abspath::AbstractString)
    _OTHER_DIRS_[String(key)] = String(abspath)
end

"""
    set_proj_dirs!(d::AbstractDict)

Replace all project-relative directory aliases at once.
"""
function set_proj_dirs!(d::AbstractDict)
    empty!(_PROJ_DIRS_)
    merge!(_PROJ_DIRS_, d)
end

"""
    set_other_dirs!(d::AbstractDict)

Replace all absolute path aliases at once.
"""
function set_other_dirs!(d::AbstractDict)
    empty!(_OTHER_DIRS_)
    merge!(_OTHER_DIRS_, d)
end

function _root()
    r = _ROOT_[]
    isempty(r) ? get(ENV, "JPATH_ROOT", ".") : r
end

"""
    jpath(path="") -> String

Resolve `path` using registered aliases and the configured project root.

Resolution rules:
- `jpath()` or `jpath("")` returns the project root.
- If the first `/`-separated component of `path` matches a key in the "other
  dirs" table (see [`add_other_dir!`](@ref)), it is treated as an absolute path.
- Otherwise the first component is looked up in the "proj dirs" table (see
  [`add_proj_dir!`](@ref)), or used as-is, and the result is joined to the root.

The project root is resolved in this priority order:
1. A value set via [`set_root!`](@ref)
2. The `JPATH_ROOT` environment variable
3. The current directory `"."`

# Examples
```julia
JPath.set_root!("~/Projects/MyProject.jl")
JPath.set_proj_dirs!(Dict("data" => "rsrc/data", "pdata" => "rsrc/pdata"))
JPath.set_other_dirs!(Dict("~" => "~", "dotfiles" => "~/dotfiles"))

jpath()                  # => expanduser("~/Projects/MyProject.jl")
jpath("data")            # => joinpath(root, "rsrc/data")
jpath("pdata/file.csv")  # => joinpath(root, "rsrc/pdata", "file.csv")
jpath("dotfiles/zshrc")  # => joinpath(expanduser("~/dotfiles"), "zshrc")
```
"""
function jpath(path::AbstractString="")
    isempty(path) && return expanduser(_root())

    slash_idx = findfirst('/', path)
    head = isnothing(slash_idx) ? path : path[1:slash_idx-1]
    tail = isnothing(slash_idx) ? nothing : path[slash_idx+1:end]

    base = if haskey(_OTHER_DIRS_, head)
        expanduser(_OTHER_DIRS_[head])
    else
        root = expanduser(_root())
        rel = get(_PROJ_DIRS_, head, head)
        isempty(rel) ? root : joinpath(root, rel)
    end

    isnothing(tail) ? base : joinpath(base, tail)
end

"""
    j"key/rest/of/path"

String macro shorthand for [`jpath`](@ref). Supports `\$`-interpolation.

```julia
j"pdata/results.csv"
j"dotfiles/zshrc"
j"\$subdir/data/file.h5"  # interpolated at macro-expansion time
```
"""
macro j_str(s)
    ex = Meta.parse("\"$s\"")
    return :(jpath($ex))
end

"""
    @jinclude "key/script.jl"

Equivalent to `include(jpath("key/script.jl"))`, but evaluates into the
*calling* module rather than `JPath`.

Note: this must be a macro because `include` inside a regular function always
evaluates into the module where the function is defined.
"""
macro jinclude(path_expr)
    mod = __module__
    return :(Base.include($mod, jpath($(esc(path_expr)))))
end

end # module JPath
