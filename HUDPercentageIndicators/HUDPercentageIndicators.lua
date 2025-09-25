local ADDON_NAME, core = ...

local OPACITY = 0.7
local SIZE = 25
local FONT = "Interface\\addons\\"..ADDON_NAME.."\\fonts\\trebucbd.ttf"
local DEF_RED, DEF_GREEN, DEF_BLUE = 1, 0.7, 0.3

local min, max, abs, strf, ceil, modf = 
  math.min, math.max, math.abs, string.format, math.ceil, math.modf
local select, pairs, ipairs, unpack = select, pairs, ipairs, unpack

local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitPowerType = UnitPowerType
local UnitGUID = UnitGUID
local UIFrameFadeIn, UIFrameFadeOut = UIFrameFadeIn, UIFrameFadeOut
local GetUnitSpeed = GetUnitSpeed
local UnitMana, UnitManaMax = UnitMana, UnitManaMax
local GetTime = GetTime
local UnitIsDeadOrGhost = UnitIsDeadOrGhost

local frames, cfg = {}, {}
local curManaPercentAnnounceTime = {}

local tmp = {
  ["Health"] = "Interface\\addons\\"..ADDON_NAME.."\\texture\\healer_white2.tga",
  ["Power"]  = "Interface\\addons\\"..ADDON_NAME.."\\texture\\power.tga",
  ["Speed"]  = "Interface\\addons\\"..ADDON_NAME.."\\texture\\speed.tga",
  ["TargetSpeed"]  = "Interface\\addons\\"..ADDON_NAME.."\\texture\\target.tga",
}

local function UnitManaPercent(unit)
  return (UnitMana("player") / UnitManaMax("player")) *100
end

-- ключ(то что в квадратных скобках) - процент маны для анонса
-- значение(после знака равно) - кд анонса в секундах
local trackPercentValues = { 
  [20] = 10,
  [50] = 30, 
}

local f = CreateFrame("frame") 
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("UNIT_MANA")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) end end)

function f:PLAYER_ENTERING_WORLD(...)
  wipe(curManaPercentAnnounceTime)
  for perc, _cd in pairs(trackPercentValues) do
    curManaPercentAnnounceTime[perc] = {
      nextTime = GetTime() + 2,
      curPercentWasAbove = (UnitManaPercent("player") >= perc),
      cd = _cd,
    }
  end
end

function f:UNIT_MANA(...)
  if ... == "player" and not UnitIsDeadOrGhost("player") and UnitManaMax("player") > 0 then
    local manaPercent = UnitManaPercent("player")
    local time = GetTime()
    
    for perc, v in pairs(curManaPercentAnnounceTime) do
      if manaPercent < perc and v.curPercentWasAbove and v.nextTime < time then
        curManaPercentAnnounceTime[perc].nextTime = time + v.cd
        PlaySoundFile("interface\\addons\\"..ADDON_NAME.."\\sounds\\mana"..perc..".mp3")
      end
      curManaPercentAnnounceTime[perc].curPercentWasAbove = (manaPercent >= perc)
    end
  end
end

function f:PLAYER_TARGET_CHANGED()
  if not frames["TargetSpeed"] then return end
  if UnitGUID("target") then
    frames["TargetSpeed"]:Show()
  else
    frames["TargetSpeed"]:Hide()
  end
end

local function StartMoving(self)
  if not IsShiftKeyDown() then return end
  self:StartMoving()
end

local function StopMoving(self)
  self:StopMovingOrSizing()
end

local function testflash(self, speed, minalpha)
  if not UIFrameIsFading(self) then
    if self:GetAlpha() <= (minalpha+0.01) then
      UIFrameFadeIn(self, speed, minalpha, cfg["opacity"] or OPACITY)
    elseif self:GetAlpha() >= ((cfg["opacity"] or OPACITY) - 0.01) then
      UIFrameFadeOut(self, speed, cfg["opacity"] or OPACITY, minalpha)
    end
  end
end

local frameNum = 0

