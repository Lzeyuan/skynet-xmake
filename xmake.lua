-- 原项目依赖assert，所以只有debug模式
add_rules("mode.debug")

-- >>> platform >>>
local SKYNET_LIBS = {"pthread", "m"}
local SHARED = {"-fPIC", "--shared"}
local EXPORT = "-Wl,-E"
local MALLOC_STATICLIB = ""
local SKYNET_DEFINES = ""

if is_plat("linux") then
    table.insert(SKYNET_LIBS, "dl")
    table.insert(SKYNET_LIBS, "rt")
end

if is_plat("macosx") then
    table.insert(SKYNET_LIBS, "dl")
    EXPORT = ""
    SHARED = {"-fPIC","-dynamiclib","-Wl,-undefined,dynamic_lookup"}
    MALLOC_STATICLIB = ""
    SKYNET_DEFINES  = ""
end

if is_plat("freebsd") then
    table.insert(SKYNET_LIBS, "rt")
end

-- Turn off jemalloc and malloc hook on macosx
local SKYNET_DEFINES = ""
if is_plat("macosx") then
    SKYNET_DEFINES = "-DNOUSE_JEMALLOC"
end
-- <<< platform <<<

local PLAT = "linux"
local third_part_deps = {"third_part::jemalloc", "third_part::lua"}
local MAKE = "make"
local CC = "gcc"
local SKYNET_BUILD_PATH = "."

local LUA_INC = "3rd/lua"
local LUA_STATICLIB = "3rd/lua/liblua.a"
local JEMALLOC_INC = "3rd/jemalloc/include/jemalloc"

-- 这是个 c 项目
set_toolchains("gcc")

-- CFLAGS = -g -O2 -Wall -I$(LUA_INC) $(MYCFLAGS)
set_symbols("debug")
set_optimize("faster")
set_warnings("all")
add_includedirs(LUA_INC)
add_cflags("")

target("skynet-main", function()
    set_kind("binary")
    -- xmake默认并行构建target，导致 jemalloc 还未编译完成就直接编译 skynet-main，导致编译失败
    -- 感谢群友 Gracious 提供的方案
    -- https://github.com/xmake-io/xmake/discussions/2500
    -- https://xmake.io/#/zh-cn/guide/build_policies?id=buildacross_targets_in_parallel
    set_policy("build.across_targets_in_parallel", false)
    add_includedirs("skynet-src")
    add_syslinks(SKYNET_LIBS)
    add_ldflags(EXPORT, SKYNET_DEFINES)
    add_cflags(SKYNET_DEFINES)

    set_targetdir(os.curdir())
    set_filename("skynet")

    add_files("skynet-src/*.c")
    add_deps(third_part_deps)
    add_deps(CSERVICE)
    add_deps(LUA_CLIB)
end)

namespace ("third_part", function ()
    target("jemalloc", function()
        set_kind("object")

        before_build(function (target) 
            if not os.exists("3rd/jemalloc/Makefile") then
                os.exec("git submodule update --init")
                os.cd("3rd")
                os.cd("jemalloc")
                os.exec("./autogen.sh --with-jemalloc-prefix=je_ --enable-prof")
                -- make CC=gcc
                os.exec(MAKE .. " CC=" .. CC)
            end
        end)
        
        add_linkdirs("3rd/jemalloc/lib", {public = true})
        add_links("jemalloc_pic", {public = true})
        add_includedirs(JEMALLOC_INC, {public = true})
    end)

    target("lua", function()
        set_kind("phony")
        on_build(function (target) 
            if not os.exists(LUA_STATICLIB) then
                os.cd("3rd")
                os.cd("lua")
                -- make 'CC=gcc -std=gnu99' linux
                os.exec(MAKE  .. " CC='" .. CC .." -std=gnu99' " .. PLAT)
            end
        end)
        add_linkdirs(LUA_INC, {public = true})
        add_links("lua", {public = true})
        add_includedirs(LUA_INC, {public = true})
    end)
end)

-- cservices
local CSERVICE = { "snlua", "logger", "gate", "harbor" }
for _, name in ipairs(CSERVICE) do
    target(name)
        set_kind("shared")
        set_prefixname("")
        add_cflags("-fPIC","--shared")
        set_targetdir("cservice")
        add_includedirs("skynet-src", "3rd/lua")
        add_files("service-src/service_" .. name .. ".c")
end

-- luaclib
namespace ("luaclib", function ()
    local TLS_MODULE = ""
    local TLS_LIB= ""
    local TLS_INC= ""

    local LUA_CLIB = {
        "skynet",
        "client",
        "bson", "md5" ,"sproto" ,"lpeg", 
        TLS_MODULE
    }

    set_targetdir("luaclib")
    -- lib***.so => ***.so
    set_prefixname("")

    -- .so
    set_kind("shared")


    target("skynet", function()
        add_includedirs("skynet-src", "service-src", "lualib-src")
        add_files("lualib-src/lua-*.c", "lualib-src/lsha1.c")
    end)

    target("bson", function()
        add_includedirs("skynet-src")
        add_files("lualib-src/lua-bson.c")
    end)

    target("md5", function()
        add_includedirs("3rd/lua-md5")
        add_files("3rd/lua-md5/*.c")
    end)

    target("client", function()
        add_syslinks("pthread")
        add_files("lualib-src/lua-clientsocket.c", "lualib-src/lua-crypt.c", "lualib-src/lsha1.c")
    end)

    target("sproto", function()
        add_includedirs("lualib-src/sproto")
        add_files("lualib-src/sproto/sproto.c", "lualib-src/sproto/lsproto.c")
    end)

    -- TODO: add library
    -- target("ltls",function ()
    --     set_kind("shared")
    --     add_includedirs("skynet-src")
    --     add_linkdirs(TLS_LIB)
    --     add_includedirs(TLS_INC)
    --     add_links("ssl")
    --     add_files("lualib-src/ltls.c")
    -- end)

    target("lpeg", function()
        add_includedirs("3rd/lpeg")
        add_files("3rd/lpeg/*.c")
    end)
end)

task("cleanall", function () 
    on_run(function ()
        -- clean 3rd
        local third_part_dirs = os.projectdir() .. "/3rd"
        os.cd("3rd")
        -- clean 3rd/jemalloc
        print("===== clean jemalloc =====")
        if os.exists("jemalloc/Makefile") then
            os.cd("jemalloc")
            os.exec(MAKE .. " clean")
            os.rm("Makefile")
        end
        print("===== end clean jemalloc =====")

        -- clean 3rd/lua
        print("===== clean lua =====")
        os.cd(third_part_dirs)
        os.cd("lua")
        os.exec(MAKE .. " clean")
        print("===== end clean lua =====")

        -- clean project
        os.cd(os.projectdir())
        os.exec("xmake clean")
        os.rm("luaclib")
        os.rm("cservice")
    end)

    set_menu {
        usage = "xmake cleanall",
        description = "清理所有生成的文件和第三方库生成文件",
    }
end)