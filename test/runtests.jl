using Test
using ProjPath

function with_clean_projpath(f)
    old_env = get(ENV, "PROJPATH_ROOT", nothing)

    try
        clear_setups!()
        f()
    finally
        clear_setups!()

        if old_env === nothing
            delete!(ENV, "PROJPATH_ROOT")
        else
            ENV["PROJPATH_ROOT"] = old_env
        end
    end
end

@testset "ProjPath.jl" begin
    # Root resolution should fall back to ".", honor PROJPATH_ROOT, and let
    # set_root! take precedence over the environment.
    @testset "root resolution" begin
        with_clean_projpath() do
            @test jpath() == expanduser(".")
            @test jpath("") == expanduser(".")
        end

        mktempdir() do env_root
            mktempdir() do configured_root
                with_clean_projpath() do
                    ENV["PROJPATH_ROOT"] = env_root
                    @test jpath() == env_root
                    @test jpath("") == env_root

                    set_root!(configured_root)
                    @test jpath() == configured_root
                    @test jpath("") == configured_root
                end
            end
        end
    end

    # Paths whose first component is not registered resolve relative to root.
    @testset "unregistered paths are root-relative" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)

                @test jpath("subdir") == joinpath(root, "subdir")
                @test jpath("subdir/file.txt") == joinpath(root, "subdir", "file.txt")
                @test jpath("nested/path/file.csv") == joinpath(root, "nested", "path", "file.csv")
            end
        end
    end

    # Project aliases map the first path component to a root-relative directory.
    @testset "project aliases" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                set_proj_dirs!(Dict("data" => "rsrc/data", "pdata" => "rsrc/pdata"))

                @test jpath("data") == joinpath(root, "rsrc", "data")
                @test jpath("data/file.csv") == joinpath(root, "rsrc", "data", "file.csv")
                @test jpath("pdata/nested/file.h5") == joinpath(root, "rsrc", "pdata", "nested", "file.h5")

                set_proj_dirs!(Dict("root" => ""))
                @test jpath("root") == root
                @test jpath("root/output.txt") == joinpath(root, "output.txt")
            end
        end
    end

    # Other aliases map the first path component to an expanduser-based path.
    @testset "other aliases" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                set_other_dirs!(Dict("home" => "~", "config" => "~/.julia/config"))

                @test jpath("home") == expanduser("~")
                @test jpath("home/docs") == joinpath(expanduser("~"), "docs")
                @test jpath("config/startup.jl") == joinpath(expanduser("~/.julia/config"), "startup.jl")
            end
        end
    end

    # Absolute "other" aliases intentionally win when an alias exists in both
    # tables.
    @testset "other aliases take precedence over project aliases" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                set_proj_dirs!(Dict("shared" => "project/shared"))
                set_other_dirs!(Dict("shared" => "~/.julia"))

                @test jpath("shared") == expanduser("~/.julia")
                @test jpath("shared/config") == joinpath(expanduser("~/.julia"), "config")
            end
        end
    end

    # set_*_dirs! replaces existing aliases, while add_*_dir! appends one alias.
    @testset "configuration mutators" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                set_proj_dirs!(Dict("old" => "old"))
                set_proj_dirs!(Dict("new" => "new"))
                @test jpath("old/file.txt") == joinpath(root, "old", "file.txt")
                @test jpath("new/file.txt") == joinpath(root, "new", "file.txt")

                set_other_dirs!(Dict("oldhome" => "~"))
                set_other_dirs!(Dict("dotjulia" => "~/.julia"))
                @test jpath("oldhome/file.txt") == joinpath(root, "oldhome", "file.txt")
                @test jpath("dotjulia/config") == joinpath(expanduser("~/.julia"), "config")

                add_proj_dir!("src", "src")
                add_other_dir!("cfg", "~/.julia/config")
                @test jpath("src/main.jl") == joinpath(root, "src", "main.jl")
                @test jpath("cfg/startup.jl") == joinpath(expanduser("~/.julia/config"), "startup.jl")
            end
        end
    end

    # clear_setups! removes all in-process state and the PROJPATH_ROOT environment
    # variable, returning resolution to the default root.
    @testset "clear_setups!" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                ENV["PROJPATH_ROOT"] = joinpath(root, "env")
                set_proj_dirs!(Dict("data" => "rsrc/data"))
                set_other_dirs!(Dict("home" => "~"))

                @test jpath("data/file.csv") == joinpath(root, "rsrc", "data", "file.csv")
                @test jpath("home/docs") == joinpath(expanduser("~"), "docs")

                @test clear_setups!() === nothing
                @test !haskey(ENV, "PROJPATH_ROOT")
                @test jpath() == expanduser(".")
                @test jpath("data/file.csv") == joinpath(expanduser("."), "data", "file.csv")
                @test jpath("home/docs") == joinpath(expanduser("."), "home", "docs")
            end
        end
    end

    # The j"..." string macro is shorthand for jpath and supports caller-scope
    # interpolation.
    @testset "string macro" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                set_proj_dirs!(Dict("data" => "rsrc/data"))
                set_other_dirs!(Dict("home" => "~"))

                subdir = "experiment_01"
                @test j"data/file.csv" == joinpath(root, "rsrc", "data", "file.csv")
                @test j"data/$subdir/output.h5" == joinpath(root, "rsrc", "data", subdir, "output.h5")
                @test j"home/docs" == joinpath(expanduser("~"), "docs")
            end
        end
    end

    # @jinclude should include resolved files into the calling module, not ProjPath.
    @testset "@jinclude includes into caller module" begin
        mktempdir() do root
            with_clean_projpath() do
                set_root!(root)
                set_proj_dirs!(Dict("src" => "src"))

                script = joinpath(root, "src", "hello.jl")
                mkpath(dirname(script))
                write(script, "included_value() = :from_jinclude\n")

                test_module = Module(:JIncludeTarget)
                Core.eval(test_module, :(using ProjPath))
                Core.eval(test_module, :(@jinclude "src/hello.jl"))

                @test !isdefined(ProjPath, :included_value)
                @test Core.eval(test_module, :(included_value())) == :from_jinclude
            end
        end
    end
end
