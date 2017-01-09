require "settings" -- берем инструмент, код клиента и спрэд оттуда

local CLOSE_TIME = {hour=15, min=20} -- время закрытия
local QUANTITY = 1; -- количество для закрытия
local OPERATION = "B"; -- "B" -- купить, "S" -- продать

local trade_date = {}


-- вызывается квиком при запуске робота
function OnInit()

	-- проверка текущей даты
	trade_date = os.date("*t", os.time())
    -- инициализируем data source
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M1)
    -- подпишемся на обновление цены INSTRUMENT (SiZ6)
    DS:SetUpdateCallback(NewPrice)
    PrintDbgStr("Cкрипт закрытия запущен!".. trade_date.day .." ".. OPERATION .. " " .. tostring(QUANTITY) .. " в " .. CLOSE_TIME.hour .. ":" .. CLOSE_TIME.min)
end



function doClose(curPrice)
    PrintDbgStr("Закрываемся!")

    local price; -- цена заявки
    if OPERATION == "B" then
        price = curPrice + BUFFER -- цена заявки на покупку
    else
        price = curPrice - BUFFER -- цена заявки на продажу
    end
    -- заявка
    local order = {
        ["TRANS_ID"]    = "1",
        ["ACTION"]      = "NEW_ORDER",
        ["CLASSCODE"]   = "SPBFUT",
        ["CLIENT_CODE"] = CLIENT_CODE,
        ["SECCODE"]     = INSTRUMENT,
        ["ACCOUNT"]     = ACCOUNT,
        ["OPERATION"]   = OPERATION,
        ["QUANTITY"]    = string.format('%.0f', QUANTITY),
        ["PRICE"]       = string.format('%.0f', price)
    }
    sendTransaction(order)

end

function NewPrice(i)  -- функция вызывается при каждом обновлении цены
    local curPrice = DS:C(i)
    local dt = DS:T(i)
    if Run and dt.day == trade_date.day and (dt.hour > CLOSE_TIME.hour or (dt.hour == CLOSE_TIME.hour and dt.min >= CLOSE_TIME.min)) then
        Run = false -- завершение работы!!!
        PrintDbgStr("Время закрытия наступило!")
        doClose(curPrice)
    end
end


Run = true

-- основная функция (нужна чтобы робот работал)
function main()
    while Run do
        sleep(1000)
    end
end

function OnStop()
    Run = false
end