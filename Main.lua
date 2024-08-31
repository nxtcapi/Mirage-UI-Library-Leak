local TS = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local Client = game:GetService("Players").LocalPlayer
local Camera = game:GetService("Workspace").CurrentCamera
local RunService = game:GetService("RunService")

local viewportX, viewportY = Camera.ViewportSize.X, Camera.ViewportSize.Y

local tween = {}
local keysystem = {}
local config = { _debug = true, write = nil }
local base = {}
local library = {}
local connections = {}
local tooltips = {}
local acrylic = {}
local states = { build = false, react = true }
local view = Client:WaitForChild("PlayerGui"):FindFirstChild("UI")

--> From https://github.com/Sleitnick/RbxCookbook/blob/master/src/Map.lua
local function map(n: number, oldMin: number, oldMax: number, min: number, max: number): number
	return (min + ((max - min) * ((n - oldMin) / (oldMax - oldMin))))
end

--> Cleanup all connections.
local function cleanup()
	for i, v: RBXScriptConnection in next, connections do
		if v.Connected then
			v:Disconnect()
		end
	end
end

--> Utility for adding to the connections.
local function add_connection(cn: RBXScriptConnection)
	connections[#connections + 1] = cn
end

--> Helper function
local function has_dupe(item, tbl)
	local count = 0

	for _, value in ipairs(tbl) do
		if value == item then
			count = count + 1
			if count > 1 then
				return true
			end
		end
	end

	return false
end

--> Log important information to the console regarding the UI. Only called when _debug is true.
local function log(...)
	if not config._debug then
		return
	end

    config.write(`[UI]: {...}`)
end

--> Obsersable values, fires on any changes
local function create_observable(initial_value: any)
	local val = initial_value
	local callbacks = {}

	local _p = setmetatable({}, {
		__index = function(_, k: any)
			return val[k]
		end,

		__newindex = function(_, k: any, v: any)
			val[k] = v
			for _, c: (v: any) -> () in next, callbacks do
				c(v)
			end
		end,
	})

	return {
		onChanged = function(callback: (v: any | boolean | number | string) -> ())
			callbacks[#callbacks + 1] = callback
		end,

		get = function()
			return val
		end,

		set = function(v: any)
			val = v

			for _, c: (v: any) -> () in next, callbacks do
				c(v)
			end
		end,

		object = _p,
	}
end

--> Default properties for objects
local default_properties = {
	Frame = {
		BackgroundColor3 = Color3.fromHex("FFFFFF"),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(100, 100),
	},
	TextLabel = {
		BackgroundTransparency = 1,
		FontFace = Font.fromId(12187365364, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 16,
		Text = "Label",
		Size = UDim2.fromOffset(100, 30),
		TextColor3 = Color3.fromHex("000000"),
	},
	TextButton = {
		FontFace = Font.fromId(12187365364, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 16,
		Text = "Button",
		Size = UDim2.fromOffset(100, 30),
		TextColor3 = Color3.fromHex("000000"),
	},
	TextBox = {
		FontFace = Font.fromId(12187365364, Enum.FontWeight.Medium, Enum.FontStyle.Normal),
		TextSize = 16,
		PlaceholderText = "TextBox",
		Size = UDim2.fromOffset(100, 30),
		TextColor3 = Color3.fromHex("000000"),
	},
	ScrollingFrame = {
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 0,
		BackgroundTransparency = 1,
	},
}

--> Create any instance with brevity
local function create(className: string, instanceProperties, children): Instance
	local instance = Instance.new(className)

	if default_properties[className] then
		for property, value in pairs(default_properties[className]) do
			if instance:GetPropertyChangedSignal(property) ~= nil then
				instance[property] = value
			end
		end
	end

	if instanceProperties then
		for property, value in pairs(instanceProperties) do
			if instance:GetPropertyChangedSignal(property) ~= nil then
				instance[property] = value
			end

			if property == "Parent" then
				instance.Parent = value
			end
		end
	end

	if children then
		mount(children, instance)
	end

	return instance
end

--> Mount an instance to a target
function mount(instances: GuiObject | {}, target: GuiObject)
	if not instances then
		return
	end

	if type(instances) ~= "table" then
		instances.Parent = target
	end

	if type(instances) == "table" then
		for _, c in next, instances do
			c.Parent = target
		end
	end
end

--> Util function for fading text
function fade_text(object, text: string, duration: number?)
	local tweenInfo = TweenInfo.new(if duration then duration else 1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TS:Create(object, tweenInfo, { TextTransparency = 1 })
	tween:Play()
	tween.Completed:Wait()
	object.Text = text
	tween = TS:Create(object, tweenInfo, { TextTransparency = 0 })
	tween:Play()
end

local function createTooltip(props: { [any]: any })
	-- If a tooltip is already showing, don't create a new one.
	if #props.Parent:GetChildren() == 1 then
		return
	end

	local tooltip = create("Frame", {
		Name = "Tooltip",
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = props.Position,
		Size = UDim2.fromOffset(0, 30),
		ZIndex = 2,
	}, {
		tooltip = create("Frame", {
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(37, 37, 46),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.fromOffset(60, 20),
			BackgroundTransparency = 1,
			ZIndex = 2,
		}, {
			uICorner = create("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),

			text = create("TextLabel", {
				FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				Text = props.Text,
				TextColor3 = Color3.fromRGB(174, 174, 180),
				TextSize = 12,
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				TextTransparency = 1,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 2,
			}, {
				uIPadding = create("UIPadding", {
					PaddingLeft = UDim.new(0, 5),
					PaddingRight = UDim.new(0, 5),
					PaddingTop = UDim.new(0, 2),
				}),
			}),

			arrow = create("ImageLabel", {
				Image = "rbxassetid://16766190150",
				ImageColor3 = Color3.fromRGB(37, 37, 46),
				ImageTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 0, -10),
				Size = UDim2.fromOffset(10, 10),
				ZIndex = 2,
			}),
		}),
	})

	-- tooltip:SetAttribute("Skip", true)

	tooltip.Size = UDim2.fromOffset(tooltip:WaitForChild("Tooltip").Size.X.Offset, 30)

	mount(tooltip, props.Parent)

	return tooltip
end

local function createDialog(target, options)
	if target:FindFirstChild("Dialog") then
		return
	end

	local dialog = create("Frame", {
		Name = "Dialog",
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(0, 0, 0),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 50, 1, 50),
		ZIndex = 999,
	}, {
		uICorner = create("UICorner"),

		container = create("CanvasGroup", {
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 0.5),
			GroupTransparency = 1,
			BackgroundColor3 = Color3.fromRGB(21, 21, 26),
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(300, 172),
			ZIndex = 1000,
		}, {
			uICorner1 = create("UICorner"),

			uIStroke = create("UIStroke", {
				Color = Color3.fromRGB(32, 32, 40),
				Thickness = 1.3,
			}),

			uIListLayout = create("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			title = create("TextLabel", {
				Name = "Title",
				FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				Text = options.Title,
				TextColor3 = Color3.fromRGB(193, 185, 255),
				TextSize = 17,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = 1,
				Size = UDim2.new(1, 0, 0, 40),
				ZIndex = 1001,
			}),

			seperator = create("Frame", {
				Name = "Seperator",
				BackgroundColor3 = Color3.fromRGB(28, 28, 35),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Size = UDim2.new(1, 0, 0, 1),
				ZIndex = 1001,
			}),

			message = create("TextLabel", {
				Name = "Message",
				FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				Text = options.Message,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = 15,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextWrapped = true,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = 3,
				Size = UDim2.new(1, 0, 0, 80),
				ZIndex = 1001,
			}, {
				uIPadding = create("UIPadding", {
					PaddingBottom = UDim.new(0, 5),
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
					PaddingTop = UDim.new(0, 5),
				}),
			}),

			buttons = create("Frame", {
				Name = "Buttons",
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = 4,
				Size = UDim2.new(1, 0, 0, 50),
			}, {
				uIListLayout1 = create("UIListLayout", {
					Padding = UDim.new(0, 15),
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				actionCancel = create("Frame", {
					Name = "ActionCancel",
					BackgroundColor3 = Color3.fromRGB(35, 35, 43),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Size = UDim2.new(0, 130, 1, -20),
					ZIndex = 1001,
				}, {
					uICorner2 = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					onActivated = create("TextButton", {
						Name = "OnActivated",
						FontFace = Font.new("rbxassetid://12187365364"),
						Text = "Cancel",
						TextColor3 = Color3.fromRGB(158, 158, 158),
						TextSize = 14,
						Modal = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1001,
					}),

					uIStroke1 = create("UIStroke", {
						Color = Color3.fromRGB(31, 31, 38),
					}),
				}),

				actionConfirm = create("Frame", {
					Name = "ActionConfirm",
					BackgroundColor3 = Color3.fromRGB(35, 35, 43),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Size = UDim2.new(0, 130, 1, -20),
					ZIndex = 1001,
				}, {
					uICorner3 = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					onActivated1 = create("TextButton", {
						Name = "OnActivated",
						FontFace = Font.new("rbxassetid://12187365364"),
						Text = "Confirm",
						TextColor3 = Color3.fromRGB(194, 194, 194),
						TextSize = 14,
						Modal = true,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Size = UDim2.fromScale(1, 1),
						ZIndex = 1001,
					}),

					uIStroke2 = create("UIStroke", {
						Color = Color3.fromRGB(31, 31, 38),
					}),
				}),
			}),
		}),
	})

	local container = dialog.Container
	local buttons = container.Buttons

	TS:Create(dialog, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 0.25 }):Play()
	TS:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { GroupTransparency = 0 }):Play()
	TS:Create(container.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = 0 }):Play()

	local function peformAnimation()
		(view :: ScreenGui).ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		states.react = false

		TS:Create(dialog, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 }):Play()
		TS:Create(container, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { GroupTransparency = 1 }):Play()
		TS:Create(container.UIStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Transparency = 1 }):Play()
		task.wait(0.5)
		dialog:Destroy();

		(view :: ScreenGui).ZIndexBehavior = Enum.ZIndexBehavior.Global
		states.react = true
	end

	add_connection(buttons.ActionCancel.OnActivated.Activated:Connect(function()
		if options.OnAction then
			local s, r = pcall(options.OnAction, "Cancel")
			assert(s, r)
		end

		peformAnimation()
	end))

	add_connection(buttons.ActionConfirm.OnActivated.Activated:Connect(function()
		if options.OnAction then
			local s, r = pcall(options.OnAction, "Confirm")
			assert(s, r)
		end

		peformAnimation()
	end))

	mount(dialog, target)