for frameName,tex in pairs(tmp) do
  local f = CreateFrame("frame", ADDON_NAME.."_HUD_"..frameName.."_Frame", UIParent) 
  frames[frameName]=f
  f:SetMovable(true)
  f:EnableMouse(false)
  f:EnableMouseWheel(false)
  f:SetSize(cfg["size"] and cfg["size"]*3 or SIZE*3, cfg["size"] or SIZE)
  f:SetFrameStrata("high")
  f:SetClampedToScreen(true)

  f:RegisterEvent("MODIFIER_STATE_CHANGED")
  f:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) end end)

  f:SetScript("OnMouseDown", StartMoving)
  f:SetScript("OnMouseUp", StopMoving)

  function f:MODIFIER_STATE_CHANGED(...)
    if arg2==1 then
      f:EnableMouse(true)
      f:EnableMouseWheel(true)
    else
      StopMoving(f)
      f:EnableMouse(false)
      f:EnableMouseWheel(false)
    end
  end
  
  f:SetScript("OnMouseWheel", function(self, delta) 
    if not IsShiftKeyDown() then return end
    if (delta==1) then
      cfg["size"]=ceil(self:GetHeight()+2)
      self:SetSize(cfg["size"]*3, cfg["size"])
      local texNewSize = self.tex:GetWidth()+2
      self.tex:SetSize(texNewSize, texNewSize)
      self.text:SetFont(FONT, select(2,self.text:GetFont())+2)
    elseif (delta==-1) then
      cfg["size"]=ceil(self:GetHeight()-2)
      self:SetSize(cfg["size"]*3, cfg["size"])
      local texNewSize = self.tex:GetWidth()-2
      self.tex:SetSize(texNewSize, texNewSize)
      self.text:SetFont(FONT, select(2,self.text:GetFont())-2)
    end
  end)
  
  f.tex = f:CreateTexture(nil, "OVERLAY")
  f.tex:SetTexture(tex)
  f.tex:SetPoint("left", 0, 0)
  f.tex:SetVertexColor(1, 1, 1)
  f.tex:SetSize((cfg["size"] or SIZE)-8, (cfg["size"] or SIZE)-8)
  f.tex:SetAlpha(cfg["opacity"] or OPACITY)
  
  f.text = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  f.text:SetPoint("left", f.tex, "right", 2, 0)
  f.text:SetTextColor(DEF_RED, DEF_GREEN, DEF_BLUE)
  f.text:SetFont(FONT, cfg["size"] or SIZE)
  f.text:SetAlpha(cfg["opacity"] or OPACITY)
  
  if cfg["font_shadow"] then
    f.text:SetShadowOffset(1,-1)
  else
    f.text:SetShadowOffset(0,0)
  end
end

frames["Health"]:SetPoint("CENTER",-120,0)
frames["Power"]:SetPoint("CENTER",120,0)
frames["Speed"]:SetPoint("CENTER",0,-120)
frames["TargetSpeed"]:SetPoint("CENTER",UIParent,"TOP",0,0)
frames["TargetSpeed"]:Hide()

-- health
do  
  local t, r, g, b, hpPerc, lowHp = 0
  
  frames["Health"]:SetScript("onupdate",function(f,e)
    t = t+e
    if t < 0.1 then return end
    t = 0
    
    if not cfg["enable_hp"] then
      f:SetScript("onupdate",nil)
      f:Hide()
      f=nil
      return
    end
    
    hpPerc = min((UnitHealth("player") / UnitHealthMax("player")) *100, 100)

    if cfg["color_gradient"] then
      if hpPerc>=100 then
        r, g, b = 0, 1, 0
      elseif hpPerc>=95 then
        r, g, b = 0.3, 1, 0.1
      elseif hpPerc>=85 then
        r, g, b = 0.6, 1, 0.1
      elseif hpPerc>=65 then
        r, g, b = 1, 1, 0.1
      elseif hpPerc>=45 then
        r, g, b = 1, 0.6, 0.1
      elseif hpPerc>=25 then
        r, g, b = 1, 0.3, 0.1
      else
        r, g, b = 1, 0, 0
      end
    else
      r, g, b = DEF_RED, DEF_GREEN, DEF_BLUE
    end
    
    f.text:SetTextColor(r, g, b)
    
    f.text:SetText(strf("%.0f", hpPerc))
    
    if cfg["flash_on_low_hp"] then
      if hpPerc>=25 and hpPerc<45 then
        lowHp=true
        testflash(f.tex, min((cfg["opacity"] or OPACITY), 0.7), min((cfg["opacity"] or OPACITY), 0.4))
      elseif hpPerc<25 then
        lowHp=true
        testflash(f.tex, min((cfg["opacity"] or OPACITY), 0.5), min((cfg["opacity"] or OPACITY), 0.33))
      elseif lowHp then
        lowHp=nil
        UIFrameFadeIn(f.tex, 0.1, f.tex:GetAlpha(), cfg["opacity"] or OPACITY)
      end
    end

    f.tex:SetVertexColor(r, g, b, f.tex:GetAlpha())
    f.text:SetAlpha(cfg["opacity"] or OPACITY)
  end)
