
local INSTRUMENT = "SiZ6"
local START_TIME = "1030" -- время начала поиска входа
local END_TIME = "1800" -- время конца поиска входа
local numCandlesForStop = 163 -- колво свечей для расчета размера стопа

local relStopSize; -- относительный размер стопа

local greenState, redState; -- статусы поиска точки входа (0 -- ничего, 1 -- найден фрактал удовл условию а), 2 -- найдена свеча (условие б))
local greenFractal, redFractal; -- значения последних найденных фракталов удовл условию а) (фрактал ниже/выше всех средних)
local candleHigh, candleLow; -- значения свечи из условия б) которые должны быть пробиты следующей свечой

--[[

Сделать:
- сохранение значений найденных последних фракталов при выполнении условия а), переход в состояние 1
- сесли появляется новый фрактал не удовлетворяющий условию а) -- брос статуса на 0
- если новый фрактал удовл условию а) -- обновление фрактала, переход в состояние 1 (если были в другом)

- если в состоянии 1, при закрытии свечи -- проверка на выполнение условия б), переход в состояние 2 (сохраняем номер свечи!)
- если в состоянии 2, смотрим на новую свечу -- если она пробивает мин/макс предыдущей свечи -- АГА (делаем заявки и стопы)
- если в состоянии 2 свеча заканчивается -- сброс на состояние 0

- функция выставления заявок

--]]


-- функция вызывается квиком при запуске робота

function OnInit()
    -- посчитаем относительный размер стопа
    relStopSize = getStopSize()
    PrintDbgStr("Отн. размер стопа: " .. relStopSize)

    -- подпишемся на обновление цены SiZ6
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M5)
    lastBarIndex = DS:Size()
    PrintDbgStr("DS Size: " .. lastBarIndex)
    DS:SetUpdateCallback(NewPrice)
end


-- функция рассчитывает относительный размер стопа

function getStopSize()
    local N = getNumCandles("Price")
    local t, count, l = getCandlesByIndex("Price", 0, N-numCandlesForStop, numCandlesForStop) -- получить последние 163 свечи

    local sum = 0
    for i, row in ipairs(t) do
        sum = sum + (row.high - row.low) / row.low  -- относительный размер свечи
    end

    return 3.75 * sum / count -- сумма относительных размеров свечи деленная на количество свечей
end


-- функция вызывается при каждом обновлении цены

function NewPrice(i)
    PrintDbgStr("New Price: " .. DS:C(i) .. " Свеча№: " .. i)

    -- получим значения индикатора ThreeMOVie в этот момент
    local t0, count, l = getCandlesByIndex("3MA", 0, i-1, 1)
    local t1, count, l = getCandlesByIndex("3MA", 1, i-1, 1)
    local t2, count, l = getCandlesByIndex("3MA", 2, i-1, 1)
    PrintDbgStr(string.format(
        "Линии: %s %s %s",
        string.format('%.1f', t0[0].close),
        string.format('%.1f', t1[0].close),
        string.format('%.1f', t2[0].close)
    ))
    PrintDbgStr("DDDD"..t0[0].datetime.hour..t0[0].datetime.min )

    -- получим значение фрактала в данный момент
    local f, count, l = getCandlesByIndex("Fractal", 0, i-15, 15)
    for k, v in pairs(f) do
        PrintDbgStr(string.format(
            "Фрактал: %s %s %s %s -- %s:%s",
                v.open, v.high, v.low, v.close,
                v.datetime.hour, v.datetime.min
            )
        )
    end

end


-- основная функция (нужна чтобы робот работал)
function main()
    Run = true
    while Run do
        sleep(200)
    end
end

function OnStop()
    Run = false
end