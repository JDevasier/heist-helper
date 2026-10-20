-- Arsenal definitions, separated by entity namespace.
local profile = { npc = {}, loc = {}, obj = {} }
local function add(kind, ids, role, source, state)
    for _, numericID in ipairs(ids) do
        profile[kind][numericID] = { role = role, source = source, state = state }
    end
end

add("loc", { 84214 }, "chest", "ordinary", "locked")
add("loc", { 84215 }, "chest", "ordinary", "open")
add("loc", { 86429 }, "chest", "ornate", "locked")
add("loc", { 86430 }, "chest", "ornate", "open")
add("loc", { 84176 }, "chest", "final", "locked")
add("loc", { 84177 }, "chest", "final", "open")
add("loc", { 134525 }, "safe", "safe", "locked")
add("loc", { 134526 }, "safe", "safe", "open")

-- Share the existing anchor switch for Arsenal's activation objects.
add("loc", { 84183, 84187 }, "anchor", "pylon", "off")
add("loc", { 84193 }, "anchor", "pylon", "on")
add("loc", { 84196 }, "anchor", "conduit", "off")
add("loc", { 84197 }, "anchor", "conduit", "on")

-- Guards and noninteractive objectives help identify the heist during discovery.
add("npc", { 7891 }, "guard", "siege-engine")
add("npc", { 14934 }, "guard", "siege-cannon")
add("npc", { 651 }, "guard", "keeper")
add("npc", { 652 }, "guard", "projection")
add("loc", { 134554 }, "security", "projector")
add("loc", { 84181 }, "control", "controls")
add("loc", { 84191 }, "objective", "tablet")
add("loc", { 84192 }, "objective", "lectern")
add("loc", { 134532 }, "door", "door", "locked")
add("loc", { 134533 }, "door", "door", "open")
add("loc", { 134527, 134528 }, "door", "door")
add("loc", { 84178 }, "barrier", "keeper-barrier")
add("loc", { 84179 }, "barrier", "barrier", "closed")
add("loc", { 84180, 84182 }, "barrier", "barrier")
add("loc", { 134548, 134550, 134549, 134551, 134546 }, "obstacle", "rubble")
add("loc", { 134534, 134535, 134536, 134537, 134538 }, "obstacle", "crevice")
add("loc", { 134545 }, "obstacle", "railing")
add("loc", { 134539, 134541, 134543 }, "obstacle", "handholds")
add("loc", { 134540, 134542, 134544 }, "obstacle", "dropdown")
add("loc", { 134547 }, "obstacle", "low-wall")
add("loc", { 84171, 84172, 84173 }, "entrance", "entrance")
add("loc", { 84174 }, "exit", "exit")
-- Fallback sizes apply only when native bounds are unavailable.
local doorMarker = { scale = 1, height = 1200 }
for _, numericID in ipairs({ 134527, 134528, 134532, 134533 }) do
    profile.loc[numericID].marker = doorMarker
end
profile.loc[84181].marker = { scale = 1, height = 700 }
return profile