end

-- Acrylic / Blur module
-- Open sourced module
-- Refined and edited
-- Will write a custom one soon, this one is fine for now.

-- TODO: add acrylic paint effect. (create acrylic paint decal, split across window)

do
    do
        local function IsNotNaN(x)
            return x == x
        end

        local continued = IsNotNaN(Camera:ScreenPointToRay(0, 0).Origin.X)
        while not continued do
            RunService.RenderStepped:Wait()
            continued = IsNotNaN(Camera:ScreenPointToRay(0, 0).Origin.X)
        end
    end

    local RootParent = Camera
    local root
    local binds = {}

    local function getRoot()
        if root then
            return root
        else
            root = Instance.new('Folder', RootParent)
            root.Name = "Processing"
            return root
        end
    end

    local function destroyRoot()
        if root then
            root:Destroy()
            root = nil
        end
    end

    local GenUid; do
        local id = 0
        function GenUid()
            id = id + 1
            return 'processing->'..tostring(id)
        end
    end

    local DrawQuad; do
        local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
        local sz = 0.2

        local function DrawTriangle(v1, v2, v3, p0, p1)
            local s1 = (v1 - v2).Magnitude
            local s2 = (v2 - v3).Magnitude
            local s3 = (v3 - v1).Magnitude
            local smax = max(s1, s2, s3)
            local A, B, C
            if s1 == smax then
                A, B, C = v1, v2, v3
            elseif s2 == smax then
                A, B, C = v2, v3, v1
            elseif s3 == smax then
                A, B, C = v3, v1, v2
            end

            local para = ( (B - A).X * (C - A).X + (B - A).Y * (C - A).Y + (B - A).Z * (C - A).Z ) / (A - B).Magnitude
            local perp = sqrt((C - A).Magnitude ^ 2 - para * para)
            local diff = (A - B).Magnitude - para

            local st = CFrame.new(B, A)
            local angles = CFrame.Angles(pi / 2, 0, 0)

            local cf0 = st

            local top_look = (cf0 * angles).LookVector
            local mid_point = A + CFrame.new(A, B).LookVector * para
            local want = CFrame.new(mid_point, C).LookVector
            local point = top_look.X * want.X + top_look.Y * want.Y + top_look.Z * want.Z

            local ac = CFrame.Angles(0, 0, acos(point))

            cf0 *= ac
            if ((cf0 * angles).LookVector - want).Magnitude > 0.01 then
                cf0 = cf0 * CFrame.Angles(0, 0, -2 * acos(point))
            end

            cf0 *= CFrame.new(0, perp / 2, -(diff + para / 2))

            local cf1 = st * ac * CFrame.Angles(0, pi, 0)
            if ((cf1 * angles).LookVector - want).Magnitude > 0.01 then
                cf1 *= CFrame.Angles(0, 0, 2 * acos(point))
            end

            cf1 *= CFrame.new(0, perp / 2, diff / 2)

            if not p0 then
                p0 = Instance.new('Part')
                p0.FormFactor = 'Custom'
                p0.TopSurface = 0
                p0.BottomSurface = 0
                p0.Anchored = true
                p0.CanCollide = false
                p0.Material = 'Glass'
                p0.Size = Vector3.new(sz, sz, sz)
                local mesh = Instance.new('SpecialMesh', p0)
                mesh.MeshType = 2
                mesh.Name = 'WedgeMesh'
            end

            p0.WedgeMesh.Scale = Vector3.new(0, perp / sz, para / sz)
            p0.CFrame = cf0

            if not p1 then
                p1 = p0:clone()
            end
            p1.WedgeMesh.Scale = Vector3.new(0, perp / sz, diff / sz)
            p1.CFrame = cf1

            return p0, p1
        end

        function DrawQuad(v1, v2, v3, v4, parts)
            parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
            parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
        end
    end

    function acrylic:Setup()
        local dof = Instance.new("DepthOfFieldEffect", game:GetService("Lighting"))
        dof.FarIntensity = 0
        dof.FocusDistance = 6
        dof.InFocusRadius = 0
        dof.NearIntensity = 0.35
    end

    function acrylic:BindFrame(frame, properties)
        if binds[frame] then
            return binds[frame].parts
        end

        local uid = GenUid()
        local parts = {}
        local f = Instance.new('Folder', getRoot())
        f.Name = frame.Name

        local parents = {}
        do
            local function add(child)
                if child:IsA"GuiObject" then
                    parents[#parents + 1] = child
                    add(child.Parent)
                end
            end

            add(frame)
        end

        local function UpdateOrientation(fetchProps)
            local zIndex = 1 - 0.05*frame.ZIndex
            local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
            local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
            do
                local rot = 0
                for _, v in ipairs(parents) do
                    rot = rot + v.Rotation
                end
                if rot ~= 0 and rot%180 ~= 0 then
                    local mid = tl:lerp(br, 0.5)
                    local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
                    local vec = tl
                    tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
                    tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
                    bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
                    br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
                end
            end
            DrawQuad(
                Camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin, 
                Camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin, 
                Camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin, 
                Camera:ScreenPointToRay(br.x, br.y, zIndex).Origin, 
                parts
            )
            if fetchProps then
                for _, pt in pairs(parts) do
                    pt.Parent = f
                end
                for propName, propValue in pairs(properties) do
                    for _, pt in pairs(parts) do
                        pt[propName] = propValue
                    end
                end
            end
        end

        UpdateOrientation(true)
        RunService:BindToRenderStep(uid, 2000, UpdateOrientation)

        binds[frame] = {
            uid = uid,
            parts = parts,
        }

        return binds[frame].parts
    end

    function acrylic:Modify(frame, props)
        local parts = acrylic:GetBoundParts(frame)
        if parts then
            for propName, propValue in pairs(props) do
                for _, pt in pairs(parts) do
                    pt[propName] = propValue
                end
            end
        end
    end

    function acrylic:UnbindFrame(frame)
        if RootParent == nil then return end
        local cb = binds[frame]
        if cb then
            RunService:UnbindFromRenderStep(cb.uid)
            for _, v in pairs(cb.parts) do
                v:Destroy()
            end
            binds[frame] = nil
        end
        if getRoot():FindFirstChild(frame.Name) then
            getRoot()[frame.Name]:Destroy()
        end
    end

    function acrylic:HasBinding(frame)
        return binds[frame] ~= nil
    end

    function acrylic:GetBoundParts(frame)
        return binds[frame] and binds[frame].parts
    end
end

--> Creates the ScreenGui, if in studio then parent it to the player gui else the protected / hidden ui.
function base:CreateView()
	local v = create("ScreenGui", {
			Name = "NewUI",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
        }, {
    		create("Frame", {
    			Name = "Tooltips",
    			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
    			BackgroundTransparency = 1,
    			BorderColor3 = Color3.fromRGB(0, 0, 0),
    			BorderSizePixel = 0,
    			Size = UDim2.fromScale(1, 1),
    			ZIndex = 2,
            }),
            
            create("ImageLabel", {
                Name = "ResizeCursor",
                Image = "rbxassetid://17697485964",
                ScaleType = Enum.ScaleType.Crop,
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundTransparency = 1,
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Size = UDim2.fromOffset(35, 35),
                Visible = false,
            })
        }
	)

	mount(v, Client:WaitForChild("PlayerGui"))
	--mount(v, game:GetService("CoreGui"))
	--gethui(v)

	return v
end

--> Base for creating a window.
function base:CreateWindow(window_options: any)
	if not window_options then
		log("CreateWindow options parameter is nil!")
	end

	local position = create_observable(window_options.Position or UDim2.new(0.5, -400, 0.5, -250))
	local window = create("Frame", {
		Name = window_options.Name,
		Parent = view,
		Size = window_options.Size,
		Position = window_options.Position,
		BackgroundColor3 = (window_options.BackgroundColor3 or Color3.new(255, 255, 255)),
	}, {
        create("UICorner", { CornerRadius = UDim.new(0, 8) }),
        create("Frame", {
            Name = "Resizer",
            AnchorPoint = Vector2.new(1, 1),
            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Position = window_options.ResizerPosition or UDim2.new(1, 25, 1, 25),
            Size = UDim2.fromOffset(7, 7),
        })
	})

	if window_options.Children then
		mount(window_options.Children, window)
	end

	if window_options.CreateLayout then
		create("UIPadding", {
			Parent = window,
			PaddingBottom = UDim.new(0, 25),
			PaddingLeft = UDim.new(0, 25),
			PaddingRight = UDim.new(0, 25),
			PaddingTop = UDim.new(0, 25),
		})
    end
    
    local dragOutline = create("Frame", {
        Name = "DragOutline",
        Parent = view,
        
        Size = window.Size,
        BackgroundTransparency = 1,
        Position = window.Position,
        
        Visible = false,
    }, {
		create("UIStroke", { Color = Color3.fromRGB(193, 185, 255) }),
        create("UICorner")
    })
    
    local allowDrag = create_observable(true)

	local dragging = create_observable(false)
	local dragStart = create_observable()
    local startPos = create_observable()
    
    dragging.onChanged(function(v) 
        if not allowDrag:get() then
            return
        end
        
        dragOutline.Visible = v
        dragOutline.Size = window.Size
        
        if not v then
            local dragTween = TS:Create(window, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {Position = dragOutline.Position})
            
            dragTween.Completed:Connect(function()
                dragOutline.Position = window.Position
            end)
            
            dragTween:Play()
            
        end
    end)

	local update = function(i: InputObject)
		local d = i.Position - dragStart.get()
		position.set(startPos.get() + UDim2.fromOffset(d.X, d.Y))
	end

    add_connection(window.InputBegan:Connect(function(i: InputObject)
        if allowDrag:get() and i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging.set(true)
			dragStart.set(i.Position)
			startPos.set(position.get())

			i.Changed:Connect(function(a0: string)
				if i.UserInputState == Enum.UserInputState.End then
					dragging.set(false)
				end
			end)
		end
	end))

    add_connection(UIS.InputChanged:Connect(function(i: InputObject)
		if allowDrag:get() and i.UserInputType == Enum.UserInputType.MouseMovement then
			if dragging.get() then
				update(i)
			end
		end
	end))

    position.onChanged(function(new)
        if not allowDrag:get() then
            return
        end
        
        dragOutline.Position = new
    end)
    
    local resizer = window:WaitForChild("Resizer")

    add_connection(resizer.MouseEnter:Connect(function()
        allowDrag:set(false)
        UIS.MouseIcon = "rbxassetid://17697485964"
    end))

    add_connection(resizer.MouseLeave:Connect(function()
        allowDrag:set(true)
        UIS.MouseIcon = ""
    end))

	return window
end

--> Cleanup all connections
function base:Cleanup()
	for i, v in next, connections do
		v:Disconnect()
	end
end

function keysystem:Create()
	local view = base:CreateWindow({
		Name = "KeySystem",
		Parent = view,
		Size = UDim2.fromOffset(370, 480),
		Position = UDim2.new(0.5, -(370 / 2), 0.5, -(480 / 2)),
        BackgroundColor3 = Color3.fromRGB(21, 21, 26),
        ResizerPosition = UDim2.new(1, 0, 1, 0),
		Children = {
			uICorner = create("UICorner", {
				CornerRadius = UDim.new(0, 6),
			}),

			textfieldOption = create("Frame", {
				Name = "Textfield",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				LayoutOrder = 2,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 0, 45),
			}, {
				uIPadding = create("UIPadding", {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				}),

				container = create("Frame", {
					Name = "Container",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(1, -50, 1, -10),
				}, {
					uICorner = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					uIGradient = create("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 43, 56)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 39)),
						}),
						Rotation = 90,
					}),

					input = create("TextBox", {
						Name = "Input",
						ClearTextOnFocus = false,
						FontFace = Font.new(
							"rbxassetid://12187365364",
							Enum.FontWeight.SemiBold,
							Enum.FontStyle.Normal
						),
						PlaceholderColor3 = Color3.fromRGB(71, 71, 81),
						PlaceholderText = "Key",
						ShowNativeInput = false,
						Text = "",
						TextColor3 = Color3.fromRGB(206, 204, 234),
						TextSize = 16,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Size = UDim2.new(1, -30, 1, 0),
					}, {
						uIPadding = create("UIPadding", {
							PaddingLeft = UDim.new(0, 10),
						}),
					}),

					image = create("ImageLabel", {
						Image = "rbxassetid://15450356515",
						ImageColor3 = Color3.fromRGB(108, 108, 135),
						ImageTransparency = 0.3,
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.new(1, -7, 0.5, 0),
						Size = UDim2.fromOffset(20, 20),
					}),
				}),

				iconButton = create("Frame", {
					Name = "IconButton",
					AnchorPoint = Vector2.new(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					Position = UDim2.new(1, -35, 0.5, 0),
					Size = UDim2.fromOffset(35, 35),
				}, {
					uICorner = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					uIGradient = create("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 43, 56)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 39)),
						}),
						Rotation = 90,
					}),

					onActivated = create("ImageButton", {
						Image = "rbxassetid://16769466906",
						ImageColor3 = Color3.fromRGB(137, 145, 255),
						ScaleType = Enum.ScaleType.Crop,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -10, 1, -10),
					}),
				}),
			}),

			actions = create("Frame", {
				Name = "Actions",
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 1, -90),
				Size = UDim2.new(1, 0, 0, 45),
			}, {
				uIPadding2 = create("UIPadding", {
					PaddingLeft = UDim.new(0, 25),
					PaddingRight = UDim.new(0, 25),
				}),

				helpButton = create("Frame", {
					Name = "HelpButton",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 1,
					Size = UDim2.fromOffset(35, 35),
				}, {
					uICorner3 = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					uIGradient2 = create("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 43, 56)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 39)),
						}),
						Rotation = 90,
					}),

					onActivated1 = create("ImageButton", {
						Image = "rbxassetid://16769510607",
						ImageColor3 = Color3.fromRGB(137, 145, 255),
						ScaleType = Enum.ScaleType.Crop,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -10, 1, -10),
					}),
				}),

				getButton = create("Frame", {
					Name = "GetButton",
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(1, -35, 0.5, 0),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 3,
					Size = UDim2.fromOffset(35, 35),
				}, {
					uICorner4 = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					uIGradient3 = create("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 43, 56)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 39)),
						}),
						Rotation = 90,
					}),

					onActivated2 = create("ImageButton", {
						Image = "rbxassetid://16769517300",
						ImageColor3 = Color3.fromRGB(137, 145, 255),
						ScaleType = Enum.ScaleType.Crop,
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -10, 1, -10),
					}),
				}),

				button = create("Frame", {
					Name = "Button",
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Size = UDim2.new(1, -100, 0, 35),
				}, {
					container1 = create("Frame", {
						Name = "Container",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
					}, {
						uICorner5 = create("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),

						onActivated3 = create("TextButton", {
							Name = "OnActivated",
							FontFace = Font.new(
								"rbxassetid://12187365364",
								Enum.FontWeight.SemiBold,
								Enum.FontStyle.Normal
							),
							Text = "Continue",
							TextColor3 = Color3.fromRGB(102, 101, 112),
							TextSize = 16,
							TextTruncate = Enum.TextTruncate.AtEnd,
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							ClipsDescendants = true,
							Size = UDim2.fromScale(1, 1),
						}, {
							uIPadding3 = create("UIPadding", {
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
							}),
						}),

						uIGradient4 = create("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(43, 43, 56)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(32, 32, 39)),
							}),
							Rotation = 90,
						}),

						uiStroke = create("UIStroke", {
							Color = Color3.fromRGB(255, 255, 255),
						}, {
							uIGradient = create("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(53, 53, 67)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(53, 53, 67)),
								}),
								Transparency = NumberSequence.new({
									NumberSequenceKeypoint.new(0, 0),
									NumberSequenceKeypoint.new(0.312, 1),
									NumberSequenceKeypoint.new(0.484, 1),
									NumberSequenceKeypoint.new(0.675, 1),
									NumberSequenceKeypoint.new(0.701, 1),
									NumberSequenceKeypoint.new(1, 0),
								}),
							}),
						}),
					}),
				}),
			}),

			text = create("TextLabel", {
				Name = "Notice",
				FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				Text = "Don't have a key?",
				TextColor3 = Color3.fromRGB(71, 71, 81),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				AnchorPoint = Vector2.new(0.5, 1),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 1, -135),
				Size = UDim2.fromScale(1, 0),
			}, {
				uIPadding4 = create("UIPadding", {
					PaddingBottom = UDim.new(0, 7),
					PaddingLeft = UDim.new(0, 26),
				}),
			}),

			logo = create("ImageLabel", {
				Name = "Logo",
				Image = "http://www.roblox.com/asset/?id=16808561494",
				ImageColor3 = Color3.fromRGB(137, 145, 255),
				Active = true,
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 0, 50),
				Size = UDim2.fromOffset(95, 70),
			}),

			close = create("ImageButton", {
				Name = "Close",
				Image = "rbxassetid://16769570265",
				ImageColor3 = Color3.fromRGB(137, 145, 255),
				ScaleType = Enum.ScaleType.Crop,
				AnchorPoint = Vector2.new(1, 0),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(1, -20, 0, 20),
				Size = UDim2.fromOffset(20, 20),
			}),

			status = create("TextLabel", {
				Name = "Status",
				FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				Text = "Ready.",
				TextColor3 = Color3.fromRGB(114, 114, 130),
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
				AnchorPoint = Vector2.new(0.5, 1),
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 1, -190),
				Size = UDim2.fromScale(1, 0),
			}, {
				uIPadding = create("UIPadding", {
					PaddingBottom = UDim.new(0, 7),
					PaddingLeft = UDim.new(0, 26),
				}),
			}),
		},
	})

	-- Later: implement the logic for the close button, help button and get button

	local closeButton = view.Close
	local verifyButton = view.Actions.Button
	local keyInput = view.Textfield.Container.Input
	local actionButtons = {
		Get = view.Actions.GetButton,
		Help = view.Actions.HelpButton,
	}

	local isDown = create_observable(false)
	local isHovering = create_observable(false)

	-- Handle reactivity
	do
		add_connection(closeButton.Activated:Connect(function()
			base:Cleanup()
			view.Parent:Destroy()
		end))

		local function change_status(status: string)
			fade_text(view.Status, status, 0.3)
		end

		isDown.onChanged(function(v)
			TS:Create(
				verifyButton.Container,
				TweenInfo.new(0.125, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = (if v then 0.4 else 0) }
			):Play()
		end)

		isHovering.onChanged(function(v)
			if isDown.get() then
				return
			end

			TS:Create(
				verifyButton.Container,
				TweenInfo.new(0.125, Enum.EasingStyle.Quad),
				{ BackgroundTransparency = (if v then 0.2 else 0) }
			):Play()
			TS:Create(
				verifyButton.Container.OnActivated,
				TweenInfo.new(0.125, Enum.EasingStyle.Quad),
				{ TextColor3 = (if v then Color3.fromRGB(190, 190, 201) else Color3.fromRGB(138, 137, 152)) }
			):Play()
		end)

		add_connection(verifyButton.Container.OnActivated.MouseButton1Down:Connect(function()
			if not isDown.get() then
				isDown.set(true)
			end
		end))

		add_connection(verifyButton.Container.OnActivated.MouseButton1Up:Connect(function()
			if isDown.get() and isHovering.get() then
				isDown.set(false)
			end
		end))

		add_connection(verifyButton.MouseEnter:Connect(function()
			if not isHovering.get() then
				isHovering.set(true)
			end
		end))

		add_connection(verifyButton.MouseLeave:Connect(function()
			if isHovering.get() then
				isHovering.set(false)
			end
		end))

		add_connection(verifyButton.Container.OnActivated.Activated:Connect(function()
			local userInput = keyInput.Text

			if userInput == "key123" then
				change_status("Success.")
				task.wait(2)
				states.build = true
			else
				change_status("Incorrect key. Please try again.")
			end
		end))

		add_connection(closeButton.Activated:Connect(function()
			if view then
				view:Destroy()
			end

			for i, v in pairs(connections) do
				if v.Connected then
					v:Disconnect()
				end
			end
		end))

		--> Get key button
		add_connection(actionButtons.Get:FindFirstChildOfClass("ImageButton").Activated:Connect(function()
			--> Copy something to the clipboard, or anything of your choice.
		end))

		--> Help button
		add_connection(actionButtons.Help:FindFirstChildOfClass("ImageButton").Activated:Connect(function()
			fade_text(view.Notice :: TextLabel, "Don't have a key? Visit <site> to get one.", 0.5)
			task.wait(5)
			fade_text(view.Notice :: TextLabel, "Don't have a key?", 0.5)
		end))
	end

	return view
