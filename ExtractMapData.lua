
local WOWDIR = "E:\\Games\\World of Warcraft"
local CDN = "http://us.patch.battle.net:1119/wow_beta/#eu"
local PRODUCT = "wow_beta" --  "wow", "wowt", "wow_classic"
local LOCALDB2 = false

local INFO = {
	["UIMapAssignment.db2"] = {
		table = "UIMapAssignment",
		fileId = 1957219,
		syntax = "4f6fuiiiiii",
		fields = {
			[1] = "id",
			[2] = "UIMin0",
			[3] = "UIMin1",
			[4] = "UIMax0",
			[5] = "UIMax1",
			[6] = "Region0",
			[7] = "Region1",
			[8] = "Region2",
			[9] = "Region3",
			[10] = "Region4",
			[11] = "Region5",
			--[12] = "id",
			[13] = "uiMapID",
			[14] = "OrderIndex",
			[15] = "MapID",
			[16] = "AreaID",
			[17] = "WMODoodadPlacementID",
			[18] = "WMOGroupID",
		},
	},
	["UIMap.db2"] = {
		table = "UIMap",
		fileId = 1957206,
		--syntax = "suuuuu.*",
		fields = {
			[1] = "id",
			[2] = "name",
			[4] = "parent",
			[5] = "flags",
			[6] = "system",
			[7] = "type",
		}
	}
}

-- continent lookup table (MapID -> uiMapID)
local Continents = {
	[0] = 13, -- EK
	[1] = 12, -- Kalimdor
	[530] = 101, -- Outlands
	[571] = 113, -- Northrend
	[870] = 424, -- Pandaria
	[1116] = 572, -- Draenor
	[1220] = 619, -- Broken Isles
	[1642] = 875, -- Zandalar
	[1643] = 876, -- Kul Tiras
	[2364] = 1550, -- Shadowlands
	[2444] = 1978, -- Dragon Isles
	[2552] = 2274, -- Khaz Algar
}

-- uiMapID -> MapID
local ContinentUIMapIDs = {
	[12] = 1, -- Kalimdor
	[13] = 0, -- Eastern Kingdoms
	[101] = 530, -- Outlands
	[113] = 571, -- Northrend
	[424] = 870, -- Pandaria
	[572] = 1116, -- Draenor
	[619] = 1220, -- Broken Isles
	[875] = 1642, -- Zandalar
	[876] = 1643, -- Kul Tiras
	[1550] = 2364, -- Shadowlands
	[1978] = 2444, -- Dragon Isles
	[2274] = 2552, -- Khaz Algar
	
	-- Classic/BC/Wrath
	[1414] = 1, -- Kalimdor
	[1415] = 0, -- EK
	[1945] = 530, -- Outlands
}

local keys = {
	["83a2ab72dd8ae992"] = "023cff062b19a529b9f14f9b7aaac5bb",
	["17f07c2e3a45db3d"] = "6D3886BDB91E715AE7182D9F3A08F2C9",
	-- ["a4541c671097d0bd"] = "0400000058465448FFFFFFFFFFFFFFFF",
}

local function printerr(pattern, ...)
	io.stderr:write(string.format(pattern .. "\n", ...))
end

local casc, dbc = require("casc"), require("dbc")

local cdnFlag = nil
local buildKey, cdnBase, cdnKey, version
if WOWDIR then
	local function selectBuild(buildInfo)
		for i=1,#buildInfo do
			if buildInfo[i].Product == PRODUCT and buildInfo[i].Active == 1 then
				return i
			end
			assert(0)
		end
	end

	buildKey, cdnBase, cdnKey, version = casc.localbuild(WOWDIR .. "\\.build.info", selectBuild)
	cdnFlag = false
	printerr("Build: %s", tostring(version))
end
local handle
if WOWDIR then
	local err
	handle, err = casc.open(WOWDIR, {locale = casc.locale.GB, verifyHashes = false, bkey = buildKey, keys = keys, zerofillEncryptedChunks = true})
	if not handle then
		printerr("Unable to open CASC, %s", err)
		return
	end
else
	local err
	handle, err = casc.open(CDN, {locale = casc.locale.GB, verifyHashes = false, keys = keys, zerofillEncryptedChunks = true})
	if not handle then
		printerr("Unable to open CASC, %s", err)
		return
	end
end

local function readFile(fileName, info)
	if not LOCALDB2 then
        return handle:readFile(info.fileId)
    else
        local f, err = io.open(fileName, "rb")
        if not f then return nil, err end
        local c = f:read("*all")
        f:close()
        return c
    end
end

local function process_row(info, ...)
	local id = (...)
	local entry = {}
	for index, field in pairs(info.fields) do
		entry[field] = (select(index, ...))
	end
	return id, entry
end

