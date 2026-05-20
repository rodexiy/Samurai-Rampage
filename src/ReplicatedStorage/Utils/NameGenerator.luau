local MaleNames = {
	"Jirō",
	"Tarō",
	"Saburō",
	"Gorō",
	"Heita",
	"Kinnosuke",
	"Daisuke",
	"Shinpei",
	"Gen",
	"Kōsuke",
	"Ichirō",
	"Tokichi",
	"Yūta",
	"Seiji",
	"Tetsuya",
	"Masao",
	"Hikaru",
	"Rokurō",
	"Shinji",
	"Kenzō",
}

local FemaleNames = {
	"Oume",
	"Oharu",
	"Otsu",
	"Okiku",
	"Osei",
	"Oshizu",
	"Oryō",
	"Oiyo",
	"Omasa",
	"Otsune",
	"Oaki",
	"Omi",
	"Otake",
	"Ohana",
	"Otama",
	"Ocho",
	"Omitsu",
	"Okane",
	"Osono",
	"Oyuki",
}

local LastNames = {
	"Tanaka",
	"Yamamoto",
	"Inoue",
	"Saito",
	"Kobayashi",
	"Ishikawa",
	"Fujita",
	"Murakami",
	"Shimada",
	"Nakamura",
	"Tsuchiya",
	"Kawamura",
	"Endō",
	"Okabe",
	"Hirano",
	"Sugiyama",
	"Hoshino",
	"Nozawa",
	"Kaneko",
	"Ogawa",
}

local NameGenerator = {}
function NameGenerator:Male(full: boolean)
	if full then
		return MaleNames[math.random(#MaleNames)] .. " " .. LastNames[math.random(#LastNames)]
	else
		return MaleNames[math.random(#MaleNames)]
	end
end

function NameGenerator:Female(full: boolean)
	if full then
		return FemaleNames[math.random(#FemaleNames)] .. " " .. LastNames[math.random(#LastNames)]
	else
		return FemaleNames[math.random(#FemaleNames)]
	end
end

return NameGenerator
