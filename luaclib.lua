add_cflags("-O2", "-fPIC")

add_packages("lua")
set_targetdir("luaclib")
set_prefixname("")


target("skynet", function()
    set_kind("shared")
    add_includedirs("skynet-src", "service-src", "lualib-src")
    add_files("lualib-src/lua-*.c", "lualib-src/lsha1.c")
end)

target("bson", function()
    set_kind("shared")
    add_includedirs("skynet-src")
    add_files("lualib-src/lua-bson.c")
end)

target("md5", function()
    set_kind("shared")
    add_includedirs("3rd/lua-md5")
    add_files("3rd/lua-md5/*.c")
end)

target("client", function()
    set_kind("shared")
    add_syslinks("pthread")
    add_files("lualib-src/lua-clientsocket.c", "lualib-src/lua-crypt.c", "lualib-src/lsha1.c")
end)

target("sproto", function()
    set_kind("shared")
    add_includedirs("lualib-src/sproto")
    add_files("lualib-src/sproto/sproto.c", "lualib-src/sproto/lsproto.c")
end)

-- TODO: add library
-- target("ltls",function ()
--     set_kind("shared")
--     add_includedirs("skynet-src")
--     add_files("lualib-src/ltls.c")
-- end)

target("lpeg", function()
    set_kind("shared")
    add_includedirs("3rd/lpeg")
    add_files("3rd/lpeg/*.c")
end)
