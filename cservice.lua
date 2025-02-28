local CSERVICE = { "snlua", "logger", "gate", "harbor" }
for _, name in ipairs(CSERVICE) do
    target(name)
        set_kind("shared")
        set_prefixname("")
        add_cflags("-fPIC","--shared")
        set_targetdir("cservice")
        add_includedirs("skynet-src")
        add_packages("lua")
        add_files("service-src/service_" .. name .. ".c")
end
