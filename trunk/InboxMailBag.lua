-- Thank you to Partha
--  ... finer detail for how long items may stay in the inbox
--  ... PUSH_ITEM event based queue operation

NUM_BAGITEMS_PER_ROW = 6;
NUM_BAGITEMS_ROWS = 7;

BAGITEMS_ICON_ROW_HEIGHT = 36;
BAGITEMS_ICON_DISPLAYED = NUM_BAGITEMS_PER_ROW * NUM_BAGITEMS_ROWS;

-- Saved variable (and default value)
MAILBAGDB = {
	["GROUP_STACKS"] = true,
	["ADVANCED"] = false,
	["MAIL_DEFAULT"] = false,
	["QUALITY_COLORS"] = false
};

-- Localization globals
local L = LibStub("AceLocale-3.0"):GetLocale("InboxMailbag", true);

-- Export localization into namespace for XML localization
MB_BAGNAME = L["BAGNAME"];
MB_FRAMENAME = L["FRAMENAME"];
MB_GROUP_STACKS = L["Group Stacks"];

-- Drawing in localization info
local WEAPON = WEAPON or ENCHSLOT_WEAPON;
-- ARMOR is normally defined

local MB_Items = {};
local MB_Queue = {};
local MB_Ready = true;
local MB_SearchField = _G["BagItemSearchBox"];
local MB_Tab; -- The tab for our frame.
local MB_BattlePetTooltipLines;

local options = {
	name = L["FRAMENAME"],
	type = 'group',
	args = {
		advanced = {
			type = 'toggle',
			name = L["Advanced"],
			desc = L["ADVANCED_MODE_DESC"],
			descStyle = "inline",
			width = "full",
			set = function(info, val)
					InboxMailbag_ToggleAdvanced(val);
					if (info[0]) then
						LibStub("AceConsole-3.0"):Print(L["ADVANCED_MODE_CHANGED"](val));
					end
				 end,
			get = function(info) return MAILBAGDB["ADVANCED"] end,
		},
		quality_colors = {
			type = 'toggle',
			name = L["Quality Colors"],
			desc = L["QUALITY_COLOR_MODE_DESC"],
			descStyle = "inline",
			width = "full",
			set = function(info, val)
					MAILBAGDB["QUALITY_COLORS"] = val;
					if ( InboxMailbagFrame:IsVisible() ) then
						InboxMailbag_Update();
					end
					if (info[0]) then
						LibStub("AceConsole-3.0"):Print(L["QUALITY_COLORS_MODE_CHANGED"](val));
					end
				 end,
			get = function(info) return MAILBAGDB["QUALITY_COLORS"] end,
		},
		mail_default = {
			type = 'toggle',
			name = L["MAIL_DEFAULT"],
			desc = L["MAIL_DEFAULT_DESC"],
			descStyle = "inline",
			width = "full",
			set = function(info, val)
					MAILBAGDB["MAIL_DEFAULT"] = val;
					if (info[0]) then
						LibStub("AceConsole-3.0"):Print(L["MAIL_DEFAULT_CHANGED"](val));
					end
				 end,
			get = function(info) return MAILBAGDB["MAIL_DEFAULT"] end,
		},
	},
};
LibStub("AceConfig-3.0"):RegisterOptionsTable("InboxMailbag", options, {"mailbag"});
LibStub("AceConfigDialog-3.0"):AddToBlizOptions("InboxMailbag", L["FRAMENAME"]);

function InboxMailbagSearch_OnEditFocusGained(self, ...)
	MB_SearchField = self;
end

