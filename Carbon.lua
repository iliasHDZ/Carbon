--args = { ... }

local EnvVarC = {
    update = {type = "event", list = {}},
    render = {type = "event", list = {}},
    exit = {type = "event", list = {}},
    stop = {type = "function"}
}

local function trigger(event, ...)
    if event.type == "event" then
        for i=1, #event.list do
            event.list[i](...)
        end
    end
end

--[[local Log = {
    init = function()
        local h = fs.open("Carbon.log", "w")
        h.writeLine("-- CARBON LOG --")
        h.close()
    end,
    i = function(msg)
        local h = fs.open("Carbon.log", "a")
        h.writeLine(msg)
        h.close()
    end
}

Log.init()]]

--local progEnv = cleanEnv
local running = true

local SCRN_W, SCRN_H = term.getSize()

local prevError = error

error = function(...)
    running = false
    return prevError(...)
end

EnvVarC.stop.call = function()
    running = false
end

local buffer = window.create(term.current(), 1, 1, SCRN_W, SCRN_H, false)

local draw = {
    clear = function(col)
        if col then
            buffer.setBackgroundColor(col)
        end
        buffer.clear()
    end,
    setCur = function(x, y)
        buffer.setCursorPos(x, y)
    end,
    setBG = function(col)
        buffer.setBackgroundColor(col)
    end,
    setTXT = function(col)
        buffer.setTextColor(col)
    end,
    rect = function(x, y, w, h, col)
        buffer.setBackgroundColor(col)
        for i=1, h do
            buffer.setCursorPos(x, y+i-1)
            buffer.write(string.rep(" ", w))
        end
    end,
    clipWrite = function(pos, size, text, multi)
        local ox, oy = buffer.getCursorPos()
        for i=1, #text do
            local x, y = buffer.getCursorPos()
            x, y = x-1, y-1
            if x >= math.floor(pos.X) and y >= math.floor(pos.Y) and x < math.floor(pos.X+size.X) and y < math.floor(pos.Y+size.Y) then
                buffer.write(text:sub(i, i))
            else
                buffer.setCursorPos(x+2, y+1)
            end
            if text:sub(i, i) == "\n" and multi then
                oy = oy + 1
                buffer.setCursorPos(ox, oy)
            end
        end
    end,
    swapBuffers = function()
        buffer.setVisible(true)
        buffer.setVisible(false)
    end,
    write = buffer.write
}

local defmeta

local cMetatable = {
    __index = function(tab, i)
        if EnvVarC[i] == nil then
            error("attempt to index a nil value (field '" .. i .. "')")
        else
            --print(EnvVarC[i].type)
            if getmetatable(EnvVarC[i]) == defmeta then
                return EnvVarC[i]
            end
            if EnvVarC[i].type == "event" then
                return function(func)
                    if type(func) == "function" then
                        table.insert(EnvVarC[i].list, func)
                    else
                        error("argument #1: function expected (got '" .. type(func) .. "')")
                    end
                end
            elseif EnvVarC[i].type == "function" then
                return EnvVarC[i].call
            end
        end
    end,
    __newindex = function(tab, i, val)
        error("attempt to change value of '"..i.."' (not possible)")
    end
}

--[[type = function(val)
    if type(val) == "table" and getmetatable(val) ~= nil and getmetatable(val).__type then
        return getmetatable(val).__type
    else
        return type(val)
    end
end]]

Uiv2 = {}

Uiv2 = {
    __meta = {
        __add = function(tab, val)
            if type(val) == "table" and getmetatable(val) == Uiv2.__meta then
                tab.X.Scale = tab.X.Scale + val.X.Scale
                tab.X.Offset = tab.X.Offset + val.X.Offset
                tab.Y.Scale = tab.Y.Scale + val.Y.Scale
                tab.Y.Offset = tab.Y.Offset + val.Y.Offset
                return tab
            else
                error("(+) operator: Uiv2 expected, got '" .. type(val) .. "'.")
            end
        end,
        __sub = function(tab, val)
            if type(val) == "table" and getmetatable(val) == Uiv2.__meta then
                tab.X.Scale = tab.X.Scale - val.X.Scale
                tab.X.Offset = tab.X.Offset - val.X.Offset
                tab.Y.Scale = tab.Y.Scale - val.Y.Scale
                tab.Y.Offset = tab.Y.Offset - val.Y.Offset
                return tab
            else
                error("(-) operator: Uiv2 expected, got '" .. type(val) .. "'.")
            end
        end,
        __type = "uiv2"
    },
    new = function(xs, xo, ys, yo)
        local new = {}
        new.X, new.Y = {}, {}
        new.X.Scale, new.X.Offset = xs, xo
        new.Y.Scale, new.Y.Offset = ys, yo

        setmetatable(new, Uiv2.__meta)

        return new
    end,
    scale = function(xs, ys)
        return Uiv2.new(xs, 0, ys, 0)
    end,
    offset = function(xo, yo)
        return Uiv2.new(0, xo, 0, yo)
    end
}

