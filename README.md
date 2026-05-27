# JPath.jl

Resolve short path aliases to full filesystem paths in the Julia REPL and scripts.

```julia
julia> j"pdata/results.csv"
"/Users/you/Projects/MyProject.jl/rsrc/pdata/results.csv"

julia> j"dotfiles/zshrc"
"/Users/you/dotfiles/zshrc"
```

## Installation

Not yet registered in the Julia General Registry. Install directly from GitHub:

```julia
using Pkg
Pkg.add(url="https://github.com/WooJoongKim0107/JPath.jl")
```

## Setup

Add the following to `~/.julia/config/startup.jl`:

```julia
using JPath

# Set the project root (or set the JPATH_ROOT environment variable instead)
JPath.set_root!("~/Projects/MyProject.jl")

# Project-relative aliases: j"key/file" => joinpath(root, relpath, "file")
JPath.set_proj_dirs!(Dict(
    "data"  => "rsrc/data",
    "pdata" => "rsrc/pdata",
    "src"   => "src",
))

# Absolute path aliases: j"key/file" => joinpath(expanduser(abspath), "file")
JPath.set_other_dirs!(Dict(
    "~"        => "~",
    "dotfiles" => "~/dotfiles",
    "config"   => "~/.julia/config",
))
```

The project root can also be set via the `JPATH_ROOT` environment variable,
which is useful on machines where you don't want to modify `startup.jl`.

## Usage

| Expression | Resolves to |
|---|---|
| `j"pdata/file.csv"` | `joinpath(root, "rsrc/pdata", "file.csv")` |
| `j"src"` | `joinpath(root, "src")` |
| `j"dotfiles/zshrc"` | `joinpath(expanduser("~/dotfiles"), "zshrc")` |
| `jpath()` | the project root |
| `jpath("pdata/file.csv")` | same as `j"pdata/file.csv"` |

`$`-interpolation works inside `j"..."`:

```julia
subdir = "experiment_01"
j"pdata/$subdir/output.h5"  # => joinpath(root, "rsrc/pdata", "experiment_01", "output.h5")
```

Use `jopen` as a drop-in for `open` with a `j`-path:

```julia
jopen("pdata/results.csv") do io
    read(io, String)
end
```

## API

```julia
# Path resolution
jpath(path="")                          # resolve a path string
@j_str                                  # j"..." string macro

# File I/O
jopen(f, path, args...; kwargs...)      # open(f, jpath(path), ...)
jread(path, type=String)                # read(jpath(path), type)
jreadlines(path, args...; kwargs...)    # readlines(jpath(path), ...)

# Directory operations
jreaddir(path="", args...; kwargs...)   # readdir(jpath(path), ...)
jmkpath(path)                           # mkpath(jpath(path))
jcd(path="")                            # cd(jpath(path))

# Predicates
jisfile(path)                           # isfile(jpath(path))
jisdir(path)                            # isdir(jpath(path))
jispath(path)                           # ispath(jpath(path))

# Include
@jinclude "key/script.jl"              # include(jpath("key/script.jl")) into calling module

# Configuration
set_root!(path)                         # set project root
set_proj_dirs!(d::AbstractDict)         # replace all project-relative aliases
set_other_dirs!(d::AbstractDict)        # replace all absolute path aliases
add_proj_dir!(key, relpath)             # add one project-relative alias
add_other_dir!(key, abspath)            # add one absolute path alias
```