function InboxMailbag_OnLoad(self)
	-- We have things to do after everything is loaded
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("MAIL_SHOW");

	-- Hook our tab to play nicely with MailFrame tabs
	hooksecurefunc("MailFrameTab_OnClick", InboxMailbag_Hide); -- Adopted from Sent Mail as a more general solution, and plays well with Sent Mail

	-- Hook our search field so we know what search field to use.
	-- Hack, because we can't use UI to give us current search string/search filter
	BagItemSearchBox:HookScript("OnEditFocusGained", InboxMailbagSearch_OnEditFocusGained);
	InboxMailbagFrameItemSearchBox:HookScript("OnEditFocusGained", InboxMailbagSearch_OnEditFocusGained);
	table.insert(ITEM_SEARCHBAR_LIST, "InboxMailbagFrameItemSearchBox");
		
	--Create Mailbag item buttons, button background textures
	assert(InboxMailbagFrameItem1);
	local frameParent = InboxMailbagFrameItem1:GetParent();

	for i = 2, BAGITEMS_ICON_DISPLAYED do
		local button = CreateFrame("Button", "InboxMailbagFrameItem"..i, frameParent, "MailbagItemButtonGenericTemplate");
		button:SetID(i);
		if ((i%NUM_BAGITEMS_PER_ROW) == 1) then
			button:SetPoint("TOPLEFT", _G["InboxMailbagFrameItem"..(i-NUM_BAGITEMS_PER_ROW)], "BOTTOMLEFT", 0, -7);
		else
			button:SetPoint("TOPLEFT", _G["InboxMailbagFrameItem"..(i-1)], "TOPRIGHT", 9, 0);
		end
	end
	for i = 1, BAGITEMS_ICON_DISPLAYED do
		local texture = self:CreateTexture(nil, "BORDER", "Mailbag-Slot-BG");
		texture:SetPoint("TOPLEFT", _G["InboxMailbagFrameItem"..i], "TOPLEFT", -2, 2);
		texture:SetPoint("BOTTOMRIGHT", _G["InboxMailbagFrameItem"..i], "BOTTOMRIGHT", 2, -2);
		texture:SetAlpha(0.66);
	end

	-- From sample code at http://us.battle.net/wow/en/forum/topic/7415465636
	-- thank you Ro @ Underhill
	--local BattlePetTooltip = BattlePetTooltip; -- not really needed
	MB_BattlePetTooltipLines = BattlePetTooltip:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	MB_BattlePetTooltipLines:SetPoint("TOPLEFT", BattlePetTooltip.Owned, "BOTTOMLEFT", -3, 0);
	BattlePetTooltip:HookScript("OnHide", InboxMailbag_BattlePetToolTip_OnHide);

	-- properly align Blizzard's default BattlePetTooltip
	BattlePetTooltip.Name:ClearAllPoints();
	BattlePetTooltip.Name:SetPoint("TOPLEFT", 10, -10);
end