Vec2 = {}

Vec2 = {
    __meta = {
        __add = function(tab, val)
            if type(val) == "table" and getmetatable(val) == Vec2.__meta then
                tab.X = tab.X + val.X
                tab.Y = tab.Y + val.Y
                return tab
            else
                error("(+) operator: Vec2 expected, got '" .. type(val) .. "'.")
            end
        end,
        __sub = function(tab, val)
            if type(val) == "table" and getmetatable(val) == Vec2.__meta then
                tab.X = tab.X - val.X
                tab.Y = tab.Y - val.Y
                return tab
            else
                error("(-) operator: Vec2 expected, got '" .. type(val) .. "'.")
            end
        end,
        __type = "vec2"
    },
    new = function(x, y)
        local new = {}
        new.X, new.Y = x, y
        new.__type = "vec2"
        setmetatable(new, Vec2.__meta)

        return new
    end
}

local blink_x, blink_y, blink_col

local function setBlink(x, y, col)
    blink_x = x
    blink_y = y
    blink_col = col
end

local calcAbsolute

local Press = {
    RShift = false,
    LShift = false,
    RCtrl = false,
    LCtrl = false
}

function subStr(str, b, e)
    local res = ""
    for i=b, e-1 do
        res = res .. str:sub(i, i)
    end
    return res
end