end

--> Create all windows and views.
function library:init(options: { [string]: any })
	--> Pause until the keysystem sets the state.build to true.
	if not view then
		view = base:CreateView()
    end

	local keyview = keysystem:Create()

	mount(keyview, view)

	while not states.build do
		task.wait(0.1)
	end

	keyview:Destroy()
    
    local store = {}
	local open = create_observable(options.Open)
	local show_console = create_observable(false)
	local created_components = {}
	local extended = {}
    local tabs = {}
    
    local console = base:CreateWindow({
        Name = "Console",
        Parent = view,
        Size = UDim2.fromOffset(550, 400),
        Position = UDim2.fromScale(0.6, 0.15),
        BackgroundColor3 = Color3.fromRGB(21, 21, 26),
        Children = {
            uICorner = create("UICorner"),

            topPanel = create("Frame", {
                Name = "TopPanel",
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 0, 0, 20),
                Size = UDim2.new(1, -40, 0, 40),
            }, {
                uICorner1 = create("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                }),

                uIStroke = create("UIStroke", {
                    Color = Color3.fromRGB(32, 32, 40),
                    Thickness = 1.3,
                }),

                title = create("TextLabel", {
                    Name = "Title",
                    FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
                    Text = "CONSOLE",
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    TextSize = 18,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    AnchorPoint = Vector2.new(0, 0.5),
                    AutomaticSize = Enum.AutomaticSize.X,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale(0, 0.5),
                    Size = UDim2.fromScale(0, 1),
                }, {
                    uIGradient = create("UIGradient", {
                        Color = ColorSequence.new({
                            ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                            ColorSequenceKeypoint.new(1, Color3.fromRGB(103, 103, 130)),
                        }),
                        Rotation = 90,
                    }),
                }),

                uIPadding = create("UIPadding", {
                    PaddingBottom = UDim.new(0, 10),
                    PaddingLeft = UDim.new(0, 15),
                    PaddingRight = UDim.new(0, 15),
                    PaddingTop = UDim.new(0, 10),
                }),

                uIGradient1 = create("UIGradient", {
                    Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 39, 48)),
                        ColorSequenceKeypoint.new(1, Color3.fromRGB(23, 23, 29)),
                    }),
                    Rotation = 90,
                }),

                closeButton = create("ImageButton", {
                    Image = "rbxassetid://17050627832",
                    ImageColor3 = Color3.fromRGB(229, 231, 255),
                    AnchorPoint = Vector2.new(1, 0.5),
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Position = UDim2.fromScale(1, 0.5),
                    Size = UDim2.fromOffset(15, 15),
                }),
            }),

            output = create("Frame", {
                Name = "Output",
                AnchorPoint = Vector2.new(0.5, 0),
                BackgroundColor3 = Color3.fromRGB(25, 25, 32),
                BorderColor3 = Color3.fromRGB(0, 0, 0),
                BorderSizePixel = 0,
                Position = UDim2.new(0.5, 0, 0, 70),
                Size = UDim2.new(1, -40, 1, -90),
            }, {
                uICorner2 = create("UICorner", {
                    CornerRadius = UDim.new(0, 6),
                }),

                uIStroke1 = create("UIStroke", {
                    Color = Color3.fromRGB(32, 32, 40),
                    Thickness = 1.3,
                }),

                messages = create("ScrollingFrame", {
                    Name = "Messages",
                    AutomaticCanvasSize = Enum.AutomaticSize.Y,
                    CanvasSize = UDim2.new(),
                    ScrollBarImageColor3 = Color3.fromRGB(136, 136, 168),
                    ScrollBarThickness = 3,
                    Active = true,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    Size = UDim2.fromScale(1, 1),
                }, {
                    uIListLayout = create("UIListLayout", {
                        SortOrder = Enum.SortOrder.LayoutOrder,
                    }),

                    uIPadding1 = create("UIPadding", {
                        PaddingBottom = UDim.new(0, 5),
                        PaddingLeft = UDim.new(0, 8),
                        PaddingRight = UDim.new(0, 8),
                        PaddingTop = UDim.new(0, 5),
                    }),
                }),
            }),
        },
    })          
    -- Writes a warning to the console. `dark` will shade the text.
    function extended:WriteWarn(message: string, dark: boolean?)
        create("TextLabel", {
            Parent = console.Output.Messages,
            Name = `WarningMessageOut`,
            FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
            RichText = true,
            Text = `<font color='#FFB82F'>[{os.date("%H:%M:%S")}] [WARN]</font> {message}`,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = if dark then Color3.fromRGB(139, 139, 139) else Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 20),
        })
    end

    function extended:WriteInfo(message: string, dark: boolean?)
        create("TextLabel", {
            Name = `InfoMessageOut`,
            Parent = console.Output.Messages,
            FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
            RichText = true,
            Text = `<font color='#C377FF'>[{os.date("%H:%M:%S")}] [INFO]</font> {message}`,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = if dark then Color3.fromRGB(139, 139, 139) else Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 20),
        })
    end

    function extended:WriteError(message: string, dark: boolean?)
        create("TextLabel", {
            Name = `ErrorMessageOut`,
            Parent = console.Output.Messages,
            FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
            RichText = true,
            Text = `<font color='#FF4949'>[{os.date("%H:%M:%S")}] [ERROR]</font> {message}`,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = 15,
            TextXAlignment = Enum.TextXAlignment.Left,
            BackgroundColor3 = if dark then Color3.fromRGB(139, 139, 139) else Color3.fromRGB(255, 255, 255),
            BackgroundTransparency = 1,
            BorderColor3 = Color3.fromRGB(0, 0, 0),
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 20),
        })
	end
	
	function extended:WriteDebug(message: string, dark: boolean?)
		create("TextLabel", {
			Name = `DebugMessageOut`,
			Parent = console.Output.Messages,
			FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
			RichText = true,
			Text = `<font color='#445626'>[{os.date("%H:%M:%S")}] [DEBUG]</font> {message}`,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = if dark then Color3.fromRGB(139, 139, 139) else Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 20),
		})
	end
	
	function extended:WriteLog(message: string, dark: boolean?)
		create("TextLabel", {
			Name = `DebugMessageOut`,
			Parent = console.Output.Messages,
			FontFace = Font.new("rbxassetid://16658246179", Enum.FontWeight.SemiBold, Enum.FontStyle.Normal),
			RichText = true,
			Text = `<font color='#FFF000'>[{os.date("%H:%M:%S")}] [GAME LOG]</font> {message}`,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
			BackgroundColor3 = if dark then Color3.fromRGB(139, 139, 139) else Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 20),
		})
	end
    
    config.write = function(message: string)
        extended:WriteDebug(message, false)
    end
    
    if options["Acrylic"] then
        store.acrylic = acrylic
        store.acrylic:Setup()
    end

	local window = base:CreateWindow({
		Name = "Window",
		Parent = view,
		Size = UDim2.fromOffset(600, 550),
		Position = UDim2.fromOffset(100, 100),
		BackgroundColor3 = Color3.fromRGB(21, 21, 26),
		CreateLayout = true,
    })
    
    if store["acrylic"] then
        window.BackgroundTransparency = 0.45
        store.acrylic:BindFrame(window, {
            Transparency = 0.9,
            BrickColor = BrickColor.new("Institutional white")
        })
    end

	local topPanel = create("Frame", {
		Name = "TopPanel",
		Parent = window,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 70),
	}, {
		create("UICorner"),
		create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 39, 48)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(23, 23, 29)),
			}),
			Rotation = 90,
		}),
		--create("UIListLayout", {
		--    HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween,
		--    FillDirection = Enum.FillDirection.Horizontal,
		--    SortOrder = Enum.SortOrder.LayoutOrder,
		--    VerticalAlignment = Enum.VerticalAlignment.Center,
		--}),
		create("UIPadding", {
			PaddingBottom = UDim.new(0, 10),
			PaddingLeft = UDim.new(0, 20),
			PaddingRight = UDim.new(0, 25),
			PaddingTop = UDim.new(0, 10),
		}),
		create("UIStroke", {
			Color = Color3.fromRGB(32, 32, 40),
		}),
	})

	local tabContainer = create("Frame", {
		Name = "TabContainer",
		Parent = topPanel,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.new(0, 310, 1, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
	}, {
		create("UIListLayout", {
			Padding = UDim.new(0, 10),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	})

	local title = create("TextLabel", {
		Name = "Title",
		Parent = topPanel,
		FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
		Text = string.upper(options.Title),
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromScale(0, 1),
	}, {
		uIGradient = create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(54, 54, 68)),
			}),
			Rotation = 90,
		}),
	})

	local windowView = create("Frame", {
		Name = "WindowView",
		Parent = window,
		BackgroundColor3 = Color3.fromRGB(255, 255, 255),
		BackgroundTransparency = 1,
		BorderColor3 = Color3.fromRGB(0, 0, 0),
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 0, 80),
		Size = UDim2.new(1, 0, 1, -80),
	})

	local function createTabButton(name: string, icon: string)
		local button = create("Frame", {
			Name = "TabButton",
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 1,
			BorderColor3 = Color3.fromRGB(0, 0, 0),
			BorderSizePixel = 0,
			LayoutOrder = 2,
			Size = UDim2.fromOffset(40, 40),
		}, {
			create("ImageButton", {
				Name = "OnActivated",
				Image = icon,
				ImageColor3 = Color3.fromRGB(139, 136, 176),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(30, 30),
				ZIndex = 2,
			}),

			create("ImageLabel", {
				Name = "Glow",
				Image = "rbxassetid://15450508239",
				ImageColor3 = Color3.fromRGB(193, 185, 255),
				ImageTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 20, 1, 20),
			}),

			create("ImageLabel", {
				Name = "SecondaryGlow",
				Image = "rbxassetid://16775815033",
				ImageColor3 = Color3.fromRGB(178, 178, 255),
				ImageTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 1, 15),
				Size = UDim2.new(1, 0, 1, 20),
			}),
		})

		-- Will re-write the tooltip code soon.

		return button
	end

	function extended:CreateTab(tabName: string, icon: string)
		local section = {}
		local tabButton = createTabButton(tabName, if icon then icon else "")
		local isHovering = false

		local newTab = {
			name = tabName,
			showing = false,
			display = create("ScrollingFrame", {
				Name = tabName,
				Size = UDim2.fromScale(1, 1),
				Visible = false,
			}, {
				create("UIListLayout", {
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				create("UIPadding", {
                    PaddingLeft = UDim.new(0, 1),
                    PaddingBottom = UDim.new(0, 1),
					PaddingRight = UDim.new(0, 1),
					PaddingTop = UDim.new(0, 10),
				}),
			}),
		}

		newTab.update = function(state: boolean)
			newTab.showing = state
			newTab.display.Visible = state

			TS:Create(
				tabButton.OnActivated,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad),
				{ ImageColor3 = (if state then Color3.fromRGB(193, 185, 255) else Color3.fromRGB(139, 136, 176)) }
			):Play()
			TS:Create(
				tabButton.Glow,
				TweenInfo.new(0.15, Enum.EasingStyle.Quad),
				{ ImageTransparency = (if state then 0 else 1) }
			):Play()
			TS:Create(
				tabButton.SecondaryGlow,
				TweenInfo.new(0.4, Enum.EasingStyle.Quad),
				{ ImageTransparency = (if state then 0 else 1) }
			):Play()
		end

		add_connection(tabButton:FindFirstChildOfClass("ImageButton").MouseEnter:Connect(function()
			if not states.react then
				return
			end

			if not isHovering and not newTab.showing then
				isHovering = true

				TS:Create(
					tabButton.OnActivated,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad),
					{ ImageColor3 = Color3.fromRGB(193, 185, 255) }
				):Play()
			end
		end))

		add_connection(tabButton:FindFirstChildOfClass("ImageButton").MouseLeave:Connect(function()
			if not states.react then
				return
			end

			if isHovering and not newTab.showing then
				isHovering = false

				TS:Create(
					tabButton.OnActivated,
					TweenInfo.new(0.15, Enum.EasingStyle.Quad),
					{ ImageColor3 = Color3.fromRGB(139, 136, 176) }
				):Play()
			end
		end))

		add_connection(tabButton:FindFirstChildOfClass("ImageButton").Activated:Connect(function()
			if not states.react then
				return
			end

			if newTab.showing then
				return
			end

			for _, tab in next, tabs do
				if tab.name ~= newTab.name and tab.showing then
					tab.update(false)
					break
				end
			end

			newTab.update(true)
			isHovering = false
		end))

		--> Create sides

		local left, right = nil, nil

		do
			left = create("Frame", {
				Name = "Left",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BackgroundTransparency = 1,
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(0.5, 0),
			}, {
				create("UIListLayout", {
					Padding = UDim.new(0, 20),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("UIPadding", {
					PaddingRight = UDim.new(0, 10),
				}),
			})

			right = create("Frame", {
				Name = "Right",
				AnchorPoint = Vector2.new(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(255, 255, 255),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.fromScale(0.5, 0),
			}, {
				create("UIListLayout", {
					Padding = UDim.new(0, 20),
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("UIPadding", {
					PaddingLeft = UDim.new(0, 10),
				}),
			})

			mount({ left, right }, newTab.display)
		end

		function section:CreateSection(name: string, alignment: Enums)
			if typeof(alignment) ~= "EnumItem" then
				return log("`alignment` argument takes an EnumItem!")
			end

			repeat
				task.wait()
			until (left and right) ~= nil

			local extended = {}

			local section = create("Frame", {
				Name = "Section",
				AutomaticSize = Enum.AutomaticSize.Y,
				BackgroundColor3 = Color3.fromRGB(25, 25, 32),
				BorderColor3 = Color3.fromRGB(0, 0, 0),
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 0),
			}, {
				create("UICorner"),

				create("UIStroke", {
					Color = Color3.fromRGB(32, 32, 40),
				}),

				create("TextLabel", {
					FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
					Text = string.upper(name),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 16,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					ClipsDescendants = true,
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 30),
				}, {
					uIGradient = create("UIGradient", {
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(107, 107, 107)),
						}),
						Rotation = 90,
					}),

					uIPadding = create("UIPadding", {
						PaddingBottom = UDim.new(0, 5),
						PaddingLeft = UDim.new(0, 15),
						PaddingTop = UDim.new(0, 5),
					}),
				}),

				uIListLayout = create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				uIPadding1 = create("UIPadding", {
					PaddingBottom = UDim.new(0, 10),
					PaddingTop = UDim.new(0, 5),
				}),
			})

			function extended:CreateSwitch(options)
				if options == nil then
					return log("options parameter is nil!")
				end

				local handler = {}
				local object = {
					type = "boolean",
					name = options.Name,
					state = create_observable(options.Enabled),
					keybind = create_observable(options.Keybind),
				}

				table.insert(created_components, object)

				local isHovering = false

				local hasKeybind = false
				local currentKeybind = if options.Keybind
					then UIS:GetStringForKeyCode(options.Keybind :: Enum.KeyCode)
					else ""
				local keybindInstance = nil

				local component = create("Frame", {
					Name = options.Name,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 30),
				}, {
					create("TextLabel", {
						Name = "Title",
						FontFace = Font.new(
							"rbxassetid://12187365364",
							Enum.FontWeight.SemiBold,
							Enum.FontStyle.Normal
						),
						Text = options.Name,
						TextColor3 = Color3.fromRGB(102, 101, 112),
						TextSize = 16,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						ClipsDescendants = true,
						LayoutOrder = 1,
						Size = UDim2.new(1, -90, 1, 0),
					}, {
						create("UIPadding", {
							PaddingLeft = UDim.new(0, 15),
						}),
					}),

					create("Frame", {
						Name = "State",
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.new(1, -15, 0.5, 0),
						Size = UDim2.new(0, 70, 1, 0),
					}, {
						create("ImageLabel", {
							Name = "Back",
							Image = "rbxassetid://15450190284",
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Position = UDim2.fromScale(1, 0.5),
							Size = UDim2.fromOffset(50, 20),
						}, {
							create("ImageLabel", {
								Name = "Knob",
								Image = "rbxassetid://15450191534",
								AnchorPoint = Vector2.new(0, 0.5),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Position = UDim2.new(0, 4, 0.5, 0),
								Size = UDim2.fromOffset(14, 14),
							}),

							create("TextButton", {
								Name = "OnActivated",
								FontFace = Font.new(
									"rbxassetid://12187365364",
									Enum.FontWeight.SemiBold,
									Enum.FontStyle.Normal
								),
								Text = "",
								TextColor3 = Color3.fromRGB(206, 204, 234),
								TextSize = 16,
								TextTruncate = Enum.TextTruncate.AtEnd,
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								ClipsDescendants = true,
								Size = UDim2.fromScale(1, 1),
							}),
						}),
					}),
				})

				if options.Keybind ~= nil then
					hasKeybind = true
					keybindInstance = create("Frame", {
						Name = "Keybind",
						AnchorPoint = Vector2.new(1, 0.5),
						BackgroundColor3 = Color3.fromRGB(55, 55, 71),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.new(1, -75, 0.5, 0),
						Size = UDim2.fromOffset(20, 20),
					}, {
						uICorner = create("UICorner", {
							CornerRadius = UDim.new(0, 5),
						}),

						uIStroke = create("UIStroke", {
							Color = Color3.fromRGB(38, 38, 48),
						}),

						editButton = create("ImageButton", {
							Name = "EditButton",
							Image = "rbxassetid://16428322530",
							ImageColor3 = Color3.fromRGB(121, 121, 156),
							ImageTransparency = 1,
							AutoButtonColor = false,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.fromRGB(93, 93, 120),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(14, 14),
						}),

						current = create("TextLabel", {
							Name = "Current",
							FontFace = Font.new(
								"rbxassetid://12187365364",
								Enum.FontWeight.SemiBold,
								Enum.FontStyle.Normal
							),
							TextColor3 = Color3.fromRGB(130, 129, 167),
							TextSize = 14,
							AnchorPoint = Vector2.new(0.5, 0.5),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Position = UDim2.fromScale(0.5, 0.5),
							Size = UDim2.fromOffset(14, 14),
						}, {
							uIPadding = create("UIPadding", {
								PaddingRight = UDim.new(0, 0),
							}),
						}),
					})

					local isContainerHovering = false

					local function update(new: Enum.KeyCode)
						if not states.react then
							return
						end

						if isContainerHovering then
							isContainerHovering = false
						end

						currentKeybind = UIS:GetStringForKeyCode(new)
						keybindInstance:FindFirstChild("Current").Text = currentKeybind

						TS:Create(keybindInstance.EditButton, TweenInfo.new(0.1), {
							ImageTransparency = if currentKeybind == "" then 0 else 1,
						}):Play()

						TS:Create(keybindInstance.Current, TweenInfo.new(0.15), {
							TextTransparency = 0,
						}):Play()
					end

					object.keybind.onChanged(update)

					add_connection(keybindInstance.MouseEnter:Connect(function()
						if not states.react then
							return
						end

						isContainerHovering = true
						TS:Create(keybindInstance.EditButton, TweenInfo.new(0.15), {
							ImageColor3 = Color3.fromRGB(158, 158, 204),
							ImageTransparency = 0,
						}):Play()
						TS:Create(keybindInstance.Current, TweenInfo.new(0.15), {
							TextTransparency = 1,
						}):Play()
					end))

					add_connection(keybindInstance.MouseLeave:Connect(function()
						if not states.react then
							return
						end

						isContainerHovering = false
						TS:Create(keybindInstance.EditButton, TweenInfo.new(0.15), {
							ImageColor3 = Color3.fromRGB(121, 121, 156),
							ImageTransparency = 1,
						}):Play()
						TS:Create(keybindInstance.Current, TweenInfo.new(0.15), {
							TextTransparency = 0,
						}):Play()
					end))

					add_connection(keybindInstance.EditButton.Activated:Connect(function()
						if not states.react then
							return
						end

						local c
						c = UIS.InputBegan:Connect(function(input: InputObject)
							if input.UserInputType == Enum.UserInputType.Keyboard then
								object.keybind.set(input.KeyCode)
								c:Disconnect()
							end
						end)
					end))

					update(object.keybind.get())

					mount(keybindInstance, component)
				end

				local function update(v: boolean)
					if not states.react then
						return
					end

					TS:Create(
						component.Title,
						TweenInfo.new(0.23, Enum.EasingStyle.Circular),
						{ TextColor3 = (if v then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(102, 101, 112)) }
					):Play()
					TS:Create(
						component.State.Back,
						TweenInfo.new(0.23, Enum.EasingStyle.Circular),
						{ ImageColor3 = (if v then Color3.fromRGB(180, 178, 230) else Color3.fromRGB(51, 51, 65)) }
					):Play()
					TS:Create(
						component.State.Back.Knob,
						TweenInfo.new(0.23, Enum.EasingStyle.Circular),
						{ Position = (if v then UDim2.new(0, 32, 0.5, 0) else UDim2.new(0, 4, 0.5, 0)) }
					):Play()

					local suc, req = pcall(options.OnChanged, v)

					if not suc then
						return log(req)
					end
				end

				object.state.onChanged(update)

				add_connection(component.State.Back:FindFirstChild("OnActivated").Activated:Connect(function()
					if not states.react then
						return
					end

					object.state.set(not object.state.get())
				end))

				add_connection(component.MouseEnter:Connect(function()
					if not states.react then
						return
					end

					if not isHovering and not object.state.get() then
						isHovering = true

						TS:Create(
							component.Title,
							TweenInfo.new(0.23, Enum.EasingStyle.Circular),
							{ TextColor3 = (Color3.fromRGB(244, 244, 244)) }
						):Play()
					end
				end))

				add_connection(component.MouseLeave:Connect(function()
					if not states.react then
						return
					end

					if isHovering and not object.state.get() then
						isHovering = false

						TS:Create(
							component.Title,
							TweenInfo.new(0.23, Enum.EasingStyle.Circular),
							{ TextColor3 = (Color3.fromRGB(102, 101, 112)) }
						):Play()
					end
				end))

				add_connection(UIS.InputBegan:Connect(function(input: InputObject)
					if not states.react then
						return
					end

					if input.UserInputType == Enum.UserInputType.Keyboard and hasKeybind then
						if input.KeyCode == object.keybind.get() then
							object.state.set(not object.state.get())
						end
					end
				end))

				update(object.state.get())
				mount(component, section)

				function handler:set(v: boolean)
					object.state.set(v)
				end

				function handler:get()
					return object.state.get()
				end

				return handler
			end

			function extended:CreateButton(name: string, callback: () -> ())
				local isHovering = create_observable(false)
				local isDown = create_observable(false)

				local component = create("Frame", {
					Name = name,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 40),
				}, {
					create("UIPadding", {
						PaddingLeft = UDim.new(0, 15),
						PaddingRight = UDim.new(0, 15),
					}),
					create("Frame", {
						Name = "Container",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, 0, 1, -10),
					}, {
						create("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),

						create("TextButton", {
							Name = "OnActivated",
							FontFace = Font.new(
								"rbxassetid://12187365364",
								Enum.FontWeight.SemiBold,
								Enum.FontStyle.Normal
							),
							Text = name,
							TextColor3 = Color3.fromRGB(138, 137, 152),
							TextSize = 16,
							TextTruncate = Enum.TextTruncate.AtEnd,
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							ClipsDescendants = true,
							Size = UDim2.fromScale(1, 1),
						}, {
							create("UIPadding", {
								PaddingLeft = UDim.new(0, 5),
								PaddingRight = UDim.new(0, 5),
							}),
						}),

						create("UIGradient", {
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 57, 74)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 42, 52)),
							}),
							Rotation = 90,
						}),

						create("UIStroke", {
							Color = Color3.fromRGB(38, 38, 48),
						}),
					}),
				})

				isDown.onChanged(function(v)
					if not states.react then
						return
					end

					TS:Create(
						component.Container,
						TweenInfo.new(0.125, Enum.EasingStyle.Quad),
						{ BackgroundTransparency = (if v then 0.4 else 0) }
					):Play()
				end)

				isHovering.onChanged(function(v)
					if not states.react then
						return
					end

					if isDown.get() then
						return
					end

					TS:Create(
						component.Container,
						TweenInfo.new(0.125, Enum.EasingStyle.Quad),
						{ BackgroundTransparency = (if v then 0.2 else 0) }
					):Play()
					TS:Create(
						component.Container.OnActivated,
						TweenInfo.new(0.125, Enum.EasingStyle.Quad),
						{ TextColor3 = (if v then Color3.fromRGB(190, 190, 201) else Color3.fromRGB(138, 137, 152)) }
					):Play()
				end)

				add_connection(component.Container.OnActivated.MouseButton1Down:Connect(function()
					if not states.react then
						return
					end

					if not isDown.get() then
						isDown.set(true)
					end
				end))

				add_connection(component.Container.OnActivated.MouseButton1Up:Connect(function()
					if not states.react then
						return
					end

					if isDown.get() and isHovering.get() then
						isDown.set(false)
					end
				end))

				add_connection(component.Container.MouseEnter:Connect(function()
					if not states.react then
						return
					end

					if not isHovering.get() then
						isHovering.set(true)
					end
				end))

				add_connection(component.Container.MouseLeave:Connect(function()
					if not states.react then
						return
					end

					if isHovering.get() then
						isHovering.set(false)
					end
				end))

				add_connection(component.Container.OnActivated.Activated:Connect(function()
					if not states.react then
						return
					end

					if callback then
						local suc, req = pcall(callback)
						if not suc then
							log(req)
						end
					end
				end))

				mount(component, section)
			end

			function extended:CreateSlider(options)
				if not options then
					return log("Options parameter is nil")
				end

				local min, max, value =
					options.Range[1], options.Range[2], create_observable(options.Value or options.Range[1])
				local dragging = false
				local format = options.Format

				local component = create("Frame", {
					Name = options.Name,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 50),
				}, {
					create("TextLabel", {
						Name = "Title",
						FontFace = Font.new(
							"rbxassetid://12187365364",
							Enum.FontWeight.SemiBold,
							Enum.FontStyle.Normal
						),
						Text = options.Name,
						TextColor3 = Color3.fromRGB(102, 101, 112),
						TextSize = 16,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextXAlignment = Enum.TextXAlignment.Left,
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						ClipsDescendants = true,
						LayoutOrder = 1,
						Size = UDim2.new(1, -50, 0, 30),
					}, {
						uIPadding = create("UIPadding", {
							PaddingLeft = UDim.new(0, 15),
						}),
					}),

					create("TextLabel", {
						Name = "Value",
						FontFace = Font.new(
							"rbxassetid://12187365364",
							Enum.FontWeight.SemiBold,
							Enum.FontStyle.Normal
						),
						Text = "25.5f",
						TextColor3 = Color3.fromRGB(102, 101, 112),
						TextSize = 15,
						TextTruncate = Enum.TextTruncate.None,
						TextXAlignment = Enum.TextXAlignment.Right,
						AnchorPoint = Vector2.new(1, 0),
						AutomaticSize = Enum.AutomaticSize.Y,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						ClipsDescendants = true,
						LayoutOrder = 1,
						Position = UDim2.fromScale(1, 0),
						Size = UDim2.fromOffset(65, 30),
					}, {
						uIPadding1 = create("UIPadding", {
							PaddingRight = UDim.new(0, 15),
						}),
					}),

					create("Frame", {
						Name = "Display",
						AnchorPoint = Vector2.new(0.5, 1),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.new(0.5, 0, 1, -15),
						Size = UDim2.new(1, -30, 0, 5),
					}, {
						uIGradient = create("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 56, 62)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 32)),
							}),
						}),

						create("TextButton", {
							Name = "OnActivated",
							Size = UDim2.fromScale(1, 1),
							BackgroundTransparency = 1,
							Text = "",
						}),

						create("Frame", {
							Name = "Fill",
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Size = UDim2.new(0.25, 5, 1, 0),
						}, {
							uIGradient1 = create("UIGradient", {
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(111, 103, 214)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 182, 244)),
								}),
							}),

							knob = create("ImageLabel", {
								Image = "rbxassetid://15489848868",
								AnchorPoint = Vector2.new(1, 0.5),
								BackgroundColor3 = Color3.fromRGB(255, 255, 255),
								BackgroundTransparency = 1,
								BorderColor3 = Color3.fromRGB(0, 0, 0),
								BorderSizePixel = 0,
								Position = UDim2.fromScale(1, 0.5),
								Size = UDim2.fromOffset(13, 13),
							}),
						}),
					}),
				})

				local minSize = 15

				local function update(v)
					if not states.react then
						return
					end

					local percentage = (v - min) / (max - min)
					local new = math.max(minSize, percentage * component.Display.AbsoluteSize.X)
					component.Display.Fill.Size = UDim2.new(0, new, 1, 0)
					component.Value.Text = string.format(format or "%.2f", v)

					local suc, req = pcall(options.OnChanged, math.round(v))
					assert(suc, `Failed to call slider ({options.Name}) callback: {req}`)
				end

				local initialValue = options.Value or min
				task.defer(update, initialValue)

				value.onChanged(update)

				add_connection(component.Display.OnActivated.MouseButton1Down:Connect(function(x)
					if not states.react then
						return
					end

					if not dragging then
						dragging = true

						local relativeX = math.clamp(
							UIS:GetMouseLocation().X - component.Display.AbsolutePosition.X + (minSize / 2),
							0,
							component.Display.AbsoluteSize.X
						)
						local new = min + (max - min) * (relativeX / component.Display.AbsoluteSize.X)
						if component.Display.Fill.Size.X.Offset >= minSize then
							value.set(new)
						end
					end
				end))

				add_connection(component.Display.OnActivated.InputEnded:Connect(function(i: InputObject)
					if not states.react then
						return
					end

					if i.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
						dragging = false
					end
				end))

				add_connection(UIS.InputChanged:Connect(function(i: InputObject)
					if not states.react then
						return
					end

					if i.UserInputType == Enum.UserInputType.MouseMovement and dragging then
						local relativeX = math.clamp(
							i.Position.X - component.Display.AbsolutePosition.X + (minSize / 2),
							0,
							component.Display.AbsoluteSize.X
						)
						local new = min + (max - min) * (relativeX / component.Display.AbsoluteSize.X)
						if component.Display.Fill.Size.X.Offset >= minSize then
							value.set(new)
						end
					end
				end))

				mount(component, section)
			end

            function extended:CreateCombo(options)
                local extended = {}
				options = options
					or {
						Name = options.Name or "Combo",
						Items = options.Items or {},
						Default = options.Default or "",
						Multi = options.Multi or false,
						OnSelected = options.OnSelected or function(item: any | { string })
							print(item)
						end,
					}

				local component = create("Frame", {
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 60),
				}, {
					uIPadding = create("UIPadding", {
						PaddingLeft = UDim.new(0, 15),
						PaddingRight = UDim.new(0, 15),
					}),

					container = create("Frame", {
						Name = "Container",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.new(0.5, 0, 0.5, 10),
						Size = UDim2.new(1, 0, 0, 30),
					}, {
						uICorner = create("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),

						uIGradient = create("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 57, 74)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 42, 52)),
							}),
							Rotation = 90,
						}),

						image = create("ImageLabel", {
							Name = "Image",
							Image = "rbxassetid://15450356515",
							ImageColor3 = Color3.fromRGB(108, 108, 135),
							ImageTransparency = 0.3,
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Position = UDim2.new(1, -7, 0.5, 0),
							Size = UDim2.fromOffset(20, 20),
						}),

						onActivated = create("TextButton", {
							Name = "OnActivated",
							FontFace = Font.new(
								"rbxassetid://12187365364",
								Enum.FontWeight.SemiBold,
								Enum.FontStyle.Normal
							),
							Text = "Selection",
							TextColor3 = Color3.fromRGB(102, 101, 112),
							TextSize = 16,
							TextXAlignment = Enum.TextXAlignment.Left,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            TextTruncate = Enum.TextTruncate.AtEnd,
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Size = UDim2.fromScale(1, 1),
						}, {
							uIPadding1 = create("UIPadding", {
                                PaddingLeft = UDim.new(0, 10),
                                PaddingRight = UDim.new(0, 20),
							}),
						}),
					}),

					title = create("TextLabel", {
						Name = "Title",
						FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
						Text = options.Name,
						TextColor3 = Color3.fromRGB(102, 101, 112),
						TextSize = 16,
						TextXAlignment = Enum.TextXAlignment.Left,
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BackgroundTransparency = 1,
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Size = UDim2.new(1, 0, 0, 20),
					}),
				})

				local items = create("Frame", {
					Name = "Items",
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(32, 32, 40),
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 3,
					Position = UDim2.fromScale(0, 1.03),
					Visible = false,
					Size = UDim2.fromScale(1, 0),
					ZIndex = 99,
				}, {
					uICorner = create("UICorner", {
						CornerRadius = UDim.new(0, 6),
					}),

					--scrollingFrame = create("ScrollingFrame", {
					--    Name = "MainContainer",
					--    AutomaticCanvasSize = Enum.AutomaticSize.Y,
					--    CanvasPosition = Vector2.new(0, 25),
					--    CanvasSize = UDim2.new(),
					--    ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
					--    ScrollBarThickness = 0,
					--    Active = true,
					--    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					--    BackgroundTransparency = 1,
					--    BorderColor3 = Color3.fromRGB(0, 0, 0),
					--    BorderSizePixel = 0,
					--    Size = UDim2.new(1, 0, 0, 31),
					--}, {
					--    uIListLayout = create("UIListLayout", {
					--        HorizontalAlignment = Enum.HorizontalAlignment.Center,
					--        SortOrder = Enum.SortOrder.LayoutOrder,
					--    }),

					--    uIPadding = create("UIPadding", {
					--        PaddingBottom = UDim.new(0, 3),
					--        PaddingLeft = UDim.new(0, 3),
					--        PaddingRight = UDim.new(0, 3),
					--        PaddingTop = UDim.new(0, 3),
					--    }),
					--}),

					uIStroke = create("UIStroke", {
						Color = Color3.fromRGB(36, 36, 44),
					}),

					uIPadding1 = create("UIPadding", {
						PaddingBottom = UDim.new(0, 3),
						PaddingLeft = UDim.new(0, 3),
						PaddingRight = UDim.new(0, 3),
						PaddingTop = UDim.new(0, 3),
					}),

					uIListLayout = create("UIListLayout", {
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				})

                local open = create_observable(false)
                local newItems = create_observable(options.Items)
				local offset = create_observable(0)
				local selected = create_observable(if options.Multi then {} else "")

                local function createItem(v: any)
                    offset.set(offset.get() + 25)
                    return create("Frame", {
                        BackgroundColor3 = Color3.fromRGB(41, 41, 53),
                        BackgroundTransparency = 1,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Size = UDim2.new(1, 0, 0, 25),
                        ZIndex = 99,
                    }, {
                        uICorner1 = create("UICorner", {
                            CornerRadius = UDim.new(0, 5),
                        }),

                        onActivated = create("TextButton", {
                            Name = "OnActivated",
                            FontFace = Font.new(
                                "rbxassetid://12187365364",
                                Enum.FontWeight.Medium,
                                Enum.FontStyle.Normal
                            ),
                            Text = v,
                            TextColor3 = Color3.fromRGB(216, 216, 216),
                            TextSize = 15,
                            TextXAlignment = Enum.TextXAlignment.Left,
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BackgroundTransparency = 1,
                            BorderColor3 = Color3.fromRGB(0, 0, 0),
                            BorderSizePixel = 0,
                            Size = UDim2.fromScale(1, 1),
                            ZIndex = 99,
                        }, {
                            uIPadding1 = create("UIPadding", {
                                PaddingLeft = UDim.new(0, 10),
                            }),
                        }),

                        selected = create("ImageLabel", {
                            Name = "Selected",
                            Image = "rbxassetid://16775992601",
                            ImageColor3 = Color3.fromRGB(123, 115, 231),
                            AnchorPoint = Vector2.new(1, 0.5),
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BackgroundTransparency = 1,
                            ImageTransparency = 1,
                            BorderColor3 = Color3.fromRGB(0, 0, 0),
                            BorderSizePixel = 0,
                            Position = UDim2.new(1, -10, 0.5, 0),
                            Size = UDim2.fromOffset(10, 10),
                            ZIndex = 99,
                        }),
                    })
                end

                local function createItems()
                    for _, item in newItems.get() do
                        if has_dupe(item, newItems.get()) then
                            error(`Duplicate item found in dropdown option: {options.name}.`)
                        end

                        local itemComponent = createItem(item)

                        add_connection(itemComponent.OnActivated.Activated:Connect(function()
                            if not states.react then
                                return
                            end

                            if options.Multi then
                                local selectedItems = selected.get()
                                if table.find(selectedItems, item) then
                                    table.remove(selectedItems, table.find(selectedItems, item))
                                else
                                    table.insert(selectedItems, item)
                                end

                                selected.set(selectedItems)
                            else
                                selected.set(item)
                            end
                        end))

                        add_connection(itemComponent.MouseEnter:Connect(function()
                            if not states.react then
                                return
                            end

                            TS:Create(itemComponent, TweenInfo.new(0.1), {
                                BackgroundTransparency = 0.7,
                            }):Play()
                        end))

                        add_connection(itemComponent.MouseLeave:Connect(function()
                            if not states.react then
                                return
                            end

                            TS:Create(itemComponent, TweenInfo.new(0.1), {
                                BackgroundTransparency = 1,
                            }):Play()
                        end))

                        selected.onChanged(function(v)
                            if not states.react then
                                return
                            end

                            TS:Create(itemComponent.Selected, TweenInfo.new(0.1), {
                                ImageTransparency = if options.Multi
                                    then (table.find(v, item) and 0 or 1)
                                    else (v == item and 0 or 1),
                            }):Play()
                        end)

                        mount(itemComponent, items)
                    end
                end

				open.onChanged(function(v: boolean)
					if not states.react then
						return
					end

					items.Visible = v
				end)

				offset.onChanged(function(v: number)
					if not states.react then
						return
					end
					--if v == 275 then
					--    return
					--end

					items.Size = UDim2.new(1, 0, 0, v)
				end)

				selected.onChanged(function(v)
					if not states.react then
						return
					end

					component.Container.OnActivated.Text = options.Multi and table.concat(v, ", ") or v
					local suc, req = pcall(options.OnSelected, v)
					assert(suc, `Failed to call OnSelected: {req}`)
				end)

				add_connection(component.Container.OnActivated.Activated:Connect(function()
					if not states.react then
						return
					end

					open.set(not open.get())
				end))

				add_connection(component.Container.OnActivated:GetPropertyChangedSignal("Text"):Connect(function(text)
					if text == "" then
						component.Container.OnActivated.Text = "None"
					end
				end))

				add_connection(component.Container.MouseEnter:Connect(function()
					if not states.react then
						return
					end

					TS:Create(component.Container.OnActivated, TweenInfo.new(0.1), {
						TextColor3 = Color3.fromRGB(188, 187, 207),
					}):Play()
				end))

				add_connection(component.Container.MouseLeave:Connect(function()
					if not states.react then
						return
					end

					TS:Create(component.Container.OnActivated, TweenInfo.new(0.1), {
						TextColor3 = Color3.fromRGB(102, 101, 112),
					}):Play()
				end))

				if table.find(options.Items, options.Default) then
					selected.set(options.Default)
				else
					selected.set(options.Default)
				end

				mount(items, component)
                mount(component, section)
                
                createItems()
                
                
                return extended
			end

			function extended:CreateLabel(content: string)
				local ex = {}

				local component = create("TextLabel", {
					Name = "Title",
					FontFace = Font.new("rbxassetid://12187365364", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextSize = 16,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Top,
					AutomaticSize = Enum.AutomaticSize.Y,
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					ClipsDescendants = true,
					LayoutOrder = 1,
					Size = UDim2.new(1, 0, 0, 30),
				}, {
					create("UIPadding", {
						Name = "UIPadding",
						PaddingBottom = UDim.new(0, 5),
						PaddingLeft = UDim.new(0, 15),
						PaddingTop = UDim.new(0, 5),
					}),
				})

				local text = create_observable("")

				text.onChanged(function(v: string)
					if not states.react then
						return
					end

					component.Text = v
				end)

				text.set(content)

				mount(component, section)

				function ex:Set(new: string)
					if text.get() ~= new then
						text.set(new)
					end
				end

				return ex
			end

			function extended:CreateInput(options)
				options = options
					or {
						Placeholder = options.Placeholder or "Input",
						Reset = options.Reset or false,
						OnTextChanged = options.OnTextChanged or nil,
						OnTextComitted = options.OnTextComitted or nil
					}

				local component = create("Frame", {
					Name = "TextfieldOption",
					BackgroundColor3 = Color3.fromRGB(255, 255, 255),
					BackgroundTransparency = 1,
					BorderColor3 = Color3.fromRGB(0, 0, 0),
					BorderSizePixel = 0,
					LayoutOrder = 2,
					Size = UDim2.new(1, 0, 0, 40),
				}, {
					uIPadding = create("UIPadding", {
						PaddingLeft = UDim.new(0, 15),
						PaddingRight = UDim.new(0, 15),
					}),

					container = create("Frame", {
						Name = "Container",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundColor3 = Color3.fromRGB(255, 255, 255),
						BorderColor3 = Color3.fromRGB(0, 0, 0),
						BorderSizePixel = 0,
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, 0, 1, -10),
					}, {
						uICorner = create("UICorner", {
							CornerRadius = UDim.new(0, 6),
						}),

						uIGradient = create("UIGradient", {
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 57, 74)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(42, 42, 52)),
							}),
							Rotation = 90,
						}),

						input = create("TextBox", {
							Name = "Input",
							ClearTextOnFocus = options.Reset,
							FontFace = Font.new(
								"rbxassetid://12187365364",
								Enum.FontWeight.SemiBold,
								Enum.FontStyle.Normal
							),
							PlaceholderColor3 = Color3.fromRGB(156, 154, 177),
							PlaceholderText = options.Placeholder,
							ShowNativeInput = false,
							Text = "",
							TextColor3 = Color3.fromRGB(206, 204, 234),
							TextSize = 16,
							TextTruncate = Enum.TextTruncate.AtEnd,
							TextXAlignment = Enum.TextXAlignment.Left,
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Size = UDim2.new(1, -30, 1, 0),
						}, {
							uIPadding1 = create("UIPadding", {
								PaddingLeft = UDim.new(0, 10),
							}),
						}),

						image = create("ImageLabel", {
							Name = "Image",
							Image = "rbxassetid://15450356515",
							ImageColor3 = Color3.fromRGB(108, 108, 135),
							ImageTransparency = 0.3,
							AnchorPoint = Vector2.new(1, 0.5),
							BackgroundColor3 = Color3.fromRGB(255, 255, 255),
							BackgroundTransparency = 1,
							BorderColor3 = Color3.fromRGB(0, 0, 0),
							BorderSizePixel = 0,
							Position = UDim2.new(1, -7, 0.5, 0),
							Size = UDim2.fromOffset(20, 20),
						}),
					}),
				})

				add_connection(component.Container.Input.FocusLost:Connect(function(entered)
					if not states.react then
						return
					end

					if entered and options.OnTextComitted then
						local suc, req = pcall(options.OnTextComitted, component.Container.Input.Text)
						assert(suc, `Failed to call OnTextComitted: {req}`)

						return
					end

					if options.OnTextChanged then 
						local suc, req = pcall(options.OnTextChanged, component.Container.Input.Text)
						assert(suc, `Failed to call OnTextChanged: {req}`)
					end
				end))

				mount(component, section)
			end

            function extended:CreateView(options) 
                local component = create("Frame", {
                    Name = `View:{options.Name}`,
                    Parent = section,
                    AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundTransparency = 1,
                    BorderColor3 = Color3.fromRGB(0, 0, 0),
                    BorderSizePixel = 0,
                    LayoutOrder = 2,
                    Size = UDim2.fromScale(1, 0),
                }, {
                    title = create("TextLabel", {
                        Name = "Title",
                        FontFace = Font.new(
                            "rbxassetid://12187365364",
                            Enum.FontWeight.Bold,
                            Enum.FontStyle.Normal
                        ),
                        Text = options.Name,
                        TextColor3 = Color3.fromRGB(255, 255, 255),
                        TextSize = 16,
                        TextTruncate = Enum.TextTruncate.AtEnd,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 1,
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        ClipsDescendants = true,
                        LayoutOrder = 1,
                        Size = UDim2.new(1, 0, 0, 30),
                    }, {
                        uIGradient = create("UIGradient", {
                            Color = ColorSequence.new({
                                ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
                                ColorSequenceKeypoint.new(1, Color3.fromRGB(107, 107, 107)),
                            }),
                            Rotation = 90,
                        }),

                        uIPadding = create("UIPadding", {
                            PaddingLeft = UDim.new(0, 15),
                            PaddingTop = UDim.new(0, 5),
                        }),
                    }),

                    container = create("Frame", {
                        Name = "Container",
                        AnchorPoint = Vector2.new(0.5, 0),
                        AutomaticSize = Enum.AutomaticSize.Y,
                        BackgroundColor3 = Color3.fromRGB(30, 30, 39),
                        BorderColor3 = Color3.fromRGB(0, 0, 0),
                        BorderSizePixel = 0,
                        Position = UDim2.new(0.5, 0, 0, 30),
                        Size = UDim2.new(1, -30, 0, 0),
                    }, {
                        uISizeConstraint = create("UISizeConstraint", {
                            MinSize = Vector2.new(0, 100),
                        }),

                        uICorner = create("UICorner", {
                            CornerRadius = UDim.new(0, 6),
                        }),

                        uIStroke = create("UIStroke", {
                            Color = Color3.fromRGB(42, 42, 54),
                        }),

                        viewportFrame = create("ViewportFrame", {
                            Name = "ViewportFrame",
                            BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                            BackgroundTransparency = 1,
                            BorderColor3 = Color3.fromRGB(0, 0, 0),
                            BorderSizePixel = 0,
                            Size = UDim2.fromScale(1, 1),
                        }),
                    }),

                    uIPadding1 = create("UIPadding", {
                        PaddingBottom = UDim.new(0, 5),
                    }),
                })
                
                local viewCam = create("Camera", {
                    Parent = component.Container.ViewportFrame
                })
                
                if options.Target.Parent == nil then 
                    options.Target.Parent = component.Container.ViewportFrame
                end    
                
                component.Container.ViewportFrame.CurrentCamera = viewCam
                
                local extended = {}
                
                function extended:SetPosition(position: Vector3) 
                    viewCam.CFrame = CFrame.new(position, options.Target.Position)
                end 
                
                return extended
            end

			local function getAlignment()
				if alignment == Enum.HorizontalAlignment.Left then
					return left
				end

				if alignment == Enum.HorizontalAlignment.Right then
					return right
				end
			end

			mount(section, getAlignment())

			return extended
		end

		mount(newTab.display, windowView)
		mount(tabButton, tabContainer)
		table.insert(tabs, newTab)

		return section
	end

	function extended:CreateDialog(options)
		createDialog(window, options)
	end

	function extended:OnKeybind(keybind: Enum.KeyCode, callback: () -> ())
		add_connection(UIS.InputBegan:Connect(function(a0: InputObject, a1: boolean)
			if a0.KeyCode == keybind then
				local suc, req = pcall(callback)
				assert(suc, `Failed to call OnKeybind: {req}`)
			end
		end))
	end

	task.defer(function()
		tabs[1].showing = true
		tabs[1].update(true)

		local configNum = create("NumberValue", { Name = "Config" })
		mount(configNum, view)

		open.onChanged(function(v)
			window.Visible = v
		end)

		UIS.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
			if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == options.Keybind then
				open.set(not open.get())
			end
		end)
	end)

	-- Used for configs.
	local function getComponents()
		return created_components
    end
    
    print(`Length of created_components array: {#getComponents()}`)

	return extended
