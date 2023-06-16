local lfs = love.filesystem
local src = lfs.getSource()
local lib = (...)
---@module "zapi"
local zapi = require(lib .. ".zapi")
---@module "minify"
local parser = require(lib .. ".minify")

local DONOTMATCH = {
	"^[/]%.git[/]",
	"^[/]node_modules[/]",
}

---@param s string
---@return string
local minify = function(s)
	local ast = parser.parse(s)
	parser.minify(ast)
	return parser.toLua(ast)
end

---@param path string
---@param func function
local function recursive(path, func)
	for _, ignore in ipairs(DONOTMATCH) do
		if path:match(ignore) then
			return
		end
	end
	if lfs.getInfo(path, "directory") then
		for _, item in pairs(lfs.getDirectoryItems(path)) do
			recursive(path .. "/" .. item, func)
		end
	end
	if lfs.getRealDirectory(path) == src then
		func(path)
	end
end

local maker = {}

---@param basePath? string
---@return Maker.Build
function maker.newBuild(basePath, ...)
	basePath = basePath or ""

	---@class Maker.Build
	local build = {}
	local files = { [""] = true }

	local tmp = string.format("tmp%x", love.math.random(65535))
	local file, err1 = lfs.newFile(tmp, "w")
	local zip = zapi.newZipWriter(file)

	---@param path string
	---@param mode? "minify"|"dump"
	local function addFileToZip(path, mode)
		local info = lfs.getInfo(path)
		if info and info.type ~= "file" then return end
		local data = lfs.read(path)
		if path:match("%.lua$") or path:match("%.ser$") then
			if mode == "minify" then
				data = minify(data, path, "minify")
			elseif mode == "dump" then
				data = string.dump(loadstring(data, path) --[[@as function]], true)
			end
		end
		if basePath ~= "" then
			path = path:gsub("^/" .. basePath, "")
		end
		if path:sub(1, 1) == "/" then path = path:sub(2, -1) end
		if path:sub(-1, -1) == "/" then path = path:sub(1, -2) end
		zip.addFile(path, data, info.modtime)
	end

	---@param path string
	function build:allow(path)
		files[path] = true
	end

	---@param path string
	function build:isAllowed(path)
		return files[path] == true
	end

	---@param path string
	function build:ignore(path)
		files[path] = nil
	end

	---@param pattern string
	function build:ignoreMatch(pattern)
		for item in pairs(files) do
			if item:match(pattern) then
				files[item] = nil
			end
		end
	end

	---@param dest string
	---@param comment? string
	---@param mode? string
	---@return boolean
	---@return number|string
	function build:save(dest, comment, mode)
		if not file then
			return false, err1
		end
		for path in pairs(files) do
			addFileToZip(path, mode)
		end
		zip.finishZip(comment)
		file:flush()
		local size = file:getSize()
		file:close()
		local ok, err2 = lfs.write(dest, lfs.read(tmp))
		lfs.remove(tmp)
		return ok, err2 or size
	end

	local allowed = { ... }
	if #allowed > 0 then
		for _, v in ipairs(allowed) do
			allowed[v:lower()] = true
		end
		recursive(basePath, function(path)
			path = path ~= "/" and path:sub(1, 1) ~= "/" and "/" .. path or path
			local ext = path:match("^.+%.(.+)$")
			if not ext or allowed[ext:lower()] then
				files[path] = true
			end
		end)
	else
		recursive(basePath, function(path)
			path = path ~= "/" and path:sub(1, 1) ~= "/" and "/" .. path or path
			files[path] = true
		end)
	end

	build.hasFile = files
	return build
end

---@param path string
---@return string?
---@return string?
function maker.getComment(path)
	path = path or lfs.getSource()
	local file, err = lfs.newFile(path, "r") --io.open(path, "rb")
	if not file then
		return nil, err
	end
	local comment
	local mode, size = file:getBuffer()
	local pos = file:seek(size - 22) --file:seek("end", -22)
	for i = pos, 0, -1 do
		file:seek(i) --file:seek("set", i)
		if file:read(4) == "\80\75\5\6" then
			file:seek(i + 22) --file:seek("set", i + 22)
			comment = file:read()--file:read("*all")
			break
		end
	end
	file:close()
	return comment
end

return maker