local ObjectDB = {
    ["Instance"]={
        inh=nil,
        abstract=true,
		prp={
			Name={acc=true, type="string", def="Instance"},
			ClassName={acc=false, type="string", def="Instance"},
            Parent={acc=true, type="obj", def=nil},
            GetChildren={acc=false, type="function", def=function(self) return self.__UNTOUCHABLE.Children end},
            Destroy={acc=false, type="function", def=function(self)
                if self.Parent ~= nil then
                    self.Parent.__UNTOUCHABLE.Children[self.__INDEXINGID] = nil
                    for i=self.__INDEXINGID+1, #self.Parent.__UNTOUCHABLE.Children do
                        self.Parent.__UNTOUCHABLE.Children[i].__INDEXINGID = i-1
                        self.Parent.__UNTOUCHABLE.Children[i-1] = self.Parent.__UNTOUCHABLE.Children[i]
                        self.Parent.__UNTOUCHABLE.Children[i] = nil
                    end
                end
            end}
		}
	},["UIElement"]={
        inh="Instance",
        abstract=true,
		prp={
            Position={acc=true, type="uiv2", def=Uiv2.new(0, 0, 0, 0)},
            AbsolutePosition={acc=false, type="uiv2", def=function(obj) return calcAbsolute(obj, 0) end},
            Size={acc=true, type="uiv2", def=Uiv2.new(0, 0, 0, 0)},
            AbsoluteSize={acc=false, type="uiv2", def=function(obj) return calcAbsolute(obj, 1) end}
		}
	},["Main"]={
        inh="UIElement",
        abstract=true,
        update=function(obj, evn) end,
        render=function(obj)
            draw.clear(obj.BackgroundColor)
        end,
		prp={
            BackgroundColor={acc=true, type="number", def=colors.white}
        }
	},["TextLabel"]={
        inh="UIElement",
        abstract=false,
        update=function(obj, evn) end,
        render=function(obj)
            local absP = obj.AbsolutePosition
            local absS = obj.AbsoluteSize
            draw.rect(absP.X+1,  absP.Y+1, absS.X, absS.Y, obj.BackgroundColor)
            draw.setCur(absP.X+1, absP.Y+1)
            draw.setTXT(obj.TextColor)
            draw.clipWrite(absP, absS, obj.Text, true)
        end,
        prp={
            Size={acc=true, type="uiv2", def=Uiv2.new(0, 20, 0, 2)},
            BackgroundColor={acc=true, type="number", def=colors.white},
            TextColor={acc=true, type="number", def=colors.black},
            Text={acc=true, type="string", def="Label"}
        }
    },["TextButton"]={
        inh="UIElement",
        abstract=false,
        update=function(obj, evn)
            local size
            if obj.Size == nil then
                obj.Size = Uiv2.new(0, #obj.Text+2, 0, 1)
                size = obj.AbsoluteSize
                obj.__UNTOUCHABLE.Size = nil
            else
                size = obj.AbsoluteSize
            end
            local pos = obj.AbsolutePosition
            if evn[1] == "mouse_click" then
                local b, x, y = evn[2], evn[3]-1, evn[4]-1
                obj.__UNTOUCHABLE.Clicked = false
                if x >= math.floor(pos.X) and y >= math.floor(pos.Y) and x < math.floor(pos.X+size.X) and y < math.floor(pos.Y+size.Y) then
                    obj.__UNTOUCHABLE.Clicked = true
                    for i=1, #obj.__UNTOUCHABLE.OnPress do
                        obj.__UNTOUCHABLE.OnPress[i]()
                    end
                end
            elseif evn[1] == "mouse_up" then
                local b, x, y = evn[2], evn[3]-1, evn[4]-1
                if obj.Clicked then
                    obj.__UNTOUCHABLE.Clicked = false
                    if x >= math.floor(pos.X) and y >= math.floor(pos.Y) and x < math.floor(pos.X+size.X) and y < math.floor(pos.Y+size.Y) then
                        for i=1, #obj.__UNTOUCHABLE.OnClick do
                            obj.__UNTOUCHABLE.OnClick[i]()
                        end
                    end
                end
            end
        end,
        render=function(obj)
            local absS
            if obj.Size == nil then
                obj.Size = Uiv2.new(0, #obj.Text+2, 0, 1)
                absS = obj.AbsoluteSize
                obj.__UNTOUCHABLE.Size = nil
            else
                absS = obj.AbsoluteSize
            end
            local absP = obj.AbsolutePosition
            local txtcol, bgcol = obj.TextColor, obj.BackgroundColor
            if obj.Clicked then
                txtcol, bgcol = obj.ClickTextColor, obj.ClickBackgroundColor
            end
            draw.rect(absP.X+1,  absP.Y+1, absS.X, absS.Y, bgcol)
            draw.setCur(absP.X+2, absP.Y+1)
            draw.setTXT(txtcol)
            draw.clipWrite(absP, absS, obj.Text, false)
        end,
        prp={
            Size={acc=true, type="uiv2", def=nil},
            BackgroundColor={acc=true, type="number", def=colors.lightGray},
            TextColor={acc=true, type="number", def=colors.black},
            ClickBackgroundColor={acc=true, type="number", def=colors.blue},
            ClickTextColor={acc=true, type="number", def=colors.white},
            Clicked={acc=false, type="boolean", def=false},
            Text={acc=true, type="string", def="Button"},
            OnClick={acc=false, type="event", def={}},
            OnPress={acc=false, type="event", def={}}
        }
    },["Frame"]={
        inh="UIElement",
        abstract=false,
        update=function(obj, evn) end,
        render=function(obj)
            local absP = obj.AbsolutePosition
            local absS = obj.AbsoluteSize
            draw.rect(absP.X+1,  absP.Y+1, absS.X, absS.Y, obj.BackgroundColor)
            draw.setTXT(colors.black)
        end,
        prp={
            BackgroundColor={acc=true, type="number", def=colors.lightGray}
        }
    },["TextBox"]={
        inh="UIElement",
        abstract=false,
        update=function(obj, evn)
            local absP = obj.AbsolutePosition
            local absS = obj.AbsoluteSize
            absS.Y = 1
            if evn[1] == "mouse_click" then
                local b, x, y = evn[2], evn[3]-1, evn[4]-1
                if x >= math.floor(absP.X) and y >= math.floor(absP.Y) and x < math.floor(absP.X+absS.X) and y < math.floor(absP.Y+absS.Y) then
                    obj.__UNTOUCHABLE.Selected = true
                    obj.__UNTOUCHABLE.Cursor = math.floor(x-absP.X+1+obj.Scroll)
                else
                    obj.__UNTOUCHABLE.Selected = false
                    obj.__UNTOUCHABLE.Cursor = nil
                    obj.__UNTOUCHABLE.Scroll = 0
                end
                if obj.Selection then
                    obj.__UNTOUCHABLE.Selection = false
                    obj.__UNTOUCHABLE.SelectionBegin = 0
                    obj.__UNTOUCHABLE.SelectionEnd = 0
                end
            elseif evn[1] == "mouse_drag" then
                local b, x, y = evn[2], evn[3]-1, evn[4]-1
                if obj.Selected then
                    if not obj.Selection then
                        obj.__UNTOUCHABLE.SelectionBegin = obj.Cursor
                        obj.__UNTOUCHABLE.Selection = true
                    end
                    obj.__UNTOUCHABLE.SelectionEnd = math.floor(x-absP.X+1+obj.Scroll)
                    obj.__UNTOUCHABLE.Cursor = math.floor(x-absP.X+1+obj.Scroll)
                end
            elseif evn[1] == "char" then
                if obj.Selected and not(Press.RCtrl or Press.LCtrl) then
                    local txt
                    if obj.Selection then
                        txt = obj.__UNTOUCHABLE.Text
                        obj.__UNTOUCHABLE.Text = ""

                        local selb, sele = obj.SelectionBegin, obj.SelectionEnd
                        if obj.SelectionBegin > obj.SelectionEnd then
                            sele, selb = obj.SelectionBegin, obj.SelectionEnd
                        end
                        
                        for i = 1, #txt do
                            if not (i-1 >= selb and i-1 < sele) then
                                obj.__UNTOUCHABLE.Text = obj.__UNTOUCHABLE.Text .. txt:sub(i, i)
                            end
                        end

                        obj.__UNTOUCHABLE.Selection = false
                        obj.__UNTOUCHABLE.SelectionBegin = 0
                        obj.__UNTOUCHABLE.SelectionEnd = 0
                        obj.__UNTOUCHABLE.Cursor = selb
                    end
                    txt = obj.__UNTOUCHABLE.Text
                    obj.__UNTOUCHABLE.Text = subStr(txt, 1, obj.__UNTOUCHABLE.Cursor+1) .. evn[2] .. subStr(txt, obj.__UNTOUCHABLE.Cursor+1, #obj.Text+1)
                    if #txt == 0 then
                        obj.__UNTOUCHABLE.Text = evn[2]
                    end
                    obj.__UNTOUCHABLE.Cursor = obj.__UNTOUCHABLE.Cursor + 1
                end
            elseif evn[1] == "key" then
                if obj.Selected then
                    if evn[2] == keys.left then
                        local curCur = obj.__UNTOUCHABLE.Cursor
                        obj.__UNTOUCHABLE.Cursor = obj.__UNTOUCHABLE.Cursor - 1
                        if Press.RShift or Press.LShift then
                            if obj.Selection then
                                obj.__UNTOUCHABLE.SelectionEnd = obj.__UNTOUCHABLE.Cursor
                            else
                                obj.__UNTOUCHABLE.SelectionBegin = curCur
                                obj.__UNTOUCHABLE.SelectionEnd = obj.__UNTOUCHABLE.Cursor
                                obj.__UNTOUCHABLE.Selection = true
                            end
                        elseif obj.Selection then
                            obj.__UNTOUCHABLE.Selection = false
                            obj.__UNTOUCHABLE.SelectionBegin = 0
                            obj.__UNTOUCHABLE.SelectionEnd = 0
                            obj.__UNTOUCHABLE.Cursor = curCur
                        end
                    elseif evn[2] == keys.right then
                        local curCur = obj.__UNTOUCHABLE.Cursor
                        obj.__UNTOUCHABLE.Cursor = obj.__UNTOUCHABLE.Cursor + 1
                        if Press.RShift or Press.LShift then
                            if obj.Selection then
                                obj.__UNTOUCHABLE.SelectionEnd = obj.__UNTOUCHABLE.Cursor
                            else
                                obj.__UNTOUCHABLE.SelectionBegin = curCur
                                obj.__UNTOUCHABLE.SelectionEnd = obj.__UNTOUCHABLE.Cursor
                                obj.__UNTOUCHABLE.Selection = true
                            end
                        elseif obj.Selection then
                            obj.__UNTOUCHABLE.Selection = false
                            obj.__UNTOUCHABLE.SelectionBegin = 0
                            obj.__UNTOUCHABLE.SelectionEnd = 0
                            obj.__UNTOUCHABLE.Cursor = curCur
                        end
                    elseif evn[2] == keys.backspace then
                        if obj.__UNTOUCHABLE.Cursor ~= 0 and not obj.Selection then
                            local txt = obj.__UNTOUCHABLE.Text
                            obj.__UNTOUCHABLE.Text = ""
                            for i = 1, #txt do
                                if i ~= obj.__UNTOUCHABLE.Cursor then
                                    obj.__UNTOUCHABLE.Text = obj.__UNTOUCHABLE.Text .. txt:sub(i, i)
                                end
                            end
                            obj.__UNTOUCHABLE.Cursor = obj.__UNTOUCHABLE.Cursor - 1
                        end
                        if obj.Selection then
                            local txt = obj.__UNTOUCHABLE.Text
                            obj.__UNTOUCHABLE.Text = ""

                            local selb, sele = obj.SelectionBegin, obj.SelectionEnd
                            if obj.SelectionBegin > obj.SelectionEnd then
                                sele, selb = obj.SelectionBegin, obj.SelectionEnd
                            end
                            
                            for i = 1, #txt do
                                if not (i-1 >= selb and i-1 < sele) then
                                    obj.__UNTOUCHABLE.Text = obj.__UNTOUCHABLE.Text .. txt:sub(i, i)
                                end
                            end

                            obj.__UNTOUCHABLE.Selection = false
                            obj.__UNTOUCHABLE.SelectionBegin = 0
                            obj.__UNTOUCHABLE.SelectionEnd = 0
                            obj.__UNTOUCHABLE.Cursor = selb
                        end
                    elseif evn[2] == keys.enter then
                        obj.__UNTOUCHABLE.Selected = false
                        obj.__UNTOUCHABLE.Cursor = nil
                        obj.__UNTOUCHABLE.Scroll = 0
                    elseif evn[2] == keys.a then
                        if Press.RCtrl or Press.LCtrl then
                            if not obj.Selection then
                                obj.__UNTOUCHABLE.Selection = true
                            end
                            obj.__UNTOUCHABLE.Cursor = #obj.Text
                            obj.__UNTOUCHABLE.SelectionBegin = 0
                            obj.__UNTOUCHABLE.SelectionEnd = #obj.Text
                        end
                    end
                end
            elseif evn[1] == "paste" then
                if obj.Selected then
                    local txt
                    if obj.Selection then
                        txt = obj.__UNTOUCHABLE.Text
                        obj.__UNTOUCHABLE.Text = ""

                        local selb, sele = obj.SelectionBegin, obj.SelectionEnd
                        if obj.SelectionBegin > obj.SelectionEnd then
                            sele, selb = obj.SelectionBegin, obj.SelectionEnd
                        end
                        
                        for i = 1, #txt do
                            if not (i-1 >= selb and i-1 < sele) then
                                obj.__UNTOUCHABLE.Text = obj.__UNTOUCHABLE.Text .. txt:sub(i, i)
                            end
                        end

                        obj.__UNTOUCHABLE.Selection = false
                        obj.__UNTOUCHABLE.SelectionBegin = 0
                        obj.__UNTOUCHABLE.SelectionEnd = 0
                        obj.__UNTOUCHABLE.Cursor = selb
                    end
                    txt = obj.__UNTOUCHABLE.Text
                    obj.__UNTOUCHABLE.Text = subStr(txt, 1, obj.__UNTOUCHABLE.Cursor+1) .. evn[2] .. subStr(txt, obj.__UNTOUCHABLE.Cursor+1, #obj.Text+1)
                    if #txt == 0 then
                        obj.__UNTOUCHABLE.Text = evn[2]
                    end
                    obj.__UNTOUCHABLE.Cursor = obj.__UNTOUCHABLE.Cursor + #evn[2]
                end
            end
            if obj.Selection and obj.SelectionBegin == obj.SelectionEnd then
                obj.__UNTOUCHABLE.Selection = false
                obj.__UNTOUCHABLE.SelectionBegin = 0
                obj.__UNTOUCHABLE.SelectionEnd = 0
            end
            if obj.Selection then
                obj.__UNTOUCHABLE.SelectionBegin = math.min(math.max(obj.SelectionBegin, 0), #obj.Text)
                obj.__UNTOUCHABLE.SelectionEnd = math.min(math.max(obj.SelectionEnd, 0), #obj.Text)
            end
            if obj.Selected then
                obj.__UNTOUCHABLE.Cursor = math.min(math.max(obj.__UNTOUCHABLE.Cursor, 0), #obj.Text)
                if obj.Cursor-obj.Scroll >= absS.X then
                    obj.__UNTOUCHABLE.Scroll = obj.Scroll + obj.Cursor-obj.Scroll-(absS.X-1)
                elseif obj.Cursor-obj.Scroll < 0 then
                    obj.__UNTOUCHABLE.Scroll = obj.Scroll + (obj.Cursor-obj.Scroll)
                end
            end
        end,
        render=function(obj)
            local absP = obj.AbsolutePosition
            local absS = obj.AbsoluteSize
            absS.Y = 1
            if obj.Selected then
                draw.rect(absP.X+1,  absP.Y+1, absS.X, absS.Y, obj.SelectedBackgroundColor)
                draw.setCur(absP.X+1-obj.Scroll, absP.Y+1)
                draw.setTXT(obj.SelectedTextColor)
                setBlink(absP.X+obj.Cursor+1-obj.Scroll, absP.Y+1, obj.SelectedTextColor)
            else
                draw.rect(absP.X+1,  absP.Y+1, absS.X, absS.Y, obj.BackgroundColor)
                draw.setCur(absP.X+1-obj.Scroll, absP.Y+1)
                draw.setTXT(obj.TextColor)
            end
            if obj.Selection then
                local ox, oy = buffer.getCursorPos()
                for i=1, #obj.Text do
                    local xp, yp = buffer.getCursorPos()
                    xp, yp = xp-1, yp-1
                    local selb, sele = obj.SelectionBegin, obj.SelectionEnd
                    if obj.SelectionBegin > obj.SelectionEnd then
                        sele, selb = obj.SelectionBegin, obj.SelectionEnd
                    end
                    if i-1 >= selb and i-1 < sele then
                        draw.setBG(obj.SelectionBackgroundColor)
                        draw.setTXT(obj.SelectionTextColor)
                    else
                        draw.setBG(obj.SelectedBackgroundColor)
                        draw.setTXT(obj.SelectedTextColor)
                    end
                    if xp >= math.floor(absP.X) and yp >= math.floor(absP.Y) and xp < math.floor(absP.X+absS.X) and yp < math.floor(absP.Y+absS.Y) then
                        buffer.write(obj.Text:sub(i, i))
                    else
                        buffer.setCursorPos(xp+2, yp+1)
                    end
                end
            else
                draw.clipWrite(absP, absS, obj.Text, false)
            end
        end,
        prp={
            BackgroundColor={acc=true, type="number", def=colors.lightGray},
            TextColor={acc=true, type="number", def=colors.gray},
            SelectedBackgroundColor={acc=true, type="number", def=colors.lightGray},
            SelectedTextColor={acc=true, type="number", def=colors.black},
            Size={acc=true, type="uiv2", def=Uiv2.new(0, 15, 0, 1)},
            Text={acc=true, type="string", def="Text Value"},
            Selected={acc=true, type="boolean", def=false},
            Cursor={acc=false, type="number", def=nil},
            Scroll={acc=false, type="number", def=0},
            Selection={acc=false, type="boolean", def=false},
            SelectionBegin={acc=false, type="number", def=0},
            SelectionEnd={acc=false, type="number", def=0},
            SelectionBackgroundColor={acc=false, type="number", def=colors.lightBlue},
            SelectionTextColor={acc=false, type="number", def=colors.white}
        }
    },["Checkbox"]={
        inh="UIElement",
        abstract=false,
        update=function(obj, evn)
            local size = obj.AbsoluteSize
            local pos = obj.AbsolutePosition
            if evn[1] == "mouse_click" then
                local b, x, y = evn[2], evn[3]-1, evn[4]-1
                obj.__UNTOUCHABLE.Clicked = false
                if x >= math.floor(pos.X) and y >= math.floor(pos.Y) and x < math.floor(pos.X+size.X) and y < math.floor(pos.Y+size.Y) then
                    obj.__UNTOUCHABLE.Clicked = true
                    for i=1, #obj.__UNTOUCHABLE.OnPress do
                        obj.__UNTOUCHABLE.OnPress[i]()
                    end
                end
            elseif evn[1] == "mouse_up" then
                local b, x, y = evn[2], evn[3]-1, evn[4]-1
                if obj.Clicked then
                    obj.__UNTOUCHABLE.Clicked = false
                    if x >= math.floor(pos.X) and y >= math.floor(pos.Y) and x < math.floor(pos.X+size.X) and y < math.floor(pos.Y+size.Y) then
                        if obj.Checked then
                            obj.__UNTOUCHABLE.Checked = false
                        else
                            obj.__UNTOUCHABLE.Checked = true
                        end
                        for i=1, #obj.__UNTOUCHABLE.OnClick do
                            obj.__UNTOUCHABLE.OnClick[i](obj.__UNTOUCHABLE.Checked)
                        end
                    end
                end
            end
        end,
        render=function(obj, evn)
            local absS = obj.AbsoluteSize
            local absP = obj.AbsolutePosition
            local txtcol, bgcol = obj.TextColor, obj.BackgroundColor
            if obj.Clicked then
                bgcol = obj.ClickBackgroundColor
            end
            draw.rect(absP.X+1,  absP.Y+1, absS.X, absS.Y, bgcol)
            draw.setCur(absP.X+1, absP.Y+1)
            draw.setTXT(txtcol)
            if obj.Checked then
                draw.write(obj.Check:sub(1, 1))
            end
        end,
        prp={
            Size={acc=false, type="uiv2", def=Uiv2.new(0, 1, 0, 1)},
            BackgroundColor={acc=true, type="number", def=colors.gray},
            ClickBackgroundColor={acc=true, type="number", def=colors.lightGray},
            TextColor={acc=true, type="number", def=colors.white},
            Check={acc=true, type="string", def="x"},
            Clicked={acc=true, type="boolean", def=false},
            Checked={acc=true, type="boolean", def=false},
            OnClick={acc=false, type="event", def={}},
            OnPress={acc=false, type="event", def={}}
        }
    }
}

local function isInherit(cn1, cn2)
    if cn1 == cn2 then return true end
    local db1 = ObjectDB[cn1]
    if db1.inh ~= nil then
        return isInherit(db1.inh, cn2)
    else
        return false
    end
end

calcAbsolute = function(obj, type)
    local db = ObjectDB[obj.ClassName]
    local parPos = Vec2.new(0, 0)
    if obj.Parent ~= nil and type ~= 1 then
        parPos = calcAbsolute(obj.Parent, type)
    end
    if not isInherit(obj.ClassName, "UIElement") then
        return parPos
    else
        local parSize = Vec2.new(0, 0)
        if obj.Parent ~= nil then
            parSize = calcAbsolute(obj.Parent, 1)
        end
        if type == 0 then
            return parPos + Vec2.new(parSize.X * obj.Position.X.Scale + obj.Position.X.Offset, parSize.Y * obj.Position.Y.Scale + obj.Position.Y.Offset)
        else
            return parPos + Vec2.new(parSize.X * obj.Size.X.Scale + obj.Size.X.Offset, parSize.Y * obj.Size.Y.Scale + obj.Size.Y.Offset)
        end
    end
end

local function getPrp(cn, p)
    if ObjectDB[cn].inh ~= nil then
        local prp = getPrp(ObjectDB[cn].inh, p)
        if prp then
            return prp
        end
    end
    local propety = ObjectDB[cn].prp[p]
    if propety then
        return propety
    end
    return nil
end

defmeta = {
	__index = function(t, i)
        local prp = getPrp(t.__UNTOUCHABLE.ClassName, i)
        if prp ~= nil then
            if prp.type == "event" then
                return function(call)
                    if type(call) == "function" then
                        table.insert(t.__UNTOUCHABLE[i], call)
                    else
                        error("Function expected for event(, got " .. type(call) .. ").")
                    end
                end
            elseif prp and i~="Children" then
                if type(t.__UNTOUCHABLE[i]) == "function" and prp.type ~= "function" then
                    return t.__UNTOUCHABLE[i](t)
                else
                    return t.__UNTOUCHABLE[i]
                end
            else
                for k, v in ipairs(t.__UNTOUCHABLE.Children) do
                    if v.__UNTOUCHABLE.Name == i then
                        return v
                    end
                end
            end
        end
		error(i .. " is not a valid member of " .. t.__UNTOUCHABLE.ClassName)
	end,
    __newindex = function(t, i, v)
        local prp = getPrp(t.__UNTOUCHABLE.ClassName, i)
        if prp and i~="Children" and i~="Parent" then
			if (type(v) == prp.type) or (type(v) == "table" and getmetatable(v) ~= nil and getmetatable(v).__type == prp.type) then
                if prp.acc then
					t.__UNTOUCHABLE[i] = v
				else
					error("Cannot change property "..i.." in "..t.__UNTOUCHABLE.ClassName)
					return
				end
			else
				error("Invalid datatype for property "..i.." in "..t.__UNTOUCHABLE.ClassName)
				return
			end
		elseif i=="Parent" then
			if type(v)=="table" and getmetatable(v) == defmeta then
                t.__INDEXINGID = #v.__UNTOUCHABLE.Children + 1
				v.__UNTOUCHABLE.Children[t.__INDEXINGID] = t
                t.__UNTOUCHABLE.Parent = v
			else
				error("Invalid datatype for property Parent in "..t.__UNTOUCHABLE.ClassName)
			end
		end
    end,
    __type = "obj"
}

local function newObj(className)
    local obj={}
	if ObjectDB[className].inh ~= nil then
		obj = newObj(ObjectDB[className].inh)
    else
		obj.__INDEXINGID = 0
		obj.__UNTOUCHABLE={}
		obj.__UNTOUCHABLE.Children={}
	end
	for k,v in pairs(ObjectDB[className].prp) do
		obj.__UNTOUCHABLE[k] = v.def
    end
	obj.__UNTOUCHABLE.ClassName = className
	obj.__UNTOUCHABLE.Name = className
	setmetatable(obj, defmeta)
	return obj
end

main = newObj("Main")
main.Size = Uiv2.new(0, SCRN_W, 0, SCRN_H)

new = function(typ)
    if type(typ) ~= "string" then
        error("argument #1: string expected (got '" .. type(typ) .. "')")
        return
    end
    if ObjectDB[typ] == nil then
        error("ClassName '" .. typ .. "' does not exist.")
        return
    end
    if ObjectDB[typ].abstract then
        error("Cannot create instance of abstract ClassName '" .. typ .. "'.")
        return
    end
    return newObj(typ)
end

local function renderObj(obj)
    if isInherit(obj.ClassName, "UIElement") then
        ObjectDB[obj.ClassName].render(obj)
    end
    for k, v in ipairs(obj:GetChildren()) do
        renderObj(v)
    end
end

local function updateObj(obj, evn)
    if isInherit(obj.ClassName, "UIElement") then
        ObjectDB[obj.ClassName].update(obj, evn)
    end
    for k, v in ipairs(obj:GetChildren()) do
        updateObj(v, evn)
    end
end

local function render()
    renderObj(main)
    trigger(EnvVarC.render)

    draw.swapBuffers()
    if blink_x ~= nil then
        term.setCursorPos(blink_x, blink_y)
        term.setTextColor(blink_col)
        term.setCursorBlink(true)
        setBlink()
    else
        term.setCursorBlink(false)
    end
end

local function update(evn)
    if evn[1] == "key" then
        if evn[2] == keys.rightShift then
            Press.RShift = true
        elseif evn[2] == keys.leftShift then
            Press.LShift = true
        elseif evn[2] == keys.rightCtrl then
            Press.RCtrl = true
        elseif evn[2] == keys.leftCtrl then
            Press.LCtrl = true
        end
    elseif evn[1] == "key_up" then
        if evn[2] == keys.rightShift then
            Press.RShift = false
        elseif evn[2] == keys.leftShift then
            Press.LShift = false
        elseif evn[2] == keys.rightCtrl then
            Press.RCtrl = false
        elseif evn[2] == keys.leftCtrl then
            Press.LCtrl = false
        end
    end
    updateObj(main, evn)
    trigger(EnvVarC.update, table.unpack(evn))
end

function run()
    local evn = {"start"}
    while running do
        update(evn)
        render()
        evn = table.pack(os.pullEventRaw())
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    trigger(EnvVarC.exit)
end

function Initialize(env)
    local types = {"Uiv2", "Vec2"}
    env["c"] = env["Carbon"]
    env["Carbon"] = nil

    for i=1, #types do
        env[types[i]] = env["c"][types[i]]
        env["c"][types[i]] = nil
    end

    setmetatable(env["c"], cMetatable)

    return env
end

--local rane, err

--[[local function runFile(path)
    local mainCoroutine = coroutine.create(function()
        local funcy = loadFile(path)
        setfenv(funcy, progEnv)
        rane, err = pcall(funcy)
        running = rane
    end)
    coroutine.resume(mainCoroutine)

    local evn = {"start"}

    while running do
        update(evn)
        render()

        evn = table.pack(os.pullEventRaw())
    end

    term.setBackgroundColor(colors.black)
    term.setTextColor(colors.white)
    term.clear()
    term.setCursorPos(1, 1)

    if not rane then
        error("This program unexpectedly crashed.")
        error("Error: " .. err)
    end

    trigger(EnvVarC.exit)
end

local function printUsage()
    print("Usage: carbon <option> [...]")
    print("Options:      run <file>")
end

if #args == 2 then
    if args[1] == "run" then
        local path = args[2]
        if fs.exists(path) then
            runFile(path)
        else
            term.setTextColor(colors.red)
            print("[ Carbon ] This file does not exist.")
            term.setTextColor(colors.white)
        end
    else
        printUsage()
    end
else
    printUsage()
end]]