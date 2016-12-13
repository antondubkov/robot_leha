local INSTRUMENT = "SiZ6"
local ACCOUNT = "SPBFUT00LLD"
local CLIENT_CODE = "SPBFUT00LLD" -- код клиента

local CLOSE_TIME = {hour=15, min=20} -- врем¤ закрыти¤
local QUANTITY = 1; -- количество дл¤ закрыти¤
local OPERATION = "B"; -- "B" -- купить, "S" -- продать

local BUFFER = 100 -- спред/проскальзывание


-- вызываетс¤ квиком при запуске робота
function OnInit()
    -- инициализируем data source
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M5)
    -- подпишемс¤ на обновление цены INSTRUMENT (SiZ6)
    DS:SetUpdateCallback(NewPrice)
    PrintDbgStr("—крипт закрыти¤ запущен! ".. OPERATION .. " " .. tostring(QUANTITY) .. " в " .. CLOSE_TIME.hour .. ":" .. CLOSE_TIME.min)
end



function doClose(curPrice)
    PrintDbgStr("«акрываемс¤!")

    local price; -- цена за¤вки
    if OPERATION == "B" then
        price = curPrice + BUFFER -- цена за¤вки на покупку
    else
        price = curPrice - BUFFER -- цена за¤вки на продажу
    end
    -- за¤вка
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

function NewPrice(i)  -- функци¤ вызываетс¤ при каждом обновлении цены
    local curPrice = DS:C(i)
    local dt = DS:T(i)
    if dt.hour >= CLOSE_TIME.hour and dt.min >= CLOSE_TIME.min then
        PrintDbgStr("¬–≈ћя «ј –џ“»я ѕ–»ЎЋќ!")
        doClose(curPrice)
        Run = false -- завершение работы!!!
    end
end


Run = true

-- основна¤ функци¤ (нужна чтобы робот работал)
function main()
    while Run do
        sleep(200)
    end
end

function OnStop()
    Run = false
end