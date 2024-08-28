local Replicated = game:GetService('ReplicatedStorage')
local TweenService = game:GetService('TweenService')
local MarketplaceService = game:GetService('MarketplaceService')
local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local ProductsModule = require(Replicated:WaitForChild('Modules'):WaitForChild('Products'):WaitForChild('Core'))
local LocalPlayer = Players.LocalPlayer

local Frame = script.Parent
local Templates = script:WaitForChild('Templates')

local Primary = Frame:WaitForChild('Primary')

local Main = Primary:WaitForChild('Main')
local Sidebar = Primary:WaitForChild('Sidebar')

-- Variables
local Default = Sidebar:WaitForChild('Default')
local CurrentlyOpenedTab = nil

-- Configurations
local Configurations = {
	Offers = {
		GradientOffset = 2,
		GradientWaitBetween = 1.5,
		GradientTweenLength = 4,
	},
	
	Sidebar = {
		GradientOffset = 1,
		GradientWaitBetween = 2,
		GradientTweenLength = 1.5,
	},
	
	SpecialTemplateColor = Color3.fromRGB(254, 183, 33)
}

-- More gradient stuff
local OffersFinalGradientOffset = (Configurations.Offers.GradientOffset / Configurations.Offers.GradientTweenLength) * (Configurations.Offers.GradientTweenLength + Configurations.Offers.GradientWaitBetween)
local OffersGradientTweenInfo = TweenInfo.new((Configurations.Offers.GradientWaitBetween + Configurations.Offers.GradientTweenLength), Enum.EasingStyle.Sine, Enum.EasingDirection.Out, -1, false)

local SidebarFinalGradientOffset = (Configurations.Sidebar.GradientOffset / Configurations.Sidebar.GradientTweenLength) * (Configurations.Sidebar.GradientTweenLength + Configurations.Sidebar.GradientWaitBetween)
local SidebarGradientTweenInfo = TweenInfo.new((Configurations.Sidebar.GradientWaitBetween + Configurations.Sidebar.GradientTweenLength), Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local SidebarGradientTweenBackInfo = TweenInfo.new(Configurations.Sidebar.GradientTweenLength, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

-- Functions
local function CommonTween(Button)
	local Playing = TweenService:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, false),
		{Position = Button.Shadow.Position})
	
	Playing:Play()
	Playing.Completed:Wait()

	Playing = TweenService:Create(
		Button.Main,
		TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false),
		{Position = UDim2.fromScale(0.5, 0)})
	
	Playing:Play()
	Playing.Completed:Wait()
end

local function Switch(Button)
	if Button ~= CurrentlyOpenedTab then
		for _, Frame in pairs(Main:GetChildren()) do
			Frame.Visible = false
		end
		
		local Frame = Main:FindFirstChild(Button.Name)
		
		if Frame then
			Frame.Visible = true
		end
		
		CurrentlyOpenedTab = Button
	end
end

-- Main sequence
for AssetType, Asset in pairs(ProductsModule.Assets) do
	for ProductId, Product in pairs(Asset) do
		local ProductInterface, ProductCore = Product.Interface, Product.Core
		
		-- If not an interface-based product, then it will not render
		if not ProductInterface or ProductInterface.Disabled then
			continue
		end
		
		-- Fetch the product interface type, set to main by default.. also fetch the template
		local ProductInterfaceType = ProductInterface.Type or 'Default'
		local ProductTemplate = Templates:WaitForChild(ProductInterfaceType):WaitForChild('Template'):Clone()
		
		-- Set basic product data		
		if ProductInterfaceType == 'Cash' then
			if ProductInterface.SpecialAesthetics then
				ProductTemplate.BackgroundColor3 = Configurations.SpecialTemplateColor
				ProductTemplate.Main.Amount.TextColor3 = Configurations.SpecialTemplateColor
				ProductTemplate.Main._Currency.TextColor3 = Configurations.SpecialTemplateColor
			end
			
			ProductTemplate.Name = ProductCore.Name
			ProductTemplate.Main.Amount.Text = ProductInterface.Title
			ProductTemplate.Main.Picture.Image = ProductInterface.Icon
			ProductTemplate.Main.Buy.Main.Container.Label.Text = ProductCore.Price
		else
			ProductTemplate.Name = ProductCore.Name
			ProductTemplate.Main.Description.Text = ProductInterface.Description
			ProductTemplate.Main.Picture.Image = ProductInterface.Icon
			ProductTemplate.Main.Buy.Main.Container.Label.Text = ProductCore.Price
		end
		
		ProductTemplate.LayoutOrder = ProductInterface.DisplayOrder or 1
		
		-- Set gradient if it's an offer
		if ProductInterfaceType == 'Offers' then
			local Gradient = ProductTemplate.Gradient
			Gradient.Offset = Vector2.new(-Configurations.Offers.GradientOffset, 0)

			local Tween = TweenService:Create(Gradient, OffersGradientTweenInfo, {Offset = Vector2.new(OffersFinalGradientOffset, 0)})
			Tween:Play()
		end
		
		-- Set up the buying process
		local ProductButton = ProductTemplate.Main.Buy

		ProductButton.MouseButton1Down:Connect(function()
			CommonTween(ProductButton)

			if AssetType == 'Gamepasses' then
				MarketplaceService:PromptGamePassPurchase(LocalPlayer, ProductId)
			else
				MarketplaceService:PromptProductPurchase(LocalPlayer, ProductId)
			end
		end)
		
		-- Finally, parent it
		ProductTemplate.Parent = Main:WaitForChild(ProductInterfaceType):WaitForChild('Holder')
	end
