--!strict
local Players = game:GetService("Players")
return function()
    it("Observes a value in a player save for a mock player", function()
        local DexPlayerSave =
            require(game.ReplicatedStorage.DevPackages.DexPlayerSave)
        local mockPlayer = {
            Parent = Players,
        } :: any
        expect(DexPlayerSave.ObserveForPlayer(mockPlayer, "Coins", 0)).to.be.ok()
    end)
end