function InboxMailbag_OnPlayerLogin(self, event, ...)
	InboxMailbagTab_Create();
	
	-- Check for and adapt to the presence of the addon: Sent Mail
	if (SentMailTab) then
		MB_Tab:SetPoint("LEFT", SentMailTab, "RIGHT", -8, 0);
		MB_Tab:HookScript("OnClick", SentMail_UpdateTabs);
		SentMailTab:HookScript("OnClick", InboxMailbagTab_DeselectTab);
	end

	-- Check for and adapt to the presence of the addon: BeanCounter (part of Auctioneer's suite)
	if (BeanCounter) then
		BeanCounterMail:HookScript("OnShow", InboxMailbag_BeanCounter_OnShow);
		BeanCounterMail:HookScript("OnHide", InboxMailbag_BeanCounter_OnHide);
	end

	-- Last tweaks for advanced mode
	InboxMailbag_ToggleAdvanced( MAILBAGDB["ADVANCED"] );
end

function InboxMailbag_OnShow(self)
	self:RegisterEvent("MAIL_INBOX_UPDATE");
	self:RegisterEvent("ITEM_PUSH");
	self:RegisterEvent("PLAYER_MONEY");
	self:RegisterEvent("UI_ERROR_MESSAGE");
	self:RegisterEvent("INVENTORY_SEARCH_UPDATE");

	InboxMailbag_Consolidate();
end

function InboxMailbag_OnHide(self)
	self:UnregisterEvent("MAIL_INBOX_UPDATE");
	self:UnregisterEvent("ITEM_PUSH");
	self:UnregisterEvent("PLAYER_MONEY");
	self:UnregisterEvent("UI_ERROR_MESSAGE");
	self:UnregisterEvent("INVENTORY_SEARCH_UPDATE");
	
	InboxMailbag_ResetQueue();
end

function InboxMailbag_OnEvent(self, event, ...)
	if ( event == "MAIL_INBOX_UPDATE" ) then
		InboxMailbag_Consolidate();
	elseif( event == "ITEM_PUSH" or event == "PLAYER_MONEY" ) then
		if not MB_Ready then
			MB_Ready = true;
			InboxMailbag_Consolidate();
			InboxMailbag_FetchNext();
		end
	elseif( event == "INVENTORY_SEARCH_UPDATE" ) then
		InboxMailbag_UpdateSearchResults();
	elseif( event == "UI_ERROR_MESSAGE" ) then
		-- Assume it's our fault, stop the queue
		InboxMailbag_ResetQueue();
	elseif( event == "MAIL_SHOW" ) then
		if MAILBAGDB["MAIL_DEFAULT"] then
			InboxMailbagTab_OnClick(MB_Tab);
		end
	elseif( event == "PLAYER_LOGIN" ) then
		InboxMailbag_OnPlayerLogin(self, event, ...);
	end
end

-- Scan the mail. Gather it. Refresh our scroll system
function InboxMailbag_Consolidate()
	if not MB_Ready then  return;  end

	MB_Items = {};
	local indexes = {}; -- Name to MB_Items index mapping
	
	local counter = 0;
	local index = "";
	local bGroupStacks = MAILBAGDB["GROUP_STACKS"];
	local bAdvanced    = MAILBAGDB["ADVANCED"];
	
	for i=1, GetInboxNumItems() do
		local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i);
		
		if ( bAdvanced and money > 0 ) then
			local link = { ["mailID"] = i, ["money"] = money };
			if ( bGroupStacks and indexes["CASH"] ) then
				local item = MB_Items[ indexes["CASH"] ];
				item.money = item.money + money;
				table.insert(item.links, link);
				if ( daysLeft < item.daysLeft ) then
					item.daysLeft = daysLeft
				end
			else
				local item = {}
				item.money = money;
				item.hasItem = false;
				item.daysLeft = daysLeft;
				item.links = {};
				table.insert(item.links, link);

				counter = counter + 1;
				MB_Items[counter] = item;
				indexes["CASH"] = counter;
			end
		end
		
		if (itemCount and CODAmount == 0) then
			for n=1,ATTACHMENTS_MAX_RECEIVE do
				local name, itemTexture, count, quality, canUse = GetInboxItem(i, n);

				if (name) then
					local link = { ["mailID"] = i, ["attachment"] = n };
					if ( bGroupStacks and indexes[name] ) then
						local item = MB_Items[ indexes[name] ];
						item.count = item.count + count;
						table.insert(item.links, link);
						if ( daysLeft < item.daysLeft ) then
							item.daysLeft = daysLeft
						end
					else
						local item = {}
						item.count = count;
						item.hasItem = true;
						item.daysLeft = daysLeft;
						item.itemTexture = itemTexture;
						item.links = {};
						table.insert(item.links, link);

						counter = counter + 1;
						MB_Items[counter] = item;
						indexes[name] = counter;
					end
				end
			end
		end
	end

	InboxMailbag_Update()
end

function InboxMailbag_isFiltered(itemID)
	local searchString = MB_SearchField:GetText();
	if (searchString ~= SEARCH and strlen(searchString) > 0) then
		if (itemID == "CASH") then  return true;  end
		
		local name, link, _, _, _, itemType, subType, _, equipSlot, _, vendorPrice = GetItemInfo(itemID);
		local subMatch = false;
		if (itemType == ARMOR or itemType == WEAPON) then
			local secondary = _G[equipSlot] or ""
			subMatch = strfind(strlower(secondary), searchString) or strfind(strlower(subType), searchString);
		end
		searchString = strlower(searchString);
		return (not subMatch and not strfind(strlower(name), searchString));
	else
		return false;
	end
end

