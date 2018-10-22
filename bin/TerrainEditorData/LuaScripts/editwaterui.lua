-- Elevation Water Editing Brush
require 'LuaScripts/editingbrush'

EditWaterUI=ScriptObject()

function EditWaterUI:Start()
	self.panel=ui:LoadLayout(cache:GetResource("XMLFile", "UI/TerrainEditHeightBrush.xml"))

	self:SubscribeToEvent("Pressed", "EditWaterUI:HandleButtonPress")
	self:SubscribeToEvent("SliderChanged", "EditWaterUI:HandleSliderChanged")

	self.panel.style=uiStyle
	ui.root:AddChild(self.panel)
	self.active=true

	self.brushpreview=Image(context)
	self.brushpreview:SetSize(64,64,3)
	self.brushtex=Texture2D:new(context)
	self.panel:GetChild("BrushPreview",true).texture=self.brushtex

	self.power,self.max,self.radius,self.hardness,self.usemask=self:GetBrushSettings()
	self:GenerateBrushPreview()

	local text=self.panel:GetChild("PowerText", true)
	if text then text.text=string.format("%.1f", self.power) end
	text=self.panel:GetChild("RadiusText", true)
	if text then text.text=tostring(math.floor(self.radius)) end
	text=self.panel:GetChild("MaxText", true)
	if text then text.text=string.format("%.1f", self.max) end
	text=self.panel:GetChild("HardnessText", true)
	if text then text.text=string.format("%.2f", self.hardness) end

	self.buf=VectorBuffer()
	self.ary=Variant()
end

function EditWaterUI:GetBrushSettings()
	local power,max,radius,hardness=0,0,5,0.9
	local usemask0, usemask1, usemask2=false,false,false

	local slider
	slider=self.panel:GetChild("PowerSlider", true)
	if slider then power=(slider.value/slider.range)*4 end

	slider=self.panel:GetChild("MaxSlider", true)
	if slider then max=(slider.value/slider.range) end

	slider=self.panel:GetChild("RadiusSlider", true)
	if slider then radius=math.floor((slider.value/slider.range)*30) end

	slider=self.panel:GetChild("HardnessSlider", true)
	if slider then hardness=(slider.value/slider.range) end

	local button=self.panel:GetChild("Mask0Check", true)
	if button then usemask0=button.checked end

	button=self.panel:GetChild("Mask1Check", true)
	if button then usemask1=button.checked end

	button=self.panel:GetChild("Mask2Check", true)
	if button then usemask2=button.checked end

	return power,max,radius,math.min(1,hardness),usemask0, usemask1, usemask2
end

function EditWaterUI:GenerateBrushPreview()
	local hardness=0.5
	local slider=self.panel:GetChild("HardnessSlider", true)
	if slider then hardness=(slider.value/slider.range) end

	local w,h=self.brushpreview:GetWidth(), self.brushpreview:GetHeight()
	local rad=w/2
	local x,y
	for x=0,w-1,1 do
		for y=0,h-1,1 do
			local dx=x-w/2
			local dy=y-h/2
			local d=math.sqrt(dx*dx+dy*dy)
			local i=(d-rad)/(hardness*rad-rad)
			i=math.max(0, math.min(1,i))

			self.brushpreview:SetPixel(x,y,Color(i*0.5,i*0.5,i*0.6))
		end
	end

	self.brushtex:SetData(self.brushpreview, false)
end

function EditWaterUI:GetBrushPreview()
	return self.brushtex
end


function EditWaterUI:Activate()
	self.panel.visible=true
	self.active=true
	self:GenerateBrushPreview(self.hardness)
	self.panel:SetPosition(0,graphics.height-self.panel.height)
end

function EditWaterUI:SetCursor(x,y,radius,hardness)
	self.buf:Clear()
	self.buf:WriteFloat(x)
	self.buf:WriteFloat(y)
	self.buf:WriteFloat(radius)
	self.buf:WriteFloat(hardness)
	self.ary:Set(self.buf)
	TerrainState:GetMaterial():SetShaderParameter("Cursor", self.ary)
	self.buf:Clear()
	self.buf:WriteFloat(-cam.yaw*3.14159265/180.0)
	self.ary:Set(self.buf)
	TerrainState:GetMaterial():SetShaderParameter("Angle", self.ary)
end


function EditWaterUI:Deactivate()
	self.panel.visible=false
	self.active=false
	self:SetCursor(-100,-100,1,0)
end

function EditWaterUI:SetWater(ht)
	local slider=self.panel:GetChild("MaxSlider", true)
	if slider then slider.value=ht*slider.range end
	self:GenerateBrushPreview()
end

function EditWaterUI:HandleButtonPress(eventType, eventData)

end

function EditWaterUI:HandleSliderChanged(eventType, eventData)
	local which=eventData["Element"]:GetPtr("UIElement")
	if which==nil then return end

	self.power, self.max, self.radius, self.hardness, self.usemask0, self.usemask1, self.usemask2=self:GetBrushSettings(self.panel)

	if which==self.panel:GetChild("PowerSlider", true) then
		local text=self.panel:GetChild("PowerText", true)
		if text then text.text=string.format("%.2f", self.power) end
	elseif which==self.panel:GetChild("RadiusSlider", true) then
		local text=self.panel:GetChild("RadiusText", true)
		if text then text.text=tostring(math.floor(self.radius)) end
		elseif which==self.panel:GetChild("MaxSlider", true) then
		local text=self.panel:GetChild("MaxText", true)
		if text then text.text=string.format("%.2f", self.max) end
	elseif which==self.panel:GetChild("HardnessSlider", true) then
		local text=self.panel:GetChild("HardnessText", true)
		if text then text.text=string.format("%.3f", self.hardness) end
		self:GenerateBrushPreview(self.hardness)
	end
end

function EditWaterUI:Update(dt)
	if not self.active then return end
	local mousepos
	if input.mouseVisible then
		mousepos=input:GetMousePosition()
	else
		mousepos=ui:GetCursorPosition()
	end
	local ground=cam:GetScreenGround(mousepos.x, mousepos.y)
	if ground then
		local world=Vector3(ground.x,0,ground.z)
		self.power, self.max, self.radius, self.hardness, self.usemask0, self.usemask1, self.usemask2=self:GetBrushSettings()
		self:SetCursor(ground.x, ground.z, self.radius, self.hardness)
		local bs=BrushSettings(self.radius, self.max, self.power, self.hardness)
		local ms=MaskSettings(self.usemask0, false, self.usemask1, false, self.usemask2, false)

		if input:GetMouseButtonDown(MOUSEB_LEFT) and ui:GetElementAt(mousepos.x, mousepos.y)==nil then
			if input:GetQualifierDown(QUAL_CTRL) then
				local ht=TerrainState:GetWaterValue(world)
				self:SetWater(ht)
			else
				local gx,gz=ground.x,ground.z
				TerrainState:ApplyWaterBrush(gx,gz,dt,bs,ms)
			end
		end
	end
end