end

for _, AssetFrame in pairs(Main:GetChildren()) do
	if AssetFrame.ClassName ~= 'Frame' then
		continue
	end
	
	-- Initialize the 'type' and template
	local Type = AssetFrame.Name
	local Template = Templates:WaitForChild(Type):WaitForChild('Template')
	
	-- Wait for the repository
	local Holder = AssetFrame:WaitForChild('Holder')
		
	-- When we finish initalizing the assets, we make modifications to the categories using scrollingframes
	if Holder.ClassName == 'ScrollingFrame' then		
		local ScrollingAssetFrame = AssetFrame:WaitForChild('Holder')
		local AssetListLayout = ScrollingAssetFrame:WaitForChild('List')
		
		local OriginalTemplateSize = Template.Size
		local OriginalListPadding = AssetListLayout.Padding
		
		local TotalTemplates = 0
		
		-- Count them up
		for _, CountingTemplate in pairs(ScrollingAssetFrame:GetChildren()) do
			if CountingTemplate.ClassName == Template.ClassName then
				TotalTemplates += 1
			end
		end
				
		-- Set the new values up
		local Dividend = (TotalTemplates / (1 / (OriginalTemplateSize.X.Scale + OriginalListPadding.Scale)))
		
		if Dividend > 1 then
			ScrollingAssetFrame.CanvasSize = UDim2.fromScale(Dividend, 0)
			AssetListLayout.Padding = UDim.new(OriginalListPadding.Scale / Dividend, 0)
		
			for _, ChangingTemplate in pairs(ScrollingAssetFrame:GetChildren()) do
				if ChangingTemplate.ClassName == Template.ClassName then
					ChangingTemplate.Size = UDim2.fromScale(OriginalTemplateSize.X.Scale / Dividend, OriginalTemplateSize.Y.Scale)
				end
			end
		end
	end
	
	-- Initialize the side bar clicked event
	local AssetSide = Sidebar:WaitForChild(Type)
	local AssetSideGradient = AssetSide.Gradient
		
	-- We need to add renderStepped to mouseEnter/mouseLeave events so they fire reliably
	AssetSide.MouseEnter:Connect(function()
		RunService.RenderStepped:Wait()
		AssetSideGradient.Offset = Vector2.new(0, 0)

		local Tween = TweenService:Create(AssetSideGradient, SidebarGradientTweenInfo, {Offset = Vector2.new(OffersFinalGradientOffset, 0)})
		Tween:Play()
	end)
	
	-- We need to add renderStepped to mouseEnter/mouseLeave events so they fire reliably
	AssetSide.MouseLeave:Connect(function()
		RunService.RenderStepped:Wait()

		local Tween = TweenService:Create(AssetSideGradient, SidebarGradientTweenBackInfo, {Offset = Vector2.new(0, 0)})
		Tween:Play()
	end)
	
	AssetSide.MouseButton1Down:Connect(function()
		Switch(AssetSide)
	end)
end

-- Finally, switch over to the starting pass
Switch(Default)