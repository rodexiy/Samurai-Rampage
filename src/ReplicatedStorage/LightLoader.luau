local LightLoader = {}

local Lighting = game:GetService("Lighting")

function LightLoader:Apply(Settings)
	if Settings:IsA("Configuration") and Settings:GetAttribute("Ambient") ~= nil then
		for _, Obj in pairs(Lighting:GetChildren()) do
			if
				not Obj:IsA("Configuration")
				and Obj:GetAttribute("Ambient") == nil
				and Obj:GetAttribute("Core") == nil
				and Obj:GetAttribute("Atmosphere") == nil
			then
				if Obj.Name ~= "DeflectedCC" and Obj.Name ~= "DeathBlur" and Obj.Name ~= "DeflectedBlur" then
					Obj:Destroy()
				end
			end
		end

		for _, Obj in pairs(Settings:GetChildren()) do
			Obj:Clone().Parent = Lighting
		end

		Lighting.Ambient = Settings:GetAttribute("Ambient")
		Lighting.Brightness = Settings:GetAttribute("Brightness")
		Lighting.ColorShift_Bottom = Settings:GetAttribute("ColorShift_Bottom")
		Lighting.ColorShift_Top = Settings:GetAttribute("ColorShift_Top")
		Lighting.EnvironmentDiffuseScale = Settings:GetAttribute("EnvironmentDiffuseScale")
		Lighting.EnvironmentSpecularScale = Settings:GetAttribute("EnvironmentSpecularScale")
		Lighting.GlobalShadows = Settings:GetAttribute("GlobalShadows")
		Lighting.OutdoorAmbient = Settings:GetAttribute("OutdoorAmbient")
		Lighting.ShadowSoftness = Settings:GetAttribute("ShadowSoftness")

		Lighting.ExposureCompensation = Settings:GetAttribute("ExposureCompensation")
	end
end

return LightLoader