end

-- power
do  
  local t, r, g, b, powPerc, _powPerc, curPower, lowMana = 0
  local powerType = UnitPowerType("player")

  frames["Power"]:SetScript("onupdate",function(f,e)
    t = t+e
    if t < 0.1 then return end
    t = 0

    if not cfg["enable_power"] then
      f:SetScript("onupdate",nil)
      f:Hide()
      f=nil
      return
    end
    
    powerType = UnitPowerType("player")
    curPower = UnitPower("player")
    powPerc = (powerType==6 or powerType==1 or powerType==2 or powerType==3) and curPower or (curPower / UnitPowerMax("player")) *100

    if cfg["color_gradient"] then
      r, g, b = PowerBarColor[powerType].r, PowerBarColor[powerType].g, PowerBarColor[powerType].b
    else
      r, g, b = DEF_RED, DEF_GREEN, DEF_BLUE
    end

    f.text:SetTextColor(r, g, b)
    f.tex:SetVertexColor(r, g, b)
    f.text:SetText(strf("%.0f", powPerc))
    
    f.text:SetAlpha(cfg["opacity"] or OPACITY)

    if powPerc>=90 then
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\power100.tga")
    elseif powPerc>=70 then
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\power75.tga")
    elseif powPerc>=50 then
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\power50.tga")
    elseif powPerc>=25 then
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\power25.tga")
    elseif powPerc>=0 then
      if powerType==0 and cfg["flash_on_low_mana"] then
        lowMana=true
        testflash(f.tex, 0.5, 0.3)
      end
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\power0.tga")
    end
    
    if lowMana and powPerc>=25 then
      lowMana=nil
      UIFrameFadeIn(f.tex, 0.1, f.tex:GetAlpha(), cfg["opacity"] or OPACITY)
    end
  end)
end

