local L = LibStub("AceLocale-3.0"):NewLocale("InboxMailbag", "enUS", true)

if L then
	L["BAGNAME"] = "Bag"
	L["FRAMENAME"] = "Inbox Mailbag"
	L["Group Stacks"] = true
	
	L["DELETED_1"] = "%s from %s |cffFF2020 Deleted in %s|r"
	L["RETURNED_1"] = "%s from %s |cffFF2020 Returned in %s|r"
	L["DELETED_7"]  = "%s from %s |cffFF6020 Deleted in %d |4Day:Days;|r"
	L["RETURNED_7"] = "%s from %s |cffFFA020 Returned in %d |4Day:Days;|r"
	L["DELETED"]    = "%s from %s |cff20FF20 Deleted in %d |4Day:Days;|r"
	L["RETURNED"]   = "%s from %s |cff20FF20 Returned in %d |4Day:Days;|r"

	L["TOTAL"]      = "Total messages: %d"
	L["TOTAL_MORE"] = "Total messages: %d (%d)"
	
	L["Advanced"] = true
	L["ADVANCED_MODE_DESC"] = "Enable Advanced mode. Displaying more information about your mailbox, and allowing stacks of gold to be retrieved as well."
	L["ADVANCED_MODE_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: Advanced mode|r "..(enabled and "enabled" or "disabled") end

	L["MAIL_DEFAULT"] = "Default to Mailbag"
	L["MAIL_DEFAULT_DESC"] = "Enabling this will cause the Mailbox to initially open to Inbox Mailbag instead of the normal " .. INBOX
	L["MAIL_DEFAULT_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: Mailbox will default to|r "..(enabled and "Inbox Mailbag" or INBOX) end
end