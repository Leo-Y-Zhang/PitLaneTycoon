--!strict
-- Small, asset-free silhouettes on a 24 px grid. Labels stay on their original buttons.
local Icons = {}
export type Kind = "cash" | "gift" | "crew" | "goal" | "settings" | "race"

function Icons.draw(parent: GuiObject, kind: Kind, colour: Color3): Frame
	local icon = Instance.new("Frame")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.fromOffset(24, 24)
	icon.Position = UDim2.new(0, 10, 0.5, -12)
	icon.Parent = parent
	local function piece(x: number, y: number, w: number, h: number, radius: number?, outline: boolean?): Frame
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = colour
		f.BackgroundTransparency = outline and 1 or 0
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.Parent = icon
		if radius then
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, radius)
			corner.Parent = f
		end
		if outline then
			local stroke = Instance.new("UIStroke")
			stroke.Color = colour
			stroke.Thickness = 2
			stroke.Parent = f
		end
		return f
	end
	if kind == "cash" then
		piece(1, 5, 22, 14, 3, true)
		piece(9, 8, 6, 8, 3, true)
		piece(4, 11, 2, 2, 1)
		piece(18, 11, 2, 2, 1)
	elseif kind == "gift" then
		piece(3, 10, 18, 12, 2, true)
		piece(1, 7, 22, 4, 1)
		piece(11, 7, 2, 15)
		piece(5, 1, 7, 6, 3, true)
		piece(12, 1, 7, 6, 3, true)
	elseif kind == "crew" then
		piece(8, 1, 8, 8, 4)
		piece(5, 11, 14, 11, 5)
		piece(0, 6, 5, 6, 3)
		piece(19, 6, 5, 6, 3)
		piece(0, 14, 3, 7, 2)
		piece(21, 14, 3, 7, 2)
	elseif kind == "goal" then
		piece(2, 2, 20, 20, 10, true)
		piece(7, 7, 10, 10, 5, true)
		piece(11, 11, 2, 2, 1)
	elseif kind == "settings" then
		for i, knob in { 5, 16, 10 } do
			local y = 4 + (i - 1) * 8
			piece(1, y, 22, 2, 1)
			piece(knob, y - 2, 6, 6, 3)
		end
	elseif kind == "race" then
		piece(1, 1, 2, 23, 1)
		for col = 0, 2 do
			for row = 0, 2 do
				if (col + row) % 2 == 0 then piece(4 + col * 6, 2 + row * 5, 6, 5) end
			end
		end
	end
	return icon
end

function Icons.button(button: TextButton, kind: Kind, colour: Color3)
	local icon = Icons.draw(button, kind, colour)
	icon.Position = UDim2.new(0, -28, 0.5, -12)
	local padding = Instance.new("UIPadding")
	-- Balanced padding leaves a fixed lane for the icon, including on long gift labels.
	padding.PaddingLeft = UDim.new(0, 38)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = button
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = button.TextSize
	constraint.MinTextSize = 10
	constraint.Parent = button
	button.TextScaled = true
end

return Icons
