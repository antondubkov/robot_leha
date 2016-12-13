local INSTRUMENT = "SiZ6"
local ACCOUNT = "SPBFUT00LLD"
local CLIENT_CODE = "SPBFUT00LLD" -- код клиента
local START_TIME = {hour=10, min=30} -- время начала поиска входа
local END_TIME = {hour=18, min=00} -- время конца поиска входа
local BUFFER = 100 -- спред/проскальзывание
local STOP_MULTIPLIER = 4 -- мультипликатор для относительного размера стопа
local numCandlesForStop = 163 -- колво свечей для расчета размера стопа

------------------------------------------------------------------------

local ACCOUNT_BALANCE; -- баланс счета -- считывается из Квика при запуске робота (лимит открытия позиций из Ограничений по Клиентским Счетам)
local GO; -- Г.О. продавца (будет считан из Квика)
local relStopSize; -- относительный размер стопа

-- статусы поиска точки входа (0 -- ничего, 1 -- найден фрактал удовл условию а), 2 -- найдена свеча (условие б))
local b_state = 0
local s_state = 0

local greenf_idx, redf_idx; -- значения последних найденных фракталов (не обяз удовл усл)
local greenf_dt, redf_dt; -- значения datetime последних фракталов (не обяз удовл усл)

-- значения последних найденных фракталов, если они удовл условию а) (фрактал ниже/выше всех средних), иначе 0
local greenf_val = 0
local redf_val = 0;

local high, low; -- значения свечи из условия б) которые должны быть пробиты следующей свечой
local high_idx, low_idx; -- номера этих свечей

local last_idx; -- номер свечи на прошлом тике


-- функция вызывается квиком при запуске робота

function OnInit()
    -- посчитаем относительный размер стопа
    relStopSize = getStopSize()
    PrintDbgStr("Отн. размер стопа: " .. relStopSize)

    -- определим лимит открытия позиций
    for i = 0,getNumberOf("futures_client_limits") - 1 do
        local x = getItem("futures_client_limits", i)
        if x.trdaccid == ACCOUNT and x.limit_type == 0 then
            ACCOUNT_BALANCE = x.cbplplanned
            PrintDbgStr("Баланс Счета: "..ACCOUNT_BALANCE.. " -- " .. x.kgo )
            break
        end
    end

    -- считаем ГО продавца из квика
    GO = getParamEx("SPBFUT", INSTRUMENT, "BUYDEPO").param_value
    PrintDbgStr("ГО: ".. tostring(GO))

    -- инициализируем data source
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M5)
    last_idx = DS:Size()
    --PrintDbgStr("DS Size: " .. last_idx)

    -- найдем индексы и время последних фракталов
    searchFractals()

    -- подпишемся на обновление цены INSTRUMENT (SiZ6)
    DS:SetUpdateCallback(NewPrice)
end


-- поиск последних фракталов + проверка условия а)
function searchFractals()
    local N = getNumCandles("Fractal")
    local tbl, count, l = getCandlesByIndex("Fractal", 0, N-163, 163)
    for k, v in pairs(tbl) do
        if v.high > 0 then
            greenf_idx = N - 163 + k
            greenf_dt = v.datetime
            -- если наш зеленый фрактал выше средних -- сохраняем его
            if greenFractalMatch(v.high) then
                greenf_val = v.high
                b_state = 1
            else
                b_state = 0
            end
        end
        if v.low > 0 then
            redf_idx = N - 163 + k
            redf_dt = v.datetime
            -- если наш красный фрактал ниже средних -- сохраняем его
            if redFractalMatch(v.low) then
                redf_val = v.low
                s_state = 1
            else
                s_state =0
            end
        end
    end

    PrintDbgStr(string.format(
        "Найденные последние фракталы: %s:%s, %s:%s",
            greenf_dt.hour, greenf_dt.min,
            redf_dt.hour, redf_dt.min
        )
    )
    PrintDbgStr(string.format(
        "Состояния: зел:%s, красн:%s",
            b_state, s_state
        )
    )
end


function greenFractalMatch(val)
    -- проверка что это фрактал из сегодняшних свечей
    if greenf_dt.hour == 10 and greenf_dt.min < 5 then
        return false
    end

    -- получим значения индикатора ThreeMOVie в момент зеленого фрактала
    local t0, count, l = getCandlesByIndex("3MA", 0, greenf_idx, 1)
    local t1, count, l = getCandlesByIndex("3MA", 1, greenf_idx, 1)
    local t2, count, l = getCandlesByIndex("3MA", 2, greenf_idx, 1)
    v0 = t0[0].close
    v1 = t1[0].close
    v2 = t2[0].close

    if val > v0 and val > v1 and val > v2 then
        return true
    end

    return false
