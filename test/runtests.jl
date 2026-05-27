using Test
using JPath

@testset "JPath.jl" begin
    mktempdir() do root
        set_root!(root)

        @testset "jpath root" begin
            @test jpath() == root
            @test jpath("") == root
        end

        @testset "unregistered key (used as-is)" begin
            @test jpath("subdir") == joinpath(root, "subdir")
            @test jpath("subdir/file.txt") == joinpath(root, "subdir", "file.txt")
        end

        @testset "proj dirs" begin
            set_proj_dirs!(Dict("data" => "rsrc/data", "pdata" => "rsrc/pdata"))
            @test jpath("data") == joinpath(root, "rsrc/data")
            @test jpath("data/file.csv") == joinpath(root, "rsrc/data", "file.csv")
            @test jpath("pdata/nested/file.h5") == joinpath(root, "rsrc/pdata", "nested/file.h5")
        end

        @testset "other dirs" begin
            set_other_dirs!(Dict("home" => "~"))
            @test jpath("home") == expanduser("~")
            @test jpath("home/docs") == joinpath(expanduser("~"), "docs")
        end

        @testset "string macro" begin
            set_proj_dirs!(Dict("data" => "rsrc/data"))
            set_other_dirs!(Dict("home" => "~"))
            @test j"data/file.csv" == joinpath(root, "rsrc/data", "file.csv")
            @test j"home/docs" == joinpath(expanduser("~"), "docs")
        end

        @testset "add_proj_dir! / add_other_dir!" begin
            set_proj_dirs!(Dict{String,String}())
            set_other_dirs!(Dict{String,String}())
            add_proj_dir!("src", "src")
            add_other_dir!("cfg", "~/.julia/config")
            @test jpath("src/main.jl") == joinpath(root, "src", "main.jl")
            @test jpath("cfg/startup.jl") == joinpath(expanduser("~/.julia/config"), "startup.jl")
        end

        @testset "JPATH_ROOT env var" begin
            set_root!("")  # clear in-memory root
            withenv("JPATH_ROOT" => root) do
                @test jpath() == root
            end
            set_root!(root)  # restore for subsequent tests
        end

        set_proj_dirs!(Dict("src" => "src"))
        set_other_dirs!(Dict{String,String}())

        @testset "@jinclude" begin
            script = joinpath(root, "src", "hello.jl")
            mkpath(dirname(script))
            write(script, "global _jinclude_ran = true\n")
            @jinclude "src/hello.jl"
            @test @isdefined(_jinclude_ran) && _jinclude_ran
        end

        @testset "jread / jreadlines" begin
            f = joinpath(root, "src", "data.txt")
            write(f, "line1\nline2\n")
            @test jread("src/data.txt") == "line1\nline2\n"
            @test jreadlines("src/data.txt") == ["line1", "line2"]
        end

        @testset "jreaddir" begin
            mkpath(joinpath(root, "src", "sub"))
            entries = jreaddir("src")
            @test any(==("sub"), entries)
        end

        @testset "jisfile / jisdir / jispath" begin
            @test jisfile("src/data.txt")
            @test !jisdir("src/data.txt")
            @test jisdir("src")
            @test jispath("src/data.txt")
            @test !jispath("src/nonexistent.xyz")
        end

        @testset "jmkpath" begin
            jmkpath("src/deep/nested/dir")
            @test isdir(joinpath(root, "src", "deep", "nested", "dir"))
        end

        @testset "jcd" begin
            original = pwd()
            jcd("src")
            @test realpath(pwd()) == realpath(joinpath(root, "src"))
            cd(original)
        end
    end
end
