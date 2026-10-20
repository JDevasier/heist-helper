-- Release settings with an input-driven scrolling viewport.
-- Switches update their existing components in place.
local ScrollPanel = require("lib/scroll_panel")
local Menu = {}
local CONTENT_HEIGHT = 288
local INK, MUTED, GOLD = 0xE2E8EDFF, 0x9EAFBBFF, 0xD8C18FFF

function Menu.build(host, app)
    local layer, scroll, lastWidth, lastOverflow = nil, nil, nil, nil
    local function watch(component) return scroll:watch(component) end
    local function text(parent, value, x, y, width, height, colour)
        local label = watch(ui.Text.new(parent))
        label:SetPos(x, y)
        label:SetSize(width, height)
        label.font, label.content, label.rgba = id.Font.MUSEO_SANS_15PT_REGULAR, value, colour or INK
        label.clickthrough = true
        return label
    end

    local function fill(parent, x, y, width, height, colour)
        local rectangle = watch(ui.Rectangle.new(parent))
        rectangle:SetPos(x, y)
        rectangle:SetSize(width, height)
        rectangle.fill, rectangle.rgba, rectangle.clickthrough = true, colour, true
        return rectangle
    end

    local function button(parent, label, x, y, width, height, callback, selected)
        local control = watch(ui.Button.new(parent))
        control:SetPos(x, y)
        control:SetSize(width, height)
        control.stylesheetID, control.label = id.StyleSheet.BUTTON_DEFAULT, label
        control.text.font = id.Font.MUSEO_SANS_15PT_REGULAR
        control.canToggle = selected ~= nil
        if selected ~= nil then control.isToggled = selected end
        control:Subscribe(ui.Hook.ONBUTTONPRESSED, callback)
        return control
    end

    local function checkbox(parent, label, x, y, width, read, toggle, colour)
        local row = watch(ui.Layer.new(parent))
        row:SetPos(x, y)
        row:SetSize(width, 24)
        row.clickthrough = false
        local background = fill(row, 0, 0, width, 24, 0x24343F00)
        local mark = watch(ui.Sprite.new(row))
        mark:SetPos(2, 4)
        mark:SetSize(16, 16)
        mark.clickthrough = true
        local labelText = text(row, label, 25, 1, width - 27, 22)
        labelText.maxLines = 1
        local fallback = fill(row, 3, 5, 14, 14, 0x465662FF)
        local function sync()
            local enabled = read()
            local name = enabled and "RS3_BTN_CHECKBOX_SMALL_2" or "RS3_BTN_CHECKBOX_SMALL_0"
            local ok, sprite = pcall(function() return id.Sprite[name] end)
            mark.hidden = not ok or sprite == nil
            fallback.hidden = ok and sprite ~= nil
            if not mark.hidden then mark.sprite = sprite end
            mark.rgba = enabled and (colour or GOLD) or MUTED
            fallback.rgba = enabled and (colour or GOLD) or 0x465662FF
            labelText.rgba = enabled and INK or MUTED
        end
        row:Subscribe(ui.Hook.ONCLICK, function() toggle() sync() return false end)
        row:Subscribe(ui.Hook.ONMOUSEOVER, function() background.rgba = 0x2B3B47AA end)
        row:Subscribe(ui.Hook.ONMOUSELEAVE, function() background.rgba = 0x24343F00 end)
        sync()
        return row
    end

    local render
    render = function()
        local overflow = host.height < CONTENT_HEIGHT
        local width = math.max(240, host.width - (overflow and 24 or 0))
        lastWidth, lastOverflow = host.width, overflow
        if layer ~= nil then layer:Destroy() end
        layer = ui.Layer.new(host)
        layer:SetSize(0, 0, 1, 1)
        scroll = ScrollPanel.new(layer)
        local content = scroll.content
        text(content, "Heist Helper", 12, 4, width - 92, 22, GOLD)
        text(content, app.version, width - 66, 6, 56, 20, MUTED)
        local function card(y, height)
            local panel = watch(ui.Layer.new(content))
            panel:SetPos(12, y)
            panel:SetSize(width - 24, height)
            fill(panel, 0, 0, width - 24, height, 0x1B2933D9)
            return panel, width - 24
        end
        local overlay, overlayWidth = card(32, 52)
        text(overlay, "LOOT OVERLAY", 10, 5, overlayWidth - 20, 20, GOLD)
        checkbox(overlay, "Visible", 10, 26, overlayWidth - 146,
            function() return app.overlay.enabled end, app.toggleOverlay)
        button(overlay, "Reset position", overlayWidth - 128, 25, 118, 25, app.resetOverlayPosition)

        local highlights, highlightWidth = card(94, 184)
        text(highlights, "HIGHLIGHTS", 10, 7, highlightWidth - 108, 22, GOLD)
        checkbox(highlights, "Enabled", highlightWidth - 96, 6, 88,
            function() return app.highlights.enabled end, app.toggleHighlights)
        fill(highlights, 10, 37, highlightWidth - 20, 1, 0x354650FF)
        local available = highlightWidth - 28
        local leftColumn = math.floor(available * 0.44)
        for index, option in ipairs({
            { "chest", "Chests", 0xFFC247FF }, { "safe", "Safes", 0xC080FFFF },
            { "anchor", "Anchors", 0x60FF80FF }, { "door", "Doors", 0x60A8FFFF },
            { "control", "Controls", 0x60FF80FF }, { "walls", "Through walls", GOLD },
            { "labels", "Loot labels", GOLD }
        }) do
            local role = option[1]
            local right = index % 2 == 0
            checkbox(highlights, option[2], right and (18 + leftColumn) or 10,
                44 + math.floor((index - 1) / 2) * 24, right and (available - leftColumn) or leftColumn,
                function()
                    if role == "walls" then return app.highlights.throughWalls end
                    if role == "labels" then return app.highlights.labels.enabled end
                    return app.highlights.roles[role]
                end,
                function()
                    if role == "walls" then app.toggleThroughWalls()
                    elseif role == "labels" then app.toggleSourceLabels()
                    else app.toggleRole(role) end
                end, option[3])
        end
        local box3d, box2d
        local function syncBoxes()
            box3d.isToggled = app.highlights.displayType == "3d"
            box2d.isToggled = app.highlights.displayType == "2d"
        end
        local function chooseBoxes(mode) app.setDisplayType(mode) syncBoxes() end
        local modeX, modeWidth = 18 + leftColumn, math.floor((available - leftColumn - 6) / 2)
        box3d = button(highlights, "3D", modeX, 116, modeWidth, 24, function() chooseBoxes("3d") end, false)
        box2d = button(highlights, "2D", modeX + modeWidth + 6, 116, modeWidth, 24, function() chooseBoxes("2d") end, false)
        syncBoxes()
        text(highlights, "Completed", 10, 149, highlightWidth - 146, 26, MUTED)
        local hide, grey
        local function syncMode()
            hide.isToggled = app.highlights.completedMode == "hide"
            grey.isToggled = app.highlights.completedMode == "grey"
        end
        local function choose(mode)
            if app.highlights.completedMode ~= mode then app.toggleCompletedMode() end
            syncMode()
        end
        hide = button(highlights, "Hide", highlightWidth - 128, 148, 56, 26, function() choose("hide") end, false)
        grey = button(highlights, "Grey", highlightWidth - 68, 148, 58, 26, function() choose("grey") end, false)
        syncMode()
        scroll:setContentHeight(CONTENT_HEIGHT)
        -- Resize only rebuilds when available content width changes.
        layer:Subscribe(ui.Hook.ONRESIZE, function()
            if host.width ~= lastWidth or (host.height < CONTENT_HEIGHT) ~= lastOverflow then render()
            else scroll:layout() end
        end)
    end
    render()
end

return Menu