end


function redFractalMatch(val)
    -- проверка что это фрактал из сегодняшних свечей
    if redf_dt.hour == 10 and redf_dt.min < 5 then
        return false
    end

    -- получим значения индикатора ThreeMOVie в момент красного фрактала
    local t0, count, l = getCandlesByIndex("3MA", 0, redf_idx, 1)
    local t1, count, l = getCandlesByIndex("3MA", 1, redf_idx, 1)
    local t2, count, l = getCandlesByIndex("3MA", 2, redf_idx, 1)

    v0 = t0[0].close
    v1 = t1[0].close
    v2 = t2[0].close

    if val < v0 and val < v1 and val < v2 then
        return true
    end

    return false
end


-- функция рассчитывает относительный размер стопа
function getStopSize()
    local N = getNumCandles("Price")
    local t, count, l = getCandlesByIndex("Price", 0, N-numCandlesForStop, numCandlesForStop) -- получить последние 163 свечи

    local sum = 0
    for i, row in ipairs(t) do
        sum = sum + (row.high - row.low) / row.low  -- относительный размер свечи
    end

    PrintDbgStr(sum)
    PrintDbgStr(count)

    return STOP_MULTIPLIER * sum / count -- сумма относительных размеров свечи деленная на количество свечей
end


function searchNewFractals(i)
    -- вызывается если найдена новая свеча
    -- проверяем только свечу номер i-3 (для фрактала нужно 2 последующие завершенные свечи)

    local tbl, count, l = getCandlesByIndex("Fractal", 0, i-3, 1)
    v = tbl[0]
    PrintDbgStr("Проверяем фрактал " .. v.open .. " " .. v.high .. " " .. v.low .. " ".. v.close .. " " .. v.datetime.hour .. ":" .. v.datetime.min)

    if i > greenf_idx and v.high > 0 then
        -- запоминаем фрактал
        greenf_idx = i-3
        greenf_dt = v.datetime
        PrintDbgStr("Новый зеленый " .. v.high .. " " .. v.datetime.hour .. ":" .. v.datetime.min)

        if b_state ~= 0 then
            -- сбрасываем все состояния
            b_state = 0
            high = 0
            high_idx = 0
            PrintDbgStr("Сброс зеленого!")
        end

        -- если наш зеленый фрактал выше средних -- сохраняем его
        if greenFractalMatch(v.high) then
            greenf_val = v.high
            b_state = 1
            PrintDbgStr("Фрактал подходит!")
        end
    end

    if i > redf_idx and v.low > 0 then
        -- запоминаем фрактал
        redf_idx = i-3
        redf_dt = v.datetime
        PrintDbgStr("Новый красный " .. v.low .. " " .. v.datetime.hour .. ":" .. v.datetime.min)

        if s_state ~= 0 then
            -- сбрасываем все состояния
            s_state = 0
            low = 0
            low_idx = 0
            PrintDbgStr("Сброс красного!")
        end

        -- если наш красный фрактал ниже средних -- сохраняем его
        if redFractalMatch(v.low) then
            redf_val = v.low
            s_state = 1
            PrintDbgStr("Фрактал подходит!")
        end
    end

end


function getQuantity()
    return math.floor(ACCOUNT_BALANCE / GO)
end

function doBuy(curPrice)
    PrintDbgStr("ПОКУПАЕМ!")

    local q = getQuantity()
    local price = curPrice + BUFFER -- цена заявки на покупку
    local stop_price = math.floor(price - price * relStopSize) -- уровень стопа

    -- заявка
    local order = {
        ["TRANS_ID"]    = "1",
        ["ACTION"]      = "NEW_ORDER",
        ["CLASSCODE"]   = "SPBFUT",
        ["CLIENT_CODE"] = CLIENT_CODE,
        ["SECCODE"]     = INSTRUMENT,
        ["ACCOUNT"]     = ACCOUNT,
        ["OPERATION"]   = "B",
        ["QUANTITY"]    = string.format('%.0f', q),
        ["PRICE"]       = string.format('%.0f', price)
        --["TYPE"]        = L  -- так было в прошлом роботе, не знаю что это значит
    }

    -- стоп-заявка
    local stop = {
        ["TRANS_ID"]    = "2",
        ["ACTION"]      = "NEW_STOP_ORDER",
        ["CLASSCODE"]   = "SPBFUT",
        ["SECCODE"]     = INSTRUMENT,
        ["ACCOUNT"]     = ACCOUNT,
        ["OPERATION"]   = "S",
        ["QUANTITY"]    = string.format('%.0f', q),
        ["STOPPRICE"]   = string.format('%.0f', stop_price),
        ["PRICE"]       = string.format('%.0f', stop_price - BUFFER),
        ["EXPIRY_DATE"] = "TODAY"
    }

    sendTransaction(order)
    sendTransaction(stop)