-- speed
do  
  local gradientColor = { 0, 1, 0, 1, 1, 0, 1, 0, 0 }
  
  local gradientColorGrayYellow = { 169/255, 169/255, 169/255, 1, 1, 0, 1 }  -- от серого к желтому
  
  local gradientColorWhiteRed = { 1, 1, 1,  1, 0, 0 }  -- от серого к желтому
  
  local gradientColorGrayWhite = { 0.75, 0.75, 0.75,  1, 1, 1 }  -- от серого (0.5, 0.5, 0.5) к белому (1, 1, 1)

  local function ColorGradient(perc, ...)
    if (perc > 1) then
      local r, g, b = select(select("#", ...) - 2, ...)
      return r, g, b
    elseif (perc < 0) then
      local r, g, b = ...
      return r, g, b
    end

    local num = select("#", ...) / 3

    local segment, relperc = modf(perc * (num - 1))
    local r1, g1, b1, r2, g2, b2 = select((segment * 3) + 1, ...)

    if r2 == nil then r2 = 1 end
    if g2 == nil then g2 = 1 end
    if b2 == nil then b2 = 1 end

    return r1 + (r2 - r1) * relperc, g1 + (g2 - g1) * relperc, b1 + (b2 - b1) * relperc
  end

  local function RGBGradient(num)
    local r, g, b = ColorGradient(num, unpack(gradientColor))
    return r, g, b
  end
  
  local function GradientGreyYellow(num)
    local r, g, b = ColorGradient(num, unpack(gradientColorGrayYellow))
    return r, g, b
  end
  
  local function GradientWhiteRed(num)
    local r, g, b = ColorGradient(num, unpack(gradientColorWhiteRed))
    return r, g, b
  end
  
  local function GradientGrayWhite(num)
    local r, g, b = ColorGradient(num, unpack(gradientColorGrayWhite))
    return r, g, b
  end
  
  frames["Speed"]:SetScript("onupdate",function(f,e)
    f.t = f.t and f.t+e or 0
    if f.t < 0.01 then return end
    f.t = 0
    
    if not cfg["target_speed"] then
      f:SetScript("onupdate",nil)
      f:Hide()
      f=nil
      return
    end
    
    local r, g, b
    
    local speedPerc = (GetUnitSpeed("player") / 7) *100
    
    if cfg["color_gradient"] then
      if speedPerc >= 130 then
        r, g, b = RGBGradient(1 - speedPerc / 200)
      elseif speedPerc > 100 then
        r, g, b = 1, 0.9, 0.1
      elseif speedPerc == 100 then
        r, g, b = 1, 1, 0.9
      elseif speedPerc > 50 then
        r, g, b = 1, 0.5, 0
      elseif speedPerc > 0 then
        r, g, b = 1, 0.1, 0.1
      elseif speedPerc == 0 then 
        r, g, b = 0.7, 0.7, 0.7
      end
    else  
      r, g, b = DEF_RED, DEF_GREEN, DEF_BLUE
    end
    
    f.text:SetTextColor(r, g, b)
    f.text:SetText(strf("%d", speedPerc))
    
    if speedPerc >= 200 --[[and not IsMounted()]] then
      f.flashing=true
      f.tex:SetVertexColor(1, 1, 1)
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\flash.tga")
      testflash(f.tex, min((cfg["opacity"] or OPACITY), 0.4), min((cfg["opacity"] or OPACITY), 0.2))
    else
      if f.flashing then
        f.flashing=nil
        f.tex:SetTexture(tmp["Speed"])
        UIFrameFadeIn(f.tex, 0.1, f.tex:GetAlpha(), cfg["opacity"] or OPACITY)
      end
      f.tex:SetVertexColor(r, g, b)
    end
    
    f.text:SetAlpha(cfg["opacity"] or OPACITY)
  end)
  
  frames["TargetSpeed"]:SetScript("onupdate",function(f,e)
    f.t = f.t and f.t+e or 0
    if f.t < 0.01 then return end
    f.t = 0
    
    if not cfg["enable_speed"] then
      f:SetScript("onupdate",nil)
      f:Hide()
      f=nil
      return
    end
    
    local r, g, b
    
    local speedPerc = (GetUnitSpeed("target") / 7) *100
    
    if cfg["color_gradient"] then
      if speedPerc >= 130 then
        r, g, b = RGBGradient(1 - speedPerc / 150)
      elseif speedPerc > 100 then
        r, g, b = 1, 0.9, 0.1
      elseif speedPerc == 100 then
        r, g, b = 0.9, 0.9, 0.9
      elseif speedPerc > 50 then
        r, g, b = 1, 0.5, 0.1
      elseif speedPerc > 0 then
        r, g, b = 1, 0.1, 0.1
      elseif speedPerc == 0 then 
        r, g, b = 0.7, 0.7, 0.7
      end
    else  
      r, g, b = DEF_RED, DEF_GREEN, DEF_BLUE
    end
    
    if speedPerc >= 250 then
      f.flashing=true
      f.tex:SetTexture("Interface\\addons\\"..ADDON_NAME.."\\texture\\flash.tga")
      testflash(f.tex, min((cfg["opacity"] or OPACITY), 0.4), min((cfg["opacity"] or OPACITY), 0.2))
    else
      if f.flashing then
        f.flashing=nil
        f.tex:SetTexture(tmp["TargetSpeed"])
        UIFrameFadeIn(f.tex, 0.1, f.tex:GetAlpha(), cfg["opacity"] or OPACITY)
      end
      f.tex:SetVertexColor(r, g, b)
    end
    
    f.text:SetTextColor(r, g, b)
    f.text:SetText(strf("%d", speedPerc))
    
    f.text:SetAlpha(cfg["opacity"] or OPACITY)
  end)
end

-- опции
local options =
{
  {"enable_hp","Индикатор хп (для повторного включения нид перезагрузка интерфейса)",nil,true},
  {"enable_power","Индикатор ресурса (нид перезагрузка интерфейса)",nil,true},
  {"enable_speed","Индикатор скорости передвижения (нид перезагрузка интерфейса)",nil,true},
  {"color_gradient","Градиент цвета",nil,false},
  {"opacity","Прозрачность (от 0.1 до 1)",nil,0.7,0.1,1},
  {"size","Размер (дефолт: 25)",nil,25,10,100},
  {"font_shadow","Тень под шрифтом",nil,false},
  {"flash_on_low_mana","Мигание когда лоу мана",nil,true},
  {"flash_on_low_hp","Мигание когда лоу хп",nil,true},
  {"target_speed","Индикатор скорости цели (для повторного включения нид перезагрузка интерфейса)",nil,true},
}

