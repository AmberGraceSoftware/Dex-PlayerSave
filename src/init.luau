--!strict
local Players = game:GetService("Players")
local FindLatestWallyPackage = require(script.FindLatestWallyPackage)
local Dex = FindLatestWallyPackage("ambergracesoftware/dex", "Dex")
local PlayerSave =
    FindLatestWallyPackage("ambergracesoftware/playersave", "PlayerSave")

--[=[
    @class DexPlayerSave

    Utility for creating Dex Observers that connect to saves in the PlayerSave
    library.
]=]
local DexPlayerSave = {}

export type Observable<T> = {
    [string]: any,
    Subscribe: (any, listener: (newValue: T) -> (), ...any) -> () -> (),
    Current: (any) -> T,
}

local saveStatusChangedListenersByPlayer =
    {} :: { [Player]: { [() -> ()]: boolean } }

local function notifySaveStatusChanged(owner: Player)
    local listenerSet = saveStatusChangedListenersByPlayer[owner]
    if not listenerSet then
        return
    end
    for listener in table.clone(listenerSet) do
        task.spawn(listener)
    end
end
PlayerSave.OnSaveOpened(notifySaveStatusChanged)
PlayerSave.OnSaveLoaded(notifySaveStatusChanged)
PlayerSave.OnSaveClosed(notifySaveStatusChanged)

local function mapPlayerToSaveObservable(
    ownerCanBeObservable: Player | Observable<Player?>,
    requireOpenStatus: boolean?,
    requireLoadedStatus: boolean?
): Observable<any?>
    local ownerObservable = Dex.CoerceAsObservable(ownerCanBeObservable)
    return Dex.FlattenObservable(ownerObservable:Map(function(owner: Player?)
        if not owner then
            return nil
        end
        local initialSave = PlayerSave.Get(owner)
        if
            initialSave
            and not requireOpenStatus
            and not requireLoadedStatus
        then
            -- In most cases, the moment we find an open save, we can just cache
            -- that value in the observable permanently for this player.
            return initialSave
        end
        return Dex.CustomObservable(function()
            local save = PlayerSave.Get(owner)
            if not save then
                return nil
            end
            if requireOpenStatus and save._closed then
                return nil
            end
            if requireLoadedStatus and not save:IsLoaded() then
                return nil
            end
            return save
        end, function(notifyUpdate)
            local listenerSet = saveStatusChangedListenersByPlayer[owner]
            if not listenerSet then
                listenerSet = {}
                saveStatusChangedListenersByPlayer[owner] = listenerSet
            end
            listenerSet[notifyUpdate] = true
            return function()
                listenerSet[notifyUpdate] = nil
                if not next(listenerSet) then
                    saveStatusChangedListenersByPlayer[owner] = nil
                end
            end
        end)
    end))
end

--[=[
    @function ObserveForPlayer
    @within DexPlayerSave

    @param owner Player | Observable<Player?>
    @param keyPath string | number | { string | number }
    @param placeholderValueIfNil T?
    @return T

    Observes a value within a given player's save, at the provided keypath.
    If the value is ever "nil", the placeholder value will be resolved as the
    current state if provided.
]=]
function DexPlayerSave.ObserveForPlayer<T>(
    owner: Player | Observable<Player?>,
    keyPath: string | number | { string | number },
    placeholderValueIfNil: T
): T
    return Dex.FlattenObservable(
        mapPlayerToSaveObservable(owner):Map(function(save: any?)
            if not save then
                return placeholderValueIfNil
            end
            return Dex.CustomObservable(function()
                local value = save:Get(keyPath)
                if value == nil then
                    return placeholderValueIfNil
                end
                return value
            end, function(notifyUpdate)
                return save:Subscribe(keyPath, notifyUpdate, false)
            end)
        end)
    )
end

--[=[
    @function ObserveLocal
    @within DexPlayerSave
    @param keyPath string | number | { string | number }
    @param placeholderValueIfNil T?
    @return T

    Observes a value within the local player's save, at the provided keypath.
    If the value is ever "nil", the placeholder value will be resolved as the
    current state if provided.
]=]
function DexPlayerSave.ObserveLocal<T>(
    keyPath: string | number | { string | number },
    placeholderValueIfNil: T
): T
    return DexPlayerSave.ObserveForPlayer(
        Players.LocalPlayer,
        keyPath,
        placeholderValueIfNil
    )
end

return DexPlayerSave
