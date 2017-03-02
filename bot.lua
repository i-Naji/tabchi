redis = (loadfile "redis.lua")()
redis = redis.connect('127.0.0.1', 6379)

function dl_cb(arg, data)
end

function get_admin ()
	if redis:get('botBOT-IDadmin') then
     admin = redis:get('botBOT-IDadmin')
  else
    print("\n\27[32m  لازمه کارکرد صحیح ، فرامین و امورات مدیریتی ربات تبلیغ گر <<\n                    تعریف کاربری به عنوان مدیر است\n\27[34m                   ایدی خود را به عنوان مدیر وارد کنید\n\27[32m    شما می توانید از ربات زیر شناسه عددی خود را بدست اورید\n\27[34m        ربات:       @info_ProBot")
    print("\n\27[32m >> Tabchi Bot need a fullaccess user (ADMIN)\n\27[34m Imput Your ID as the ADMIN\n\27[32m You can get your ID of this bot\n\27[34m                 @info_ProBot")
    print("\n\27[36m                      : شناسه عددی ادمین را وارد کنید << \n >> Imput the Admin ID :\n\27[31m                 ")
    admin=io.read()
    redis:set("botBOT-IDadmin", admin)
  end
  return print("\n\27[36m     ADMIN ID |\27[32m ".. admin .." \27[36m| شناسه ادمین")
end

function get_bot (i, naji)
	function bot_info (i, naji)
		redis:del("botBOT-IDid")
		redis:set("botBOT-IDid",naji.id_)
		if naji.first_name_ then
			redis:del("botBOT-IDfname")
			redis:set("botBOT-IDfname",naji.first_name_)
		end
		if naji.last_name_ then
			redis:del("botBOT-IDlanme")
			redis:set("botBOT-IDlanme",naji.last_name_)
		else
			redis:del("botBOT-IDlname")
		end
		redis:del("botBOT-IDnum")
		redis:set("botBOT-IDnum",naji.phone_number_)
		return naji.id_
	end
	tdcli_function ({ID = "GetMe",}, bot_info, nil)
end

function writefile(filename, input)
	local file = io.open(filename, "w")
	file:write(input)
	file:flush()
	file:close()
	return true
end

function process_link(text)
	if text:match("https://telegram.me/joinchat/%S+") or text:match("https://t.me/joinchat/%S+") then
    local text = text:gsub("t.me", "telegram.me")
    local matches = {text:match("(https://telegram.me/joinchat/%S+)")}
    for i, v in pairs(matches) do
		tdcli_function({ID = "CheckChatInviteLink",invite_link_ = v},
		function (i, naji)
			if naji.is_group_ or naji.is_supergroup_channel_ then
			redis:sadd("botBOT-IDsavedlinks", i.link)
			tdcli_function ({ID = "ImportChatInviteLink",invite_link_ = i.link}, dl_cb, nil)
			end
		end,
		{link = v})
		return true
    end
	end
end
function add(id)
	local Id = tostring(id)
	if not redis:sismember("botBOT-IDall", id) then
		if Id:match("^(%d+)$") then
			redis:sadd("botBOT-IDusers", id)
			redis:sadd("botBOT-IDall", id)
		elseif Id:match("^-100") then
			redis:sadd("botBOT-IDsupergroups", id)
			redis:sadd("botBOT-IDall", id)
		else
			redis:sadd("botBOT-IDgroups", id)
			redis:sadd("botBOT-IDall", id)
		end
	end
	return true
end
function rem(id)
	local Id = tostring(id)
	if redis:sismember("botBOT-IDall", id) then
		if Id:match("^(%d+)$") then
			redis:srem("botBOT-IDusers", id)
			redis:srem("botBOT-IDall", id)
		elseif Id:match("^-100") then
			redis:srem("botBOT-IDsupergroups", id)
			redis:srem("botBOT-IDall", id)
		else
			redis:srem("botBOT-IDgroups", id)
			redis:srem("botBOT-IDall", id)
		end
	end
	return true
