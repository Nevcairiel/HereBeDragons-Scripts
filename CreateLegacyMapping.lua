
local WOWDIR = "E:\\Games\\World of Warcraft"
local CDN = "http://eu.patch.battle.net/wow/#eu"

local INFO = {
	["WorldMapArea.db2"] = {
		table = "WorldMapArea",
		fields = {
			[1] = "id",
			[2] = "mapFile",
		},
	}
}

local function printerr(pattern, ...)
	io.stderr:write(string.format(pattern .. "\n", ...))
end

local casc, dbc = require("casc"), require("dbc")

local cdnFlag = nil
if WOWDIR then
	local buildKey, cdnBase, cdnKey, version = casc.localbuild(WOWDIR .. "\\.build.info", casc.selectActiveBuild)
	cdnFlag = false
	printerr("Build: %s", tostring(version))
end

local handle = casc.open(WOWDIR or CDN, {locale = casc.locale.GB, verifyHashes = false, cdn = cdnFlag})

local function process_row(info, ...)
	local id = (...)
	local entry = {}
	for index, field in pairs(info.fields) do
		entry[field] = (select(index, ...))
	end
	return id, entry
end

local function load_dbc(file, info)
	file = "DBFilesClient/" .. file
	local t = {}
	_G[info.table] = t
	local data, err = handle:readFile(file)
	if not data then printerr(err) end
	local iter, d, c = dbc.rows(data, dbc.fields(data))
	while true do
		local id, entry = process_row(info, iter(d, c))
		if not id then
			break
		end
		t[id] = entry
		c = id
	end
end

for file, info in pairs(INFO) do
	local status, error = pcall(load_dbc, file, info)
	if not status then
		printerr("LOAD ERROR: %s, %s", file, error)
	end
end

local W = {}
for _, k in pairs(WorldMapArea) do
	if k.id and k.mapFile then
		W[k.id] = k.mapFile
	end
end

dofile("UIMapIDToWorldMapAreaID.lua")

local MapMigrationData = {}
for _, t in pairs(UIMapIDToWorldMapAreaID) do
	local mapAreaId = t[2]
	local floor = t[4]
	local uiMapId = t[1]
	if not MapMigrationData[mapAreaId] then
		MapMigrationData[mapAreaId] = { mapFile = W[mapAreaId] }
	end
	MapMigrationData[mapAreaId][floor] = uiMapId
end

print("local MapMigrationData = {")
for mapAreaId, t in pairs(MapMigrationData) do
	--print(t[1],t[2],t[4],W[t[2]])
	local floors = ""
	for k, v in pairs(t) do
		if k ~= "mapFile" then
			floors = floors .. string.format("%s[%d] = %d", floors:len() > 0 and ", " or "", k, v)
		end
	end
	if t.mapFile then
		print(string.format("    [%d] = { mapFile = \"%s\"%s%s},", mapAreaId, t.mapFile, floors:len() > 0 and ", " or "", floors))
	else
		print(string.format("    [%d] = {%s},", mapAreaId, floors))
	end
end
print("}")