function core:UpdateVisual()
  for frameName,frame in pairs(frames) do
    local size = cfg["size"] or SIZE
    local opacity = cfg["opacity"] or OPACITY
    
    frame:SetSize(size*3, size)
    frame.tex:SetSize(size-8, size-8)
    
    frame.text:SetFont(FONT, size)
    
    frame.tex:SetAlpha(opacity)
    frame.text:SetAlpha(opacity)
    
    if cfg["font_shadow"] then
      frame.text:SetShadowOffset(1,-1)
    else
      frame.text:SetShadowOffset(0,0)
    end
  end
end

function core:initConfig()
  cfg = mrcatsoul_HUD_Settings or {}

  -- [1] - settingName, [2] - checkboxText, [3] - tooltipText, [4] - значение по умолчанию, [5] - minValue, [6] - maxValue  
  for _,v in ipairs(options) do
    if cfg[v[1]]==nil then
      if type(v[2])=="table" then
        core.cfg[v[1]]={}
        print("table "..v[1].." created")
      else
        cfg[v[1]]=v[4]
        print(""..v[1]..": "..tostring(cfg[v[1]]).." (задан параметр по умолчанию)")
      end
    end
  end

  if mrcatsoul_HUD_Settings == nil then
    mrcatsoul_HUD_Settings = cfg
    cfg = mrcatsoul_HUD_Settings
    print("Инициализация дефолтного конфига")
  end
  
  core:UpdateVisual()
  
  core:CreateOptions()
end

function core:CreateOptions()
  if core.options then return end
  core.options=true
  core.optNum=0
  
  -- вроде отныне не говнокод для интерфейса настроек (27.1.25)
  -- [1] - settingName, [2] - checkboxText, [3] - tooltipText, [4] - значение по умолчанию, [5] - minValue, [6] - maxValue 
  for i,v in ipairs(options) do
    if v[4]~=nil then
      --print(v[1],type(v[4]),v[4])
      if type(v[4])=="boolean" then
        --print(v[1],v[4])
        core:createCheckbox(v[1], v[2], v[3], core.optNum)
        if options[i+1] and type(options[i+1][4])=="number" then
          core.optNum=core.optNum+3
        else
          core.optNum=core.optNum+2
        end
      elseif type(v[4])=="number" then
        --print(v[1])
        core:createEditBox(v[1], v[2], v[3], v[5], v[6], core.optNum)
        if options[i+1] and type(options[i+1][4])=="boolean" then
          core.optNum=core.optNum+1.5
        else
          core.optNum=core.optNum+2
        end
      end
    end
  end
end

--------------------------------------------------------------------------------
-- фрейм прокрутки для фрейма настроек. нужен чтобы прокручивать настройки вверх-вниз
--------------------------------------------------------------------------------
local width, height = 800, 1000
local settingsScrollFrame = CreateFrame("ScrollFrame", ADDON_NAME.."SettingsScrollFrame", InterfaceOptionsFramePanelContainer, "UIPanelScrollFrameTemplate")
settingsScrollFrame.name = GetAddOnMetadata(ADDON_NAME, "Title")  -- Название во вкладке интерфейса
settingsScrollFrame:SetSize(width, height)
settingsScrollFrame:Hide()
settingsScrollFrame:SetVerticalScroll(10)
settingsScrollFrame:SetHorizontalScroll(10)
_G[ADDON_NAME.."SettingsScrollFrameScrollBar"]:SetPoint("topleft",settingsScrollFrame,"topright",-25,-25)
_G[ADDON_NAME.."SettingsScrollFrameScrollBar"]:SetFrameLevel(1000)
_G[ADDON_NAME.."SettingsScrollFrameScrollBarScrollDownButton"]:SetPoint("top",_G[ADDON_NAME.."SettingsScrollFrameScrollBar"],"bottom",0,7)