end
function send(chat_id, msg_id, text)
	tdcli_function ({
		ID = "SendMessage",
		chat_id_ = chat_id,
		reply_to_message_id_ = msg_id,
		disable_notification_ = 1,
		from_background_ = 1,
		reply_markup_ = nil,
		input_message_content_ = {
			ID = "InputMessageText",
			text_ = text,
			disable_web_page_preview_ = 1,
			clear_draft_ = 0,
			entities_ = {},
			parse_mode_ = {ID = "TextParseModeHTML"},
		},
	}, dl_cb, nil)
end
get_admin()
function tdcli_update_callback(data)
	if data.ID == "UpdateNewMessage" then
		local msg = data.message_
		local realm = redis:get('botBOT-IDrealm')
		local admin = redis:get('botBOT-IDadmin')
		local bot_id = redis:get("botBOT-IDid") or get_bot()
		if msg.sender_user_id_ == 777000 then
			return tdcli_function({
				ID = "ForwardMessages",
				chat_id_ = realm or admin,
				from_chat_id_ = msg.chat_id_,
				message_ids_ = {[0] = msg.id_},
				disable_notification_ = 0,
				from_background_ = 1
			}, dl_cb, nil)
		end
		if tostring(msg.chat_id_):match("^(%d+)") then
			if not redis:sismember("botBOT-IDall", msg.chat_id_) then
				redis:sadd("botBOT-IDusers", msg.chat_id_)
				redis:sadd("botBOT-IDall", msg.chat_id_)
			end
		end
		add(msg.chat_id_)
		if msg.content_.ID == "MessageText" then
			local text = msg.content_.text_
			process_link(text)
			if msg.sender_user_id_ == tonumber(admin) then
				if text:match("^حذف گروه مدیریت$") then
					redis:del('botBOT-IDrealm')
					send(msg.chat_id_, msg.id_, "<i>گروه مدیریتی حذف شد</i>")
				elseif text:match("^(تنظیم مدیر) (%d+)$") then
					local matches = {string.match(text, "^(افزودن مدیر) (%d+)$")} 	
					redis:set("botBOT-IDadmin", matches[2])
					send(msg.chat_id_, msg.id_, "<i>ادمین ربات با موفقیت تغییر کرد</i>")
				elseif text:match("^(/reload)$") then
					loadfile("./bot-BOT-ID.lua")()
					send(msg.chat_id_, msg.id_, "<i>بارگذاری مجدد انجام شد</i>")
				elseif text:match("^(ترک کردن) (.*)$") then
					local matches = {string.match(text, "^(ترک گروه) (.*)$")} 	
					send(msg.chat_id_, msg.id_, 'گروه ترک شد')
					tdcli_function ({
						ID = "ChangeChatMemberStatus",
						chat_id_ = matches[2],
						user_id_ = bot_id,
						status_ = {ID = "ChatMemberStatusLeft"},
					}, dl_cb, nil)
					rem(matches[2])
				elseif text:match("^بروزرسانی ربات$") then
					io.popen("git fetch --all && git reset --hard origin/persian && git pull origin persian"):read("*all")
					local text,ok = io.open("bot.lua",'r'):read('*a'):gsub("BOT%-ID",BOT-ID)
					io.open("bot-BOT-ID.lua",'w'):write(text):close()
					loadfile("./bot-BOT-ID.lua")()
					send(msg.chat_id_, msg.id_, "<i>تبلیغ گر با موفقیت </i><code>بروزرسانی</cdoe><i> شد</i>")
				elseif text:match("^همگام سازی با تبچی$") then
					local botid = BOT-ID - 1
					--redis:del("botBOT-IDall")
					redis:sunionstore("botBOT-IDall","tabchi:"..tostring(botid)..":all")
					--redis:del("botBOT-IDusers")
					redis:sunionstore("botBOT-IDusers","tabchi:"..tostring(botid)..":pvis")
					--redis:del("botBOT-IDgroups")
					redis:sunionstore("bot1groups","tabchi:"..tostring(botid)..":groups")
					--redis:del("bot1supergroups")
					redis:sunionstore("bot1supergroups","tabchi:"..tostring(botid)..":channels")
					--redis:del("bot1savedlinks")
					redis:sunionstore("bot1savedlinks","tabchi:"..tostring(botid)..":savedlinks")
					send(msg.chat_id_, msg.id_, "<b>همگام سازی اطلاعات با تبچی شماره</b><code> "..tostring(botid).." </code><b>انجام شد.</b>")
				end
				if tostring(msg.chat_id_):match("^-") then
					if text:match("^(افزودن گروه مدیریت)$") then
						redis:set('botBOT-IDrealm', msg.chat_id_)
						send(msg.chat_id_, msg.id_, '<i>گروه مدیریتی ثبت شد</i>')
					elseif text:match("^(ترک کردن)$") then
						tdcli_function ({
							ID = "ChangeChatMemberStatus",
							chat_id_ = msg.chat_id_,
							user_id_ = bot_id,
							status_ = {ID = "ChatMemberStatusLeft"},
						}, dl_cb, nil)
						rem(msg.chat_id_)
					end
				end
			end
			if tostring(msg.chat_id_) == realm or tostring(msg.sender_user_id_) == admin then
				if text:match("^(لیست) (.*)$") then
					local matches = {text:match("^(لیست) (.*)$")}
					if matches[2] == "مخاطبین" then
						return tdcli_function({
							ID = "SearchContacts",
							query_ = nil,
							limit_ = 999999999
						},
						function (I, Naji)
							local count = Naji.total_count_
							local text = "مخاطب های ذخیره شده : \n"
							for i = 0, tonumber(count) - 1 do
								local user = Naji.users_[i]
								local firstname = user.first_name_ or ""
								local lastname = user.last_name_ or ""
								local fullname = firstname .. " " .. lastname
								text = tostring(text) .. tostring(i) .. ". " .. tostring(fullname) .. " [" .. tostring(user.id_) .. "] = " .. tostring(user.phone_number_) .. "  \n"
							end
							writefile("botBOT-ID_contacts.txt", text)
							tdcli_function ({
								ID = "SendMessage",
								chat_id_ = I.chat_id,
								reply_to_message_id_ = 0,
								disable_notification_ = 0,
								from_background_ = 1,
								reply_markup_ = nil,
								input_message_content_ = {ID = "InputMessageDocument",
								document_ = {ID = "InputFileLocal",
								path_ = "botBOT-ID_contacts.txt"},
								caption_ = "مخاطبین تبلیغ گر شماره BOT-ID"}
							}, dl_cb, nil)
							return io.popen("rm -rf botBOT-ID_contacts.txt"):read("*all")
						end, {chat_id = msg.chat_id_})
					end
				elseif text:match("^(وضعیت مشاهده) (.*)$") then
					local matches = {text:match("^(وضعیت پیام) (.*)$")}
					if matches[2] == "روشن" then
						redis:set("botBOT-IDmarkread", true)
						send(msg.chat_id_, msg.id_, "<i>وضعیت پیام ها >> خوانده شده ✔️✔️\n</i><code>(تیک دوم فعال)</code>")
					elseif matches[2] == "خاموش" then
						redis:del("botBOT-IDmarkread")
						send(msg.chat_id_, msg.id_, "<i>وضعیت پیام ها >> خوانده نشده ✔️\n</i><code>(بدون تیک دوم)</code>")
					end 
				elseif text:match("^(افزودن با پیام) (.*)$") then
					local matches = {text:match("(افزودن با پیام) (.*)$")}
					if matches[2] == "روشن" then
						redis:set("botBOT-IDaddmsg", true)
						return send(msg.chat_id_, msg.id_, "<i>پیام افزودن مخاطب فعال شد</i>")
					elseif matches[2] == "خاموش" then
						redis:del("botBOT-IDaddmsg")
						return send(msg.chat_id_, msg.id_, "<i>پیام افزودن مخاطب غیرفعال شد</i>")
					end
				elseif text:match("^(افزودن با شماره) (.*)$") then
					local matches = {text:match("(افزودن با شماره) (.*)$")}
					if matches[2] == "روشن" then
						redis:set("botBOT-IDaddcontact", true)
						return send(msg.chat_id_, msg.id_, "<i>ارسال شماره هنگام افزودن مخاطب فعال شد</i>")
					elseif matches[2] == "خاموش" then
						redis:del("botBOT-IDaddcontact")
						return send(msg.chat_id_, msg.id_, "<i>ارسال شماره هنگام افزودن مخاطب غیرفعال شد</i>")
					end
				elseif text:match("^(تنظیم پیام افزودن مخاطب) (.*)") then
					local matches = {text:match("^(تنظیم پیام افزودن مخاطب) (.*)")}
					redis:set("botBOT-IDaddmsgtext", matches[2])
					send(msg.chat_id_, msg.id_, "<i>پیام افزودن مخاطب ثبت  شد </i>:\n🔹 "..matches[2].." 🔹")
				elseif text:match("^(امار)$") or text:match("^(آمار)$") then
					local gps = redis:scard("botBOT-IDgroups")
					local sgps = redis:scard("botBOT-IDsupergroups")
					local usrs = redis:scard("botBOT-IDusers")
					local links = redis:scard("botBOT-IDsavedlinks")
					local contacts = redis:scard("botBOT-IDaddedcontacts")
					local text = [[
<i>📈 وضعیت و آمار تبلیغ گر 📊</i>
          
<code>👤 گفت و گو های شخصی : </code>
<b>]] .. tostring(usrs) .. [[</b>
<code>👥 گروها : </code>
<b>]] .. tostring(gps) .. [[</b>
<code>🌐 سوپر گروه ها : </code>
<b>]] .. tostring(sgps) .. [[</b>
<code>📖 مخاطبین دخیره شده : </code>
<b>]] .. tostring(contacts)..[[</b>
<code>📂 لینک های ذخیره شده : </code>
<b>]] .. tostring(links)..[[</b>
 😼 سازنده : @i_naji]]
					send(msg.chat_id_, 0, text)
				elseif (text:match("^(ارسال به) (.*)$") and msg.reply_to_message_id_ ~= 0) then
					local matches = {text:match("^(ارسال به) (.*)$")}
					local naji
					if matches[2]:match("^(همه)$") then
						naji = "botBOT-IDall"
					elseif matches[2]:match("^(خصوصی)") then
						naji = "botBOT-IDusers"
					elseif matches[2]:match("^(گروه)") then
						naji = "botBOT-IDgroups"
					elseif matches[2]:match("^(سوپرگروه)") then
						naji = "botBOT-IDsupergroups"
					else
						return true
					end
					local list = redis:smembers(naji)
					local id = msg.reply_to_message_id_
					for i, v in pairs(list) do
						tdcli_function({
							ID = "ForwardMessages",
							chat_id_ = v,
							from_chat_id_ = msg.chat_id_,
							message_ids_ = {[0] = id},
							disable_notification_ = 1,
							from_background_ = 1
						}, dl_cb, nil)
					end
					send(msg.chat_id_, msg.id_, "<i>با موفقیت فرستاده شد</i>")
				elseif text:match("^(مسدودیت) (%d+)$") then
					local matches = {text:match("^(مسدود کردن) (%d+)$")}
					rem(tonumber(matches[2]))
					redis:sadd("botBOT-IDblockedusers",matches[2])
					tdcli_function ({
						ID = "BlockUser",
						user_id_ = tonumber(matches[2])
					}, dl_cb, nil)
					send(msg.chat_id_, msg.id_, "<i>کاربر مورد نظر مسدود شد</i>")
				elseif text:match("^(رفع مسدودیت) (%d+)$") then
					local matches = {text:match("^(رفع مسدودیت) (%d+)$")}
					add(tonumber(matches[2]))
					redis:srem("botBOT-IDblockedusers",matches[2])
					tdcli_function ({
						ID = "UnblockUser",
						user_id_ = tonumber(matches[2])
					}, dl_cb, nil)
					send(msg.chat_id_, msg.id_, "<i>مسدودیت کاربر مورد نظر رفع شد.</i>")	
				elseif text:match('^(تنظیم نام) "(.*)" (.*)') then
					local matches = {text:match('^(تنظیم نام) "(.*)" (.*)')}
					tdcli_function ({
						ID = "ChangeName",
						first_name_ = matches[2],
						last_name_ = matches[3]
					}, dl_cb, nil)
					send(msg.chat_id_, 0, "<i>تنظیم نام با موفقیت انجام شد</i>")
				elseif text:match("^(تنظیم نام کاربری) (.*)") then
					local matches = {text:match("^(تنظیم نام کاربری) (.*)")}
						tdcli_function ({
						ID = "ChangeUsername",
						username_ = tostring(matches[2])
						}, dl_cb, nil)
					send(msg.chat_id_, 0, '<i>تلاش برای تنظیم نام کاربری...</i>')
				elseif text:match("^(حذف نام کاربری)$") then
					tdcli_function ({
						ID = "ChangeUsername",
						username_ = ""
					}, dl_cb, nil)
					send(msg.chat_id_, 0, '<i>نام کاربری با موفقیت حذف شد.</i>')
				elseif text:match("^(ارسال کن) '(.*)' (.*)") then
					local matches = {string.match(text, "^(ارسال کن) '(.*)' (.*)")} 
					send(tostring(matches[2]), 0, matches[3])
					return send(msg.chat_id_, 0, "<i>ارسال شد</i>")
				elseif text:match("^(بگو) (.*)") then
					local matches = {string.match(text, "^(بگو) (.*)")} 
					return send(msg.chat_id_, 0, matches[2])
				elseif text:match("^(شناسه مدیر)$") then
					return send(msg.chat_id_, 0, "<code>" .. admin .."</code>")
				elseif text:match("^(شناسه من)$") then
					return send(msg.chat_id_, msg.id_, "<i>" .. msg.sender_user_id_ .."</i>")
				end
			end
		end
		elseif msg.content_.ID == "MessageContact" then
			local first = msg.content_.contact_.first_name_ or "-"
			local last = msg.content_.contact_.last_name_ or "-"
			local phone = msg.content_.contact_.phone_number_
			local id = msg.content_.contact_.user_id_
			tdcli_function ({
				ID = "ImportContacts",
				contacts_ = {[0] = {
						phone_number_ = tostring(phone),
						first_name_ = tostring(first),
						last_name_ = tostring(last),
						user_id_ = id
					},
				},
			}, dl_cb, nil)
			if not redis:sismember("botBOT-IDaddedcontacts",id) then
				redis:sadd("botBOT-IDaddedcontacts",id)
			end
			if redis:get("botBOT-IDaddmsg") then
				local answer = redis:get("botBOT-IDaddmsgtext") or "اددی گلم خصوصی پیام بده"
				send(msg.chat_id_, 0, answer)
			end
			if redis:get("botBOT-IDaddcontact") and msg.sender_user_id_ ~= bot_id then
				local fname = redis:get("botBOT-IDfname")
				local lnasme = redis:get("botBOT-IDlname") or ""
				local num = redis:get("botBOT-IDnum")
				tdcli_function ({
					ID = "SendMessage",
					chat_id_ = msg.chat_id_,
					reply_to_message_id_ = 0,
					disable_notification_ = 1,
					from_background_ = 1,
					reply_markup_ = nil,
					input_message_content_ = {
						ID = "InputMessageContact",
						contact_ = {
							ID = "Contact",
							phone_number_ = num,
							first_name_ = fname,
							last_name_ = lname,
							user_id_ = bot_id
						},
					},
				}, dl_cb, nil)
			end
		elseif msg.content_.ID == "MessageChatDeleteMember" and msg.content_.id_ == bot_id then
			return rem(msg.chat_id_)
		elseif msg.content_.ID == "MessageChatJoinByLink" and msg.sender_user_id_ == bot_id then
			return add(msg.chat_id_)
		elseif msg.content_.ID == "MessageChatAddMembers" then
			for i = 0, #msg.content_.members_ do
				if msg.content_.members_[i].id_ == bot_id then
					add(msg.chat_id_)
				end
			end
		elseif msg.content_.caption_ then
			return process_link(msg.content_.caption_)
		end
		if redis:get("botBOT-IDmarkread") then
			tdcli_function ({
				ID = "ViewMessages",
				chat_id_ = msg.chat_id_,
				message_ids_ = {[0] = msg.id_} 
			}, dl_cb, nil)
		end
	elseif data.ID == "UpdateOption" and data.name_ == "my_id" then
		tdcli_function ({
			ID = "GetChats",
			offset_order_ = 9223372036854775807,
			offset_chat_id_ = 0,
			limit_ = 20
		}, dl_cb, nil)
	end
end
