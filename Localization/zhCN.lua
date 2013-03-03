local L = LibStub("AceLocale-3.0"):NewLocale("InboxMailbag", "zhCN", false)

if L then
	L["BAGNAME"] = "邮包";
	L["FRAMENAME"] = "信箱邮件包裹";
	L["Group Stacks"] = "群组堆叠";

	L["DELETED_1"]  = "%s 从 %s |cffFF2020 将删除于 %s 后|r";
	L["RETURNED_1"] = "%s 从 %s |cffFF2020 将返回于 %s 后|r";
	L["DELETED_7"]  = "%s 从 %s |cffFF6020 将删除在 %d |4日:日;|r";
	L["RETURNED_7"] = "%s 从 %s |cffFFA020 将返回在 %d |4日:日;|r";
	L["DELETED"]    = "%s 从 %s |cff20FF20 将删除在 %d |4日:日;|r";
	L["RETURNED"]   = "%s 从 %s |cff20FF20 将返回在 %d |4日:日;|r";

	L["TOTAL"]      = "总计讯息: %d";
	L["TOTAL_MORE"] = "总计讯息: %d (%d)";
	
	L["Advanced"] = "进阶"
	L["ADVANCED_MODE_DESC"] = "启用进阶模式。显示您信箱更多的讯息，并且能很好的挽回大笔的金钱。"
	L["ADVANCED_MODE_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: 进阶模式|r "..(enabled and "启用" or "关闭") end
	
	L["Quality Colors"] = true
	L["QUALITY_COLOR_MODE_DESC"] = "Enable the display of item quality via the item's border."
	L["QUALITY_COLORS_MODE_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: Quality Colors|r "..(enabled and "enabled" or "disabled") end

	L["MAIL_DEFAULT"] = "预设为邮包"
	L["MAIL_DEFAULT_DESC"] = "启用此选项会导致信箱最初打开的是邮包，而非一般 " .. INBOX
	L["MAIL_DEFAULT_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: 信箱预设为|r "..(enabled and "信箱邮包" or INBOX) end
end
