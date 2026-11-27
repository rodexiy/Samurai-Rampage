return function(_Context: any, Player: Player, Enabled: boolean?): string
	local Active = Enabled ~= false
	Player:SetAttribute("AutoParryShots", if Active then true else nil)

	local Status = if Active then "Enabled" else "Disabled"
	return string.format("%s automatic shot parry for %s.", Status, Player.Name)
end