--------------------------------------------------------------------------------
-- фрейм настроек который должен быть помещен в фрейм прокрутки
--------------------------------------------------------------------------------
local settingsFrame = CreateFrame("button", nil, InterfaceOptionsFramePanelContainer)
settingsFrame:Hide()
settingsFrame:SetSize(width, height) -- Измените размеры фрейма настроек ++ 4.3.24
settingsFrame:SetAllPoints(InterfaceOptionsFramePanelContainer)

settingsFrame:RegisterEvent("ADDON_LOADED")
settingsFrame:SetScript("OnEvent", function(self, event, ...) if self[event] then self[event](self, ...) end end)
function settingsFrame:ADDON_LOADED(addon)
  if addon==ADDON_NAME then
    core:initConfig()
  end
end

--------------------------------------------------------------------------------
-- связываем скролл-фрейм с фреймом настроек в котором все опции
--------------------------------------------------------------------------------
settingsScrollFrame:SetScrollChild(settingsFrame)

--------------------------------------------------
-- регистрируем фрейм настроек в близ настройках интерфейса (интерфейс->модификации) этой самой функцией 
--------------------------------------------------
InterfaceOptions_AddCategory(settingsScrollFrame)

--------------------------------------------------------------------------------
-- при показе/скрытии скролл-фрейма - показывается/скрывается фрейм настроек
--------------------------------------------------------------------------------
settingsScrollFrame:SetScript("OnShow", function()
  settingsFrame:Show()
end)

settingsScrollFrame:SetScript("OnHide", function()
  settingsFrame:Hide()
end)

--------------------------------------------------------------------------------
-- заголовок фрейма опций
--------------------------------------------------------------------------------
do
  local text = settingsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  text:SetPoint("TOPLEFT", 16, -16)
  text:SetFont(GameFontNormal:GetFont(), 24, 'OUTLINE')
  text:SetText(GetAddOnMetadata(ADDON_NAME, "Title"))
  text:SetJustifyH("LEFT")
  text:SetJustifyV("BOTTOM")
  settingsFrame.TitleText = text
end

--------------------------------------------------------------------------------
-- тултип (подсказка) для заголовка фрейма опций
--------------------------------------------------------------------------------
do
  local tip = CreateFrame("button", nil, settingsFrame)
  tip:SetPoint("center",settingsFrame.TitleText,"center")
  tip:SetSize(settingsFrame.TitleText:GetStringWidth()+11,settingsFrame.TitleText:GetStringHeight()+1) -- Измените размеры фрейма настроек ++ 4.3.24
  
  --------------------------------------------------------------------------------
  -- действия при наведении мышкой на тултип
  --------------------------------------------------------------------------------
  tip:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм чекбокса (маусовер) ...
    GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
    GameTooltip:SetText(""..GetAddOnMetadata(ADDON_NAME, "Title").."\n\n"..GetAddOnMetadata(ADDON_NAME, "Notes").."", nil, nil, nil, nil, true)
    GameTooltip:Show() -- ... появится подсказка
  end)

  tip:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма чекбокса ... 
    GameTooltip:Hide() -- ... подсказка скроется
  end)
end

---------------------------------------------------------------
-- функция создания чекбоксов. так как их будет много - нужно будет спамить её по кд
---------------------------------------------------------------
function core:createCheckbox(settingName,checkboxText,tooltipText,optNum) -- offsetY отступ от settingsFrame.TitleText
  local checkBox = CreateFrame("CheckButton",ADDON_NAME.."_"..settingName,settingsFrame,"UICheckButtonTemplate") -- фрейм чекбокса
  --checkBox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 0, offsetY)
  checkBox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 0, -10-(optNum*10))
  checkBox:SetSize(28,28)
  local textFrame = CreateFrame("Button",nil,checkBox) -- фрейм текст чекбокса, не совсем по гениальному, ну лан
  local text = textFrame:CreateFontString(nil, "ARTWORK") -- текст для чекбокса
  text:SetFont(GameFontNormal:GetFont(), 14)
  text:SetText(checkboxText)
  textFrame:SetSize(text:GetStringWidth()+50,text:GetStringHeight()) -- ставим длинее чем длина текста а то чет он сокращается троеточием, тут надо бы разобраться кек 
  textFrame:SetPoint("LEFT", checkBox, "RIGHT", 0, 0)
  text:SetAllPoints(textFrame)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("BOTTOM")
  
  checkBox:SetScript("OnClick", function(self) -- по клику по фрейму проставляется настройка, чекбокс
    cfg[settingName] = checkBox:GetChecked() and true or false
    core:UpdateVisual()
  end)
  
  textFrame:SetScript("OnClick", function(self) -- по клику по фрейму проставляется настройка, текст
    if checkBox:GetChecked() then
      checkBox:SetChecked(false)
    else
      checkBox:SetChecked(true)
    end
    cfg[settingName] = checkBox:GetChecked() and true or false
    core:UpdateVisual()
  end)
  
  checkBox:SetScript("OnShow", function(self) 
    self:SetChecked(cfg[settingName])
  end)
  
  checkBox:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм чекбокса (маусовер) ...
    if tooltipText then 
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
      GameTooltip:Show() -- ... появится подсказка
    end
  end)
  
  checkBox:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма чекбокса ...
    if tooltipText then 
      GameTooltip:Hide() -- ... подсказка скроется
    end
  end)
  
  textFrame:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм текста (маусовер) ...
    if tooltipText then 
      GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
      GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
      GameTooltip:Show() -- ... появится подсказка
    end
  end)
  
  textFrame:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма текста ...
    if tooltipText then 
      GameTooltip:Hide() -- ... подсказка скроется
    end
  end)
