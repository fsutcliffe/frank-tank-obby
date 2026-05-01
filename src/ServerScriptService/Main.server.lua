--!strict

local ObbyBuilder = require(script:WaitForChild("ObbyBuilder"))
local ObbyGameLogic = require(script:WaitForChild("ObbyGameLogic"))

print("=== Frank the Tank OBBY Loading ===")

-- Build the course
local movePlatforms = ObbyBuilder.build()
print("Obby course built successfully!")

-- Setup game logic with moving platform updater
ObbyGameLogic.setup(movePlatforms)
print("Game logic initialized!")

print("=== Frank the Tank OBBY Ready! ===")