local function load_dbc(fileName, info)
	local t = {}
	_G[info.table] = t
	local data, err = readFile(fileName, info)
	if not data then printerr(err) end
	local iter, d, c = dbc.rows(data, info.syntax or "*?", true)
	while true do
		local id, entry = process_row(info, iter(d, c))
		if not id then
			break
		end
		t[id] = entry
		c = id
	end
end

for _file, info in pairs(INFO) do
	local status, error = pcall(load_dbc, _file, info)
	if not status then
		printerr("LOAD ERROR: %s, %s", _file, error)
	end
end

local T = {}
local W = {}
local C = {}
for _, t in pairs(UIMapAssignment) do
	local uiMapID = tonumber(t.uiMapID)
	local Order = tonumber(t.OrderIndex)
	if Order > 0 and (t.UIMin0 ~= 0 or t.UIMin1 ~= 0 or t.UIMax0 ~= 1 or t.UIMax1 ~= 1) then
		--printerr("Skipping entry %d/%d", uiMapID, Order)
	elseif T[uiMapID] then
		if T[uiMapID][1] ~= t.MapID or T[uiMapID][2] ~= t.Region0 or T[uiMapID][3] ~= t.Region1 or T[uiMapID][4] ~= t.Region3 or T[uiMapID][5] ~= t.Region4 then
			--printerr("Map %d Order %d does not match first order seen (have: %d %d %d %d %d, new: %d %d %d %d %d)", uiMapID, Order, T[uiMapID][1],T[uiMapID][2],T[uiMapID][3],T[uiMapID][4],T[uiMapID][5], t.MapID, t.Region0, t.Region1, t.Region3, t.Region4)
		end
	else
		T[uiMapID] = { t.MapID, t.Region0, t.Region1, t.Region3, t.Region4 }
	end
	-- azeroth world map
	if uiMapID == 947 then
		table.insert(W, t)
	end
	if ContinentUIMapIDs[uiMapID] and Order > 0 and t.AreaID == 0 then
		print(uiMapID, t.MapID)
		table.insert(C, t)
	end
end

local function ppf(f,p)
	if not p then p = 4 end
	return string.format("%." .. p .. "f", f):gsub("%.?0+$", "")
end

local S = { "local db2MapData = { " }
for id, t in pairs(T) do
	table.insert(S, string.format("[%d]={%d,%s,%s,%s,%s},", id, t[1], ppf(t[2]), ppf(t[3]), ppf(t[4]), ppf(t[5])))
end
table.insert(S, "}")
local str = table.concat(S)
-- uncomment to print db2 map data
-- print(str)

local function MapIDSorter(a,b) return a.MapID < b.MapID end

table.sort(W, MapIDSorter)
table.sort(C, MapIDSorter)

print()
print("WorldMapData follows")
print("-------------------------------")
for _, k in pairs(W) do
	if k.MapID and Continents[k.MapID] then
		local w = k.Region4 - k.Region1
		local h = k.Region3 - k.Region0
		local w_ui = k.UIMax0 - k.UIMin0
		local h_ui = k.UIMax1 - k.UIMin1
		local w2 = w / w_ui
		local h2 = h / h_ui
		local l2 = k.Region4 + w2 * k.UIMin0
		local t2 = k.Region3 + h2 * k.UIMin1
		print(string.format("        worldMapData[%d] = { %s, %s, %s, %s }", k.MapID, ppf(w2, 2), ppf(h2, 2), ppf(l2, 2), ppf(t2, 2)))
	end
end

print()
print("Transform Data follows")
print("-------------------------------")
print("    local transformData = {")
for _, k in pairs(C) do
	if k.MapID and k.MapID ~= T[k.uiMapID][1] then
		local w = k.Region4 - k.Region1
		local h = k.Region3 - k.Region0
		local w_ui = k.UIMax0 - k.UIMin0
		local h_ui = k.UIMax1 - k.UIMin1
		local w2 = w / w_ui
		local h2 = h / h_ui
		local l2 = k.Region4 + w2 * k.UIMin0
		local t2 = k.Region3 + h2 * k.UIMin1
		local offsetX = T[k.uiMapID][5] - l2
		local offsetY = T[k.uiMapID][4] - t2
		if true or math.abs(offsetX) > 0.1 or math.abs(offsetY) > 0.1 then
			--print(k.uiMapID,k.OrderIndex,k.MapID, T[k.uiMapID][1], offsetY, offsetX)
			print(string.format("        { %d, %d, %s, %s, %s, %s, %s, %s },",
			                     k.MapID, T[k.uiMapID][1], ppf(k.Region0, 2), ppf(k.Region3, 2), ppf(k.Region1, 2), ppf(k.Region4, 2), ppf(offsetY, 1), ppf(offsetX, 1)))
		end
	end
end
print("    }")