end

---------------------------------------------------------------
-- функция создания эдитбоксов. ими тоже будем спамить где надо
---------------------------------------------------------------
function core:createEditBox(settingName,checkboxText,tooltipText,minValue,maxValue,optNum) -- offsetY отступ от settingsFrame.TitleText
  local editBox = CreateFrame("EditBox",ADDON_NAME.."_"..settingName,settingsFrame,"InputBoxTemplate") -- фрейм чекбокса
  --editBox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 8, offsetY)
  editBox:SetPoint("TOPLEFT", settingsFrame.TitleText, "BOTTOMLEFT", 8, -10-(optNum*10))
  editBox:SetAutoFocus(false)
  editBox:SetSize(22,12)
  editBox:SetFont(GameFontNormal:GetFont(), 12)
  editBox:SetText("")
  editBox:SetTextColor(1,1,1)
  
  local textFrame = CreateFrame("Button",nil,editBox) -- фрейм текст чекбокса, не совсем по гениальному, ну лан
  local text = textFrame:CreateFontString(nil, "ARTWORK") -- текст для чекбокса
  text:SetFont(GameFontNormal:GetFont(), 14)
  text:SetText(checkboxText)
  textFrame:SetSize(text:GetStringWidth()+50,text:GetStringHeight()) -- ставим длинее чем длина текста а то чет он сокращается троеточием, тут надо бы разобраться кек 
  textFrame:SetPoint("LEFT", editBox, "RIGHT", 3, 0)
  text:SetAllPoints(textFrame)
  text:SetJustifyH("LEFT")
  text:SetJustifyV("BOTTOM")
  
  editBox:SetScript('OnEnterPressed', function(self) 
    local num=self:GetNumber()
    if num and num>=minValue and num<=maxValue then
      cfg[settingName]=num
      self:SetText(num)
    else
      self:SetText(cfg[settingName] or "")
    end
    self:ClearFocus() 
    core:UpdateVisual()
  end)

  editBox:SetScript('OnEscapePressed', function(self) 
    self:SetText(cfg[settingName] or "")
    self:ClearFocus() 
    core:UpdateVisual()
  end)

  editBox:SetScript("OnShow", function(self) -- при появлении фрейма флаг выставится или снимется исходя из настроек
    if not self:HasFocus() then 
      self:SetText(cfg[settingName] or "") 
    end 
  end)
  
  editBox:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм чекбокса (маусовер) ...
    if tooltipText then 
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
      GameTooltip:Show() -- ... появится подсказка
    end
  end)
  
  editBox:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма чекбокса ...
    if tooltipText then 
      GameTooltip:Hide() -- ... подсказка скроется
    end
  end)
  
  textFrame:SetScript("OnEnter", function(self) -- при наведении мышкой на фрейм текста (маусовер) ...
    if tooltipText then 
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(tooltipText, 1, 1, 1, nil, true)
      GameTooltip:Show() -- ... появится подсказка
    end
  end)
  
  textFrame:SetScript("OnLeave", function(self) -- при снятии фокуса мышки с фрейма текста ...
    if tooltipText then 
      GameTooltip:Hide() -- ... подсказка скроется
    end
  end)
end
