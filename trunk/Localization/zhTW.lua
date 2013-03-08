local L = LibStub("AceLocale-3.0"):NewLocale("InboxMailbag", "zhTW", false)

if L then
	L["BAGNAME"] = "郵包";
	L["FRAMENAME"] = "信箱郵件包裹";
	L["Group Stacks"] = "群組堆疊";

	L["DELETED_1"]  = "%s 從 %s |cffFF2020 將刪除於 %s 後|r";
	L["RETURNED_1"] = "%s 從 %s |cffFF2020 將返回於 %s 後|r";
	L["DELETED_7"]  = "%s 從 %s |cffFF6020 將刪除於 %d |4日:日; 後|r";
	L["RETURNED_7"] = "%s 從 %s |cffFFA020 將返回於 %d |4日:日; 後|r";
	L["DELETED"]    = "%s 從 %s |cff20FF20 將刪除於 %d |4日:日; 後|r";
	L["RETURNED"]   = "%s 從 %s |cff20FF20 將返回於 %d |4日:日; 後|r";

	L["TOTAL"]      = "總計訊息: %d";
	L["TOTAL_MORE"] = "總計訊息: %d (%d)";
	
	L["Advanced"] = "進階"
	L["ADVANCED_MODE_DESC"] = "啟用進階模式。顯示您信箱更多的訊息，並且能很好的挽回大筆的金錢。"
	L["ADVANCED_MODE_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: 進階模式|r "..(enabled and "啟用" or "關閉") end
	
	L["Quality Colors"] = "品質著色"
	L["QUALITY_COLOR_MODE_DESC"] = "啟用可由物品的邊框顯示物品的品質"
	L["QUALITY_COLORS_MODE_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: 品質著色|r "..(enabled and "啟用" or "關閉") end

	L["MAIL_DEFAULT"] = "預設為郵包"
	L["MAIL_DEFAULT_DESC"] = "啟用此選項會導致信箱最初打開的是郵包，而非一般" .. INBOX
	L["MAIL_DEFAULT_CHANGED"] = function(enabled) return "|cff00ff96InboxMailbag: 信箱預設為|r "..(enabled and "信箱郵包" or INBOX) end
end
