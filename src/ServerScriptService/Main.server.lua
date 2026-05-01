--!strict

local ObbyGameLogic = require(script:WaitForChild("ObbyGameLogic"))

print("=== Frank the Tank OBBY Loading ===")

-- Course geometry is loaded via .model.json files in Workspace
-- Game logic handles: checkpoints, timer, fall detection, finish
ObbyGameLogic.setup()
print("Game logic initialized!")

print("=== Frank the Tank OBBY Ready! ===")
