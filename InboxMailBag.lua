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
	["ADVANCED"] = false
};

-- Localization globals
MB_BAGNAME = "Bag";
MB_FRAMENAME = "Inbox Mailbag";
MB_GROUP_STACKS = "Group Stacks";

MB_DELETED_1  = "%s from %s |cffFF2020 Deleted in %s|r";
MB_RETURNED_1 = "%s from %s |cffFF2020 Returned in %s|r";
MB_DELETED_7  = "%s from %s |cffFF6020 Deleted in %d |4Day:Days;|r";
MB_RETURNED_7 = "%s from %s |cffFFA020 Returned in %d |4Day:Days;|r";
MB_DELETED    = "%s from %s |cff20FF20 Deleted in %d |4Day:Days;|r";
MB_RETURNED   = "%s from %s |cff20FF20 Returned in %d |4Day:Days;|r";

MB_TOTAL      = "Total messages: %d";
MB_TOTAL_MORE = "Total messages: %d (%d)";

SLASH_MAILBAG1 = "/mailbag"

local MB_Items = {};
local MB_Queue = {};
local MB_Ready = true;
local MB_SearchField = _G["BagItemSearchBox"];
local MB_Tab; -- The tab for our frame. 

-- Drawing in localization info
local WEAPON = WEAPON or ENCHSLOT_WEAPON;
-- ARMOR is normally defined

function InboxMailbagSearch_OnEditFocusGained(self, ...)
	MB_SearchField = self;
end

function InboxMailbag_OnLoad(self)
	-- We have things to do after everything is loaded
	self:RegisterEvent("PLAYER_LOGIN");

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
end

function InboxMailbag_OnPlayerLogin(self, event, ...)
	InboxMailbagTab_Create();
	
	-- Check for and adapt to the presence of the addon: Sent Mail
	if (SentMailTab) then
		MB_Tab:SetPoint("LEFT", SentMailTab, "RIGHT", -8, 0);
		MB_Tab:HookScript("OnClick", SentMail_UpdateTabs);
		SentMailTab:HookScript("OnClick", InboxMailbagTab_DeselectTab);
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
		MB_Ready = true;
		InboxMailbag_Consolidate();
		InboxMailbag_FetchNext();
	elseif( event == "INVENTORY_SEARCH_UPDATE" ) then
		InboxMailbag_UpdateSearchResults();
	elseif( event == "UI_ERROR_MESSAGE" ) then
		-- Assume it's our fault, stop the queue
		InboxMailbag_ResetQueue();
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
	if (searchString ~= SEARCH and strlen(searchString)) then
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
		if(itemButton.item and InboxMailbag_isFiltered(GetInboxItemLink(itemButton.item.links[1].mailID, itemButton.item.links[1].attachment))) then
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
		InboxMailbagFrameTotalMessages:SetText( format(MB_TOTAL_MORE, numItems, totalItems) );
	else
		InboxMailbagFrameTotalMessages:SetText( format(MB_TOTAL, numItems) );
	end
	
	for i=1, BAGITEMS_ICON_DISPLAYED do
		local currentIndex = i + offset;
		local item = MB_Items[currentIndex];
		local itemButton = _G["InboxMailbagFrameItem"..i];
		if (item) then
			assert(currentIndex <= #MB_Items);
			if ( item.hasItem ) then
				local itemName, itemTexture, count, quality, canUse = GetInboxItem(item.links[1].mailID, item.links[1].attachment);
			
				SetItemButtonTexture(itemButton, itemTexture);
				SetItemButtonCount(itemButton, item.count);
			else
				SetItemButtonTexture(itemButton, GetCoinIcon(item.money));
				SetItemButtonCount(itemButton, 0);
			end
			
			itemButton.item = item;
			
			if ( item.daysLeft < 7 ) then
				if ( item.daysLeft < 1 ) then
					itemButton.deleteOverlay:SetTexture(1, 0.125, 0.125, 0.33);
				else
					itemButton.deleteOverlay:SetTexture(1, 0.627, 0.125, 0.33);
				end
				itemButton.deleteOverlay:Show();
			else
				itemButton.deleteOverlay:Hide();
			end
			
			-- GetInboxItemLink may fail if called quickly after starting Warcraft.
			-- Fallback to not filtering the item if we can't get a link for it right away.
			local itemLink = item.hasItem and GetInboxItemLink(item.links[1].mailID, item.links[1].attachment);
			if ( itemLink and InboxMailbag_isFiltered(itemLink) ) then
				itemButton.searchOverlay:Show();
			else
				itemButton.searchOverlay:Hide();
			end
		else
			SetItemButtonTexture(itemButton, nil);
			SetItemButtonCount(itemButton, 0);
			itemButton.searchOverlay:Hide();
			itemButton.deleteOverlay:Hide();
			itemButton.item = nil;
		end
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

function InboxMailbagItem_OnEnter(self, index)
	if ( self.item ) then		
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		if ( self.item.hasItem ) then
			local hasCooldown, speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetInboxItem(self.item.links[1].mailID, self.item.links[1].attachment);
			if(speciesID and speciesID > 0) then
				BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name);
			end
		else
			if ( MAILBAGDB["GROUP_STACKS"] ) then
				GameTooltip:AddLine(ENCLOSED_MONEY, "", 1, 1, 1);
			else
				local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(self.item.links[1].mailID);
				GameTooltip:AddLine(subject, "", 1, 1, 1);
			end
			SetTooltipMoney(GameTooltip, self.item.money);
		end

		for i, link in ipairs(self.item.links) do
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(link.mailID);
			local strAmount;
			if ( self.item.hasItem) then
				local name, itemTexture, count, quality, canUse = GetInboxItem(link.mailID, link.attachment);
				strAmount =  ( count and count > 0 ) and tostring(count);
			else
				strAmount = (link.money and link.money > 0) and GetCoinTextureString( link.money );
			end
			
			-- Format expiration time
			if strAmount and sender and daysLeft then
				local canDelete = InboxItemCanDelete(link.mailID);

				if daysLeft < 1 then
					if canDelete then
						GameTooltip:AddLine( format(MB_DELETED_1, strAmount, sender, SecondsToTime( floor(daysLeft * 24 * 60 * 60) ) ) );
					else
						GameTooltip:AddLine( format(MB_RETURNED_1, strAmount, sender, SecondsToTime( floor(daysLeft * 24 * 60 * 60) ) ) );
					end
				elseif daysLeft < 7 then
					if canDelete then
						GameTooltip:AddLine( format(MB_DELETED_7, strAmount, sender, floor(daysLeft) ) );
					else
						GameTooltip:AddLine( format(MB_RETURNED_7, strAmount, sender, floor(daysLeft) ) );
					end
				else
					if canDelete then
						GameTooltip:AddLine( format(MB_DELETED, strAmount, sender, floor(daysLeft) ) );
					else
						GameTooltip:AddLine( format(MB_RETURNED, strAmount, sender, floor(daysLeft) ) );
					end
				end
			end
		end

		GameTooltip:Show();
	end
end

function InboxMailbagItem_OnClick(self, index)
	local links = #MB_Queue == 0 and MB_Ready and self.item and self.item.links;

	if links then
		for i = 1, #links do
			table.insert( MB_Queue, links[i] )
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

function SlashCmdList.MAILBAG(msg, editbox)
	local command, rest = msg:match("^(%S*)%s*(.-)$");
	if ( command == "advanced" ) then
		InboxMailbag_ToggleAdvanced();
	else
		print ("Mailbag: Command "..command.."not understood");
	end
end