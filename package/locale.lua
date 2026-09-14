local L={}
function L.normalize(v)
 v=tostring(v or ''):lower():gsub('_','-')
 if v:match('^en') then return 'en' elseif v:match('^de') then return 'de' elseif v:match('^ja') then return 'ja' end
 return 'zh-CN'
end
L.words={
 ['zh-CN']={waiting='等待天气',sync='等待系统校时',city='上海',days={'日','一','二','三','四','五','六'}},
 en={waiting='Updating weather',sync='Waiting for time',city='New York',days={'Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday'}},
 de={waiting='Wetter wird geladen',sync='Zeit wird synchronisiert',city='New York',days={'Sonntag','Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag'}},
 ja={waiting='天気を取得中',sync='時刻を同期中',city='ニューヨーク',days={'日曜日','月曜日','火曜日','水曜日','木曜日','金曜日','土曜日'}}
}
function L.date(lang,t,w)
 local d=L.words[lang].days[w]
 if lang=='zh-CN' then return string.format('%04d年%d月%d日  星期%s',t.year,t.mon,t.day,d)
 elseif lang=='ja' then return string.format('%04d年%d月%d日  %s',t.year,t.mon,t.day,d)
 elseif lang=='de' then return string.format('%02d.%02d.%04d  %s',t.day,t.mon,t.year,d)
 else return string.format('%04d-%02d-%02d  %s',t.year,t.mon,t.day,d) end
end
return L