end

local window = library:init({ Title = "Catalyst", Keybind = Enum.KeyCode.RightShift, Open = true, Acrylic = false})

window:OnKeybind(Enum.KeyCode.B, function()
	print("Pressed B")
end)

local tab1 = window:CreateTab("Tab 1", "rbxassetid://15450003734")
local testing = window:CreateTab("Testing", "rbxassetid://15450003734")
local Settings = window:CreateTab("Settings", "rbxassetid://10734950309")

local testing_console = testing:CreateSection("Console", Enum.HorizontalAlignment.Left)
local message_type = create_observable("")

testing_console:CreateInput({
	Placeholder = "Output",
	Reset = false,
	OnTextChanged = function(message)
		if message_type.get() == "Info" then 
			window:WriteInfo(message)
		elseif message_type.get() == "Warn" then
			window:WriteWarn(message)
		elseif message_type.get() == "Error" then
			window:WriteError(message)
		elseif message_type.get() == "Debug" then
            window:WriteDebug(message)
		else
			window:WriteError("Unknown message type.")
		end
	end
})

testing_console:CreateCombo({
	Name = "Types",
	Items = { "Info", "Warn", "Error", "Debug" },
	Default = "Info",
	OnSelected = function(item: any)
		message_type.set(item)
	end,
})

