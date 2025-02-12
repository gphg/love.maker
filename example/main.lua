-- destination path
local sav = love.filesystem.getSaveDirectory()
local proj = love.filesystem.getIdentity()
local dest = sav.."/"..proj..".love"

love.maker = require("maker.init")
love.maker.setExtensions("lua", "txt", "png", "zip") -- include ONLY the selected formats
local build = love.maker.newBuild('C:/path/to/love/game/') -- love project directory (same as main.lua)
build:ignore('/readme.txt') -- ignore specific files or folders
build:ignoreMatch('^/.git') -- ignore based on pattern matching
build:allow("/images/exception.jpg") -- whitelist a specific file
build:save(dest, "DEMO") -- absolute path and comment/stamp
local stamp = love.maker.getComment(dest) -- get the stamp

love.system.openURL(sav)
