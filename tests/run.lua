-- Runs the Syncline tests outside the game. From the repo root: lua5.1 tests/run.lua
dofile("tests/wowstub.lua")
local ok, err = xpcall(function() dofile("tests/run_tests.lua") end, debug.traceback)
if not ok then
    REAL_PRINT("FAILED: " .. tostring(err))
    for i = math.max(1, #LOG - 8), #LOG do REAL_PRINT("  " .. LOG[i]) end
    os.exit(1)
end
REAL_PRINT(LOG[#LOG])
