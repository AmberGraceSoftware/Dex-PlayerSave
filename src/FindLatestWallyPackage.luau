--!strict
--[[
    Helper function that attempts to locate the latest (highest-semver) Wally
    package with a given ID.
]]

local cache = {}
local function FindLatestWallyPackage(
    packageId: string,
    conventionalName: string
): (ModuleScript?, string)
    if cache[packageId] then
        return cache[packageId], "Success"
    end
    local author, packageName = packageId:match("^(.+)/(.+)$")
    if not author or not packageName then
        return nil, "Invalid package ID: " .. packageId
    end
    local thisPackageModule = script.Parent
    if not thisPackageModule then
        return nil,
            "ModuleScript"
                .. script:GetFullName()
                .. "was reparented "
                .. "or destroyed from the Wally index folder."
    end
    local thisPackageFolder = thisPackageModule.Parent
    if not thisPackageFolder then
        return nil,
            "ModuleScript"
                .. thisPackageModule:GetFullName()
                .. "was "
                .. "reparented or destroyed from the Wally index folder."
    end
    local conventionalModule =
        thisPackageFolder:FindFirstChild(conventionalName)
    if conventionalModule and conventionalModule:IsA("ModuleScript") then
        cache[packageId] = conventionalModule
        return conventionalModule, "Success"
    end
    local packageIndexFolder = thisPackageFolder.Parent
    if not packageIndexFolder or packageIndexFolder.Name ~= "_Index" then
        return nil,
            "Wally Package"
                .. thisPackageFolder:GetFullName()
                .. "was "
                .. "reparented or destroyed from the Wally index folder, or a "
                .. "new Wally version was released that is not compatible with "
                .. "this script."
    end
    conventionalModule = thisPackageFolder:FindFirstChild(conventionalName)
    if conventionalModule and conventionalModule:IsA("ModuleScript") then
        cache[packageId] = conventionalModule
        return conventionalModule, "Success"
    end
    local matchingPackages = {}
    local matchStr = author .. "_" .. packageName .. "@"
    for _, object in packageIndexFolder:GetChildren() do
        if object.Name:find(matchStr, nil, true) then
            table.insert(matchingPackages, object)
        end
    end

    if #matchingPackages == 0 then
        local wallyPackagesFolder = packageIndexFolder.Parent
        if wallyPackagesFolder then
            conventionalModule =
                wallyPackagesFolder:FindFirstChild(conventionalName)
            if
                conventionalModule and conventionalModule:IsA("ModuleScript")
            then
                cache[packageId] = conventionalModule
                return conventionalModule, "Success"
            end
        end
        return nil,
            "No matching Wally package found for "
                .. packageId
                .. " near module"
                .. script:GetFullName()
    end

    local function getSemver(module: Instance)
        local s, e = module.Name:find(matchStr, nil, true)
        if not s or not e then
            return 0, 0, 0
        end
        local major, minor, patch =
            module.Name:sub(e + 1):match("@([0-9]+)%.([0-9]+)%.([0-9]+)")
        return tonumber(major) or 0, tonumber(minor) or 0, tonumber(patch) or 0
    end
    table.sort(matchingPackages, function(a, b)
        local majA, minA, patchA = getSemver(a)
        local majB, minB, patchB = getSemver(b)
        if majA > majB then
            return true
        elseif majA < majB then
            return false
        elseif minA > minB then
            return true
        elseif minA < minB then
            return false
        elseif patchA > patchB then
            return true
        elseif patchA < patchB then
            return false
        end
        return false
    end)

    local container = matchingPackages[1]
    local module: ModuleScript?
    if container:IsA("ModuleScript") then
        module = container
    else
        module = container:FindFirstChildWhichIsA("ModuleScript", true)
    end
    if not module then
        return nil,
            container:GetFullName() .. " does not contain a ModuleScript"
    end
    cache[packageId] = module
    return module, "Success"
end

return function(packageId: string, conventionalName: string): any
    local moduleScript, err =
        FindLatestWallyPackage(packageId, conventionalName)
    if not moduleScript then
        error(err)
    end
    return (require :: any)(moduleScript)
end
