NUM_BAGITEMS_PER_ROW = 6;
NUM_BAGITEMS_ROWS = 7;

BAGITEMS_ICON_ROW_HEIGHT = 36;
BAGITEMS_ICON_DISPLAYED = NUM_BAGITEMS_PER_ROW * NUM_BAGITEMS_ROWS;

-- Saved variable (and default value)
MAILBAGDB = {
	["GROUP_STACKS"] = true
};

-- Localization globals
MB_BAGNAME = "Bag";
MB_FRAMENAME = "Inbox Mailbag";
MB_GROUP_STACKS = "Group Stacks";

local MB_Items = {};
local MB_Queue = {};
local MB_Time = 0.50;
local MB_SearchField = _G["BagItemSearchBox"];

-- Drawing in localization info
if (not WEAPON) then
	WEAPON = ENCHSLOT_WEAPON;
end
-- ARMOR is normally defined

function InboxMailbagSearch_OnEditFocusGained(self, ...)
	MB_SearchField = self;
end

function InboxMailbag_OnLoad(self)
	-- Hook our tab to play nicely with MailFrame tabs
	MailFrameTab1:HookScript("OnClick", InboxMailbag_Hide);
	MailFrameTab2:HookScript("OnClick", InboxMailbag_Hide);
	MailFrame:HookScript("OnHide", InboxMailbag_Hide);
	
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

function InboxMailbag_OnShow(self)
	self:RegisterEvent("MAIL_INBOX_UPDATE");
	self:RegisterEvent("UI_ERROR_MESSAGE");
	self:RegisterEvent("INVENTORY_SEARCH_UPDATE");

	InboxMailbag_Consolidate()
end

function InboxMailbag_OnHide(self)
	self:UnregisterEvent("MAIL_INBOX_UPDATE");
	self:UnregisterEvent("UI_ERROR_MESSAGE");
	self:UnregisterEvent("INVENTORY_SEARCH_UPDATE");
end

function InboxMailbag_OnEvent(self, event, ...)
	if ( event == "MAIL_INBOX_UPDATE" ) then
		InboxMailbag_Consolidate();
	elseif( event == "INVENTORY_SEARCH_UPDATE" ) then
		InboxMailbag_UpdateSearchResults();
	elseif( event == "UI_ERROR_MESSAGE" ) then
		-- Assume it's our fault, stop the queue
		MB_Queue = {}
	end
end

-- Scan the mail. Gather it. Refresh our scroll system
function InboxMailbag_Consolidate()
--	if(#MB_Queue > 0) then return end
	MB_Items = {};
	local indexes = {}; -- Name to MB_Items index mapping
	
	local counter = 0;
	local index = "";
	local bGroupStacks = MAILBAGDB["GROUP_STACKS"];
	
	for i=1, GetInboxNumItems() do
		local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(i);
		
		if (itemCount and CODAmount == 0) then
			for n=1,ATTACHMENTS_MAX_RECEIVE do
				local name, itemTexture, count, quality, canUse = GetInboxItem(i, n);

				if (name) then
					local link = { ["mailID"] = i, ["attachment"] = n };
					if ( bGroupStacks and indexes[name] ) then
						local item = MB_Items[ indexes[name] ];
						item.count = item.count + count;
						table.insert(item.links, link);
					else
						local item = {}
						item.count = count;
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
		local name, link, _, _, _, itemType, subType, _, _, _, vendorPrice = GetItemInfo(itemID);
		searchString = strlower(searchString);
		return (not strfind(strlower(name), searchString) and not ((itemType == ARMOR or itemType == WEAPON) and strfind(strlower(subType), searchString)));
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
-- Yeah, yeah, I know we never committed to setting up the scrollbar yet.
function InboxMailbag_Update()
	local offset = FauxScrollFrame_GetOffset(InboxMailbagFrameScrollFrame);
	offset = offset * NUM_BAGITEMS_PER_ROW;
	
	for i=1, BAGITEMS_ICON_DISPLAYED do
		local currentIndex = i + offset;
		local item = MB_Items[currentIndex];
		local itemButton = _G["InboxMailbagFrameItem"..i];
		if (item) then
			assert(currentIndex <= #MB_Items);
			local itemName, itemTexture, count, quality, canUse = GetInboxItem(item.links[1].mailID, item.links[1].attachment);
			
			SetItemButtonTexture(itemButton, itemTexture);
			SetItemButtonCount(itemButton, item.count);
			
			itemButton.item = item;
			-- GetInboxItemLink may fail if called quickly after starting Warcraft.
			-- Fallback to not filtering the item if we can't get a link for it right away.
			local itemLink = GetInboxItemLink(item.links[1].mailID, item.links[1].attachment);
			if ( itemLink and InboxMailbag_isFiltered(itemLink) ) then
				itemButton.searchOverlay:Show();
			else
				itemButton.searchOverlay:Hide();
			end
		else
			SetItemButtonTexture(itemButton, nil);
			SetItemButtonCount(itemButton, 0);
			itemButton.searchOverlay:Hide();
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

function InboxMailbag_OnUpdate(self, elapsed)
	if ( #MB_Queue > 0 ) then
		MB_Time = MB_Time - elapsed;
		if(MB_Time < 0) then
			local link = table.remove(MB_Queue);
			
			-- Fake get mail body. This marks the messages we alter as read
			GetInboxText(link.mailID);

			TakeInboxItem(link.mailID, link.attachment);
			MB_Time = 0.50;
		end
	end
end

function InboxMailbagItem_OnEnter(self, index)
	if ( self.item ) then		
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		local hasCooldown, speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetInboxItem(self.item.links[1].mailID, self.item.links[1].attachment);
		if(speciesID and speciesID > 0) then
			BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name);
		end

		for i, link in ipairs(self.item.links) do
			local packageIcon, stationeryIcon, sender, subject, money, CODAmount, daysLeft, itemCount, wasRead, wasReturned, textCreated, canReply, isGM = GetInboxHeaderInfo(link.mailID);
			local name, itemTexture, count, quality, canUse = GetInboxItem(link.mailID, link.attachment);
			
			-- Format expiration time
			if ( daysLeft >= 1 ) then
				daysLeft = GREEN_FONT_COLOR_CODE..format(DAYS_ABBR, floor(daysLeft)).." "..FONT_COLOR_CODE_CLOSE;
			else
				daysLeft = RED_FONT_COLOR_CODE..SecondsToTime(floor(daysLeft * 24 * 60 * 60))..FONT_COLOR_CODE_CLOSE;
			end

			GameTooltip:AddLine(count.." from " ..sender.." "..daysLeft)
		end
		GameTooltip:Show();
	end
end

function InboxMailbagItem_OnClick(self, index)
	if ( self.item ) then
		if( #self.item.links == 1 ) then
			TakeInboxItem(self.item.links[1].mailID, self.item.links[1].attachment);
		else
			-- Actually needs to queue up items at this point.
			if (#MB_Queue == 0) then
				-- Queue is empty, load it up.
				for i=1, #self.item.links do
					table.insert(MB_Queue, self.item.links[i])
				end
			end
		end
		
		PlaySound("igMainMenuOptionCheckBoxOn");
	end
end