end


function doSell(curPrice)
    PrintDbgStr("ПРОДАЕМ!")

    local q = getQuantity()
    local price = curPrice - BUFFER -- цена заявки на продажу
    local stop_price = math.floor(price + price * relStopSize) -- уровень стопа

    -- заявка
    local order = {
        ["TRANS_ID"]    = "1",
        ["ACTION"]      = "NEW_ORDER",
        ["CLASSCODE"]   = "SPBFUT",
        ["CLIENT_CODE"] = CLIENT_CODE,
        ["SECCODE"]     = INSTRUMENT,
        ["ACCOUNT"]     = ACCOUNT,
        ["OPERATION"]   = "S",
        ["QUANTITY"]    = string.format('%.0f', q),
        ["PRICE"]       = string.format('%.0f', price)
        --["TYPE"]        = L  -- так было в прошлом роботе, не знаю что это значит
    }

    -- стоп-заявка
    local stop = {
        ["TRANS_ID"]    = "2",
        ["ACTION"]      = "NEW_STOP_ORDER",
        ["CLASSCODE"]   = "SPBFUT",
        ["SECCODE"]     = INSTRUMENT,
        ["ACCOUNT"]     = ACCOUNT,
        ["OPERATION"]   = "B",
        ["QUANTITY"]    = string.format('%.0f', q),
        ["STOPPRICE"]   = string.format('%.0f', stop_price),
        ["PRICE"]       = string.format('%.0f', stop_price + BUFFER),
        ["EXPIRY_DATE"] = "TODAY"
    }

    sendTransaction(order)
    sendTransaction(stop)
end


function NewPrice(i)
    -- функция вызывается при каждом обновлении цены
    local curPrice = DS:C(i)

    -- новая свеча -- произвести необходимые действия
    if last_idx < i then
        PrintDbgStr("Новая свеча №".. i .. ", состояния: " .. b_state .. " " .. s_state)

        -- если было состояние 2 -- сбрасываем на 0 (означает что мы не нашли на прошлой свече пробоя макс/мин предыдущей свечи)
        if b_state == 2 then
            PrintDbgStr("Сброс зеленого статуса")
            b_state = 0
        end
        if s_state == 2 then
            PrintDbgStr("Сброс красного статуса")
            s_state = 0
        end

        -- обновить значения новых фракталов. Если новые -- сбросить статусы
        searchNewFractals(i)

        -- если мы в статусе 1 -- проверить прошлую свечу на удовл условию б)
        if b_state == 1 or s_state == 1 then
            local tbl, count, l = getCandlesByIndex("Price", 0, i-1, 1)
            v = tbl[0]
            if b_state == 1 then
                if v.close > greenf_val then
                    b_state = 2
                    high = v.high
                    PrintDbgStr("Состояние 2 для зеленого фрактала!")
                end
            end

            if s_state == 1 then
                if v.close < redf_val then
                    b_state = 2
                    low = v.low
                    PrintDbgStr("Состояние 2 для красного фрактала!")
                end
            end
        end

        last_idx = i
    end

    -- если мы в статусе 2 -- проверяем текущую цену на условие в)
    if b_state == 2 then
        if curPrice > high then
            -- покупаем
            doBuy(curPrice)
            -- конец
            Run = false
            return
        end
    end

    if s_state == 2 then
        -- продаем
        doSell(curPrice)
        -- конец
        Run = false
        return
    end

end


Run = true

-- основная функция (нужна чтобы робот работал)
function main()
    while Run do
        sleep(200)
    end
    PrintDbgStr("Завершение работы")
end

function OnStop()
    Run = false
end