function InboxMailbag_UpdateSearchResults()
	for i=1, BAGITEMS_ICON_DISPLAYED do
		local itemButton = _G["InboxMailbagFrameItem"..i];
		local itemLink = itemButton.item and (itemButton.item.hasItem and GetInboxItemLink(itemButton.item.links[1].mailID, itemButton.item.links[1].attachment) or "CASH");
		if ( itemLink and InboxMailbag_isFiltered(itemLink) ) then
			itemButton.searchOverlay:Show();
		else
			itemButton.searchOverlay:Hide();
		end
	end
end

-- Interact with Faux Scrollbar to 'scroll' the inventory icons.
function InboxMailbag_Update()
	local offset = FauxScrollFrame_GetOffset(InboxMailbagFrameScrollFrame);
	offset = offset * NUM_BAGITEMS_PER_ROW;
	
	local numItems, totalItems = GetInboxNumItems();
	if ( totalItems > numItems ) then
		InboxMailbagFrameTotalMessages:SetText( format(L["TOTAL_MORE"], numItems, totalItems) );
	else
		InboxMailbagFrameTotalMessages:SetText( format(L["TOTAL"], numItems) );
	end
	
	local bQualityColors = MAILBAGDB["QUALITY_COLORS"];
	local itemName, itemTexture, count, quality, canUse, _, itemLink;
	for i=1, BAGITEMS_ICON_DISPLAYED do
		local currentIndex = i + offset;
		local item = MB_Items[currentIndex];
		local itemButton = _G["InboxMailbagFrameItem"..i];
		if (item) then
			assert(currentIndex <= #MB_Items);
			if ( item.hasItem ) then
				itemName, itemTexture, count, quality, canUse = GetInboxItem(item.links[1].mailID, item.links[1].attachment);
				itemLink = GetInboxItemLink(item.links[1].mailID, item.links[1].attachment);
				if (bQualityColors) then 
					-- GetInboxItem always returns -1 for quality. Yank from linkstring
					-- GetInboxItemLink may fail if called quickly after starting Warcraft.
					if (itemLink) then 
						_, _, quality = GetItemInfo(itemLink);
					else
						quality = nil;
					end
				end
				
				SetItemButtonTexture(itemButton, itemTexture);
				SetItemButtonCount(itemButton, item.count);
			else
				SetItemButtonTexture(itemButton, GetCoinIcon(item.money));
				SetItemButtonCount(itemButton, 0);
				quality = nil;
				itemLink = "CASH";
			end
			
			itemButton.item = item;
			
			if ( item.daysLeft < 7 ) then
				if ( item.daysLeft < 1 ) then
					itemButton.deleteOverlay:SetTexture(1, 0.125, 0.125);
				else
					itemButton.deleteOverlay:SetTexture(1, 0.5, 0);
				end
				itemButton.deleteOverlay:Show();
			else
				itemButton.deleteOverlay:Hide();
			end
			
			if( bQualityColors and quality and quality ~= 1 ) then
				itemButton.qualityOverlay:SetVertexColor(ITEM_QUALITY_COLORS[quality].r, ITEM_QUALITY_COLORS[quality].g, ITEM_QUALITY_COLORS[quality].b);
				itemButton.qualityOverlay:Show();
			else
				itemButton.qualityOverlay:Hide();
			end
			
			if ( InboxMailbag_isFiltered(itemLink) ) then
				itemButton.searchOverlay:Show();
			else
				itemButton.searchOverlay:Hide();
			end
		else
			SetItemButtonTexture(itemButton, nil);
			SetItemButtonCount(itemButton, 0);
			itemButton.searchOverlay:Hide();
			itemButton.deleteOverlay:Hide();
			itemButton.qualityOverlay:Hide();
			itemButton.item = nil;
		end

		if ( itemButton:IsMouseOver() ) then  InboxMailbagItem_OnEnter(itemButton);  end
	end

	-- Scrollbar stuff
	if (#MB_Items > BAGITEMS_ICON_DISPLAYED) then
		InboxMailbagFrameScrollFrame:Show();
	else
		InboxMailbagFrameScrollFrame:Hide();
	end
	FauxScrollFrame_Update(InboxMailbagFrameScrollFrame, ceil(#MB_Items / NUM_BAGITEMS_PER_ROW) , NUM_BAGITEMS_ROWS, BAGITEMS_ICON_ROW_HEIGHT );
end

function InboxMailbag_Hide()
	InboxMailbagFrame:Hide();
end

function InboxMailbag_ResetQueue()
	MB_Queue = {};
	MB_Ready = true;
end

function InboxMailbag_FetchNext()
	if #MB_Queue > 0 and MB_Ready then
		MB_Ready = false;

		local link = table.remove(MB_Queue);

		-- Fake get mail body. This marks the messages we alter as read
		GetInboxText(link.mailID); --  > MAIL_INBOX_UPDATE

		if ( link.attachment ) then
			TakeInboxItem(link.mailID, link.attachment); --  > MAIL_SUCCESS > ITEM_PUSH
		else
			assert(link.money);
			TakeInboxMoney(link.mailID);
		end
	end
end


local battletip = {};

function battletip:ClearLines()
	self.text = nil;
	MB_BattlePetTooltipLines:SetText(nil);
end

function battletip:AddLine(text, r, g, b)
	if (self.text) then
		if (r and g and b) then
			self.text = format("%s|n|cff%2x%2x%2x%s|r", self.text, r * 255, g * 255, b * 255, text);
		else
			self.text = format("%s|n%s", self.text, text);
		end
	else
		if (r and g and b) then
			self.text = format("|cff%2x%2x%2x%s|r", r * 255, g * 255, b * 255, text);
		else
			self.text = text;
		end
	end

	MB_BattlePetTooltipLines:SetText(self.text);
end

function battletip:Show()
	BattlePetTooltip:SetHeight( BattlePetTooltip:GetHeight() + MB_BattlePetTooltipLines:GetHeight() + 2 );
	BattlePetTooltip:SetWidth( max( 260, MB_BattlePetTooltipLines:GetWidth() + 15 ) );
end


function InboxMailbagItem_OnEnter(self, index)
	local item = self.item;
	local links = item and item.links;

	GameTooltip:SetOwner(self, "ANCHOR_RIGHT");

	if ( links ) then
		local tip = GameTooltip;

		if ( item.hasItem ) then
			local hasCooldown, speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetInboxItem( links[1].mailID, links[1].attachment );

			if ( speciesID and speciesID > 0 ) then
				BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name);
				tip = battletip;
				tip:ClearLines();
			else
				BattlePetTooltip:Hide();
			end
		elseif ( MAILBAGDB["GROUP_STACKS"] ) then
			GameTooltip:AddLine( ENCLOSED_MONEY );
			GameTooltip:AddLine( GetCoinTextureString(item.money), 1, 1, 1 );
		else
			local invoiceType, itemName, playerName, bid, buyout, deposit, consignment = GetInboxInvoiceInfo( links[1].mailID );

			if ( invoiceType == "seller" ) then
				GameTooltip:AddLine( format( "%s  |cffFFFFFF%s|r", ITEM_SOLD_COLON, itemName ) );
				GameTooltip:AddLine( format( "%s  |cffFFFFFF%s|r", PURCHASED_BY_COLON, playerName ) );
				GameTooltip:AddLine( format( "%s:   |cffFFFFFF%s|r", bid == buyout and BUYOUT or HIGH_BIDDER, GetCoinTextureString(bid) ) );
			else
				local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo( links[1].mailID );
				GameTooltip:AddLine( subject );
				GameTooltip:AddLine( GetCoinTextureString(item.money), 1, 1, 1 );
			end
		end

		local addSeparator = true;

		for i, link in ipairs(links) do
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(link.mailID);

			if daysLeft and daysLeft > 0 then
				local strAmount;

				if ( item.hasItem ) then
					local name, itemTexture, count, quality, canUse = GetInboxItem(link.mailID, link.attachment);
					strAmount = ( count and count > 0 ) and tostring(count);
				else
					strAmount = ( link.money and link.money > 0 ) and format( "|cffFFFFFF%s|r ", GetCoinTextureString(link.money) );
				end

				-- Format expiration time
				if strAmount then
					if addSeparator then  tip:AddLine(" ");  addSeparator = false;  end

					local canDelete = InboxItemCanDelete(link.mailID);

					if daysLeft < 1 then
						tip:AddLine( format( (canDelete and L["DELETED_1"]) or L["RETURNED_1"], strAmount, sender or UNKNOWN, SecondsToTime( floor(daysLeft * 24 * 60 * 60) ) ) );
					elseif daysLeft < 7 then
						tip:AddLine( format( (canDelete and L["DELETED_7"]) or L["RETURNED_7"], strAmount, sender or UNKNOWN, floor(daysLeft) ) );
					else
						tip:AddLine( format( (canDelete and L["DELETED"]) or L["RETURNED"], strAmount, sender or UNKNOWN, floor(daysLeft) ) );
					end
				end
			end
		end

		tip:Show();
	else
		GameTooltip:Hide();
		BattlePetTooltip:Hide();
	end
end

function InboxMailbagItem_OnClick(self)
	local links = #MB_Queue == 0 and MB_Ready and self.item and self.item.links;

	if links then
		if IsModifiedClick() then
			if ( self.item.hasItem and HandleModifiedItemClick( GetInboxItemLink(links[1].mailID, links[1].attachment) ) ) then
				return;
			else
				table.insert( MB_Queue, links[#links] )
			end
		else
			for i = 1, #links do
				table.insert( MB_Queue, links[i] )
			end
		end

		InboxMailbag_FetchNext();
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
end

-- Create our tab as +1 tab on the mailbox window. As long as other code builds the tabs
-- appropriately, then we can dynamically put our tab after them all.
function InboxMailbagTab_Create()
	local index = MailFrame.numTabs + 1;
	
	MB_Tab = CreateFrame("Button", "MailFrameTab"..index, _G["MailFrame"], "MailFrameTabInboxMailbagTemplate", index);
	MB_Tab:SetPoint("LEFT", _G["MailFrameTab"..MailFrame.numTabs], "RIGHT", -8, 0);
	
	PanelTemplates_SetNumTabs(MailFrame, index);
	PanelTemplates_SetTab(MailFrame, 1);
end

function InboxMailbagTab_OnClick(self)
	-- Adapted from MailFrameTab_OnClick
	PanelTemplates_SetTab(MailFrame, self:GetID());
	ButtonFrameTemplate_HideButtonBar(MailFrame)
	MailFrameInset:SetPoint("TOPLEFT", 4, -58);
	InboxFrame:Hide();
	SendMailFrame:Hide();
	SetSendMailShowing(false);

	InboxMailbagFrame:Show()

	PlaySound("igSpellBookOpen");
end

function InboxMailbagTab_DeselectTab()
	PanelTemplates_DeselectTab(MB_Tab);
	InboxMailbagFrame:Hide();
end

function InboxMailbag_ToggleAdvanced(...)
	if ( select("#", ...) >= 1 ) then
		MAILBAGDB["ADVANCED"] = select(1, ...);
	else
		MAILBAGDB["ADVANCED"] = not MAILBAGDB["ADVANCED"];
	end
	
	if ( MAILBAGDB["ADVANCED"] ) then
		InboxMailbagFrameTotalMessages:Show();
	else
		InboxMailbagFrameTotalMessages:Hide();
	end
	
	if ( InboxMailbagFrame:IsVisible() ) then
		InboxMailbag_Consolidate();
	end
end

-- Respond to BeanCounter showing it's MailGUI by hiding ours,
-- hiding our tab (since BC hides the SendMail tab itself)
-- and then selecting the Inbox tab so people can't click on it while BC is running
function InboxMailbag_BeanCounter_OnShow()
	InboxMailbagFrame:Hide();
	PanelTemplates_SetTab(MailFrame, 1);
	MB_Tab:Hide();
end

-- Respond to BeanCounter hiding its GUI by showing ours if appropriate
function InboxMailbag_BeanCounter_OnHide()
	MB_Tab:Show();
	if MAILBAGDB["MAIL_DEFAULT"] then
		InboxMailbagTab_OnClick(MB_Tab);
	end
end

function InboxMailbag_BattlePetToolTip_OnHide()
	MB_BattlePetTooltipLines:SetText(nil);
end