local section = tab1:CreateSection("main", Enum.HorizontalAlignment.Left)
local right = tab1:CreateSection("misc", Enum.HorizontalAlignment.Right)

section:CreateButton("Show Dialog", function()
	window:CreateDialog({
		Title = "Dialog",
		Message = "This is a test dialog.",
		OnAction = function(action)
			print(`{action} action was pressed!`)
		end,
	})
end)

section:CreateSwitch({
	Name = "Flag 1",
	Enabled = false,
	OnChanged = function(v)
		print(v)
	end,
})

local label = section:CreateLabel("Label")
section:CreateSwitch({ Name = "Flag 2", Enabled = false })
section:CreateSwitch({ Name = "Flag 3", Enabled = false, Keybind = Enum.KeyCode.Q })
section:CreateButton("Set label", function()
	label:Set("Hello, world!")
end)

section:CreateSlider({
	Name = "Slider",
	Range = { -100, 100 },
	Value = 0,
	Format = "%d",
	OnChanged = function(v)
		print(v)
	end,
})

section:CreateInput({
	Placeholder = "Name",
	Reset = false,
	OnTextChanged = function(name)
		print(`Hello, {name}`)
	end,
})

right:CreateCombo({
	Name = "Dropdown",
	Items = { "Hello", "World", "!" },
	Default = "Hello",
	OnSelected = function(item: any)
		print(item)
	end,
})

right:CreateCombo({
	Name = "Multi",
	Items = { "1", "2", "3", "4", "5" },
	Multi = true,
	Default = { "1" },
	OnSelected = function(items)
		print(table.concat(items, ", "))
	end,
})

local target = create("Part", {
    Material = Enum.Material.Concrete,
    Color = Color3.new(0.25, 0.75, 1),
    Position = Vector3.new(0, 0, 0),
})
right:CreateView({
    Name = "VIEW",
    Target = target,
}):SetPosition(Vector3.new(0, 2, 12))

