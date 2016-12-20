require "settings"

------------------------------------------------------------------------

local ACCOUNT_BALANCE; -- ������ ����� -- ����������� �� ����� ��� ������� ������ (����� �������� ������� �� ����������� �� ���������� ������)
local GO; -- �.�. �������� (����� ������ �� �����)
local trade_date = {}

-- ������� ������ ����� ����� (0 -- ������, 1 -- ������ ������� ����� ������� �), 2 -- ������� ����� (������� �))
local b_state = 0
local s_state = 0

local greenf_idx, redf_idx; -- �������� ��������� ��������� ��������� (�� ���� ����� ���)
local greenf_dt, redf_dt; -- �������� datetime ��������� ��������� (�� ���� ����� ���)

-- �������� ��������� ��������� ���������, ���� ��� ����� ������� �) (������� ����/���� ���� �������), ����� 0
local greenf_val = 0
local redf_val = 0;

local high, low; -- �������� ����� �� ������� �) ������� ������ ���� ������� ��������� ������
local high_idx, low_idx; -- ������ ���� ������

local last_idx; -- ����� ����� �� ������� ����


-- ������� ���������� ������ ��� ������� ������

function OnInit()

    trade_date = os.date("*t", os.time())

    PrintDbgStr("�������� ����: " ..trade_date.day.."."..trade_date.month.."."..trade_date.year )

    -- �������������� data source
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M5)
    last_idx = DS:Size()
    --PrintDbgStr("DS Size: " .. last_idx)

    -- ������ ������� � ����� ��������� ���������
    searchFractals()

    -- ���������� �� ���������� ���� INSTRUMENT (SiZ6)
    DS:SetUpdateCallback(NewPrice)
end


-- ����� ��������� ��������� ��� ������ ������� + �������� ������� �)
function searchFractals()
    local N = getNumCandles("Fractal")
    local tbl, count, l = getCandlesByIndex("Fractal", 0, N-163, 160)
    for k, v in pairs(tbl) do
        if v.high > 0 then
            greenf_idx = N - 163 + k
            greenf_dt = v.datetime
            -- ���� ��� ������� ������� ���� ������� -- ��������� ���
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
            -- ���� ��� ������� ������� ���� ������� -- ��������� ���
            if redFractalMatch(v.low) then
                redf_val = v.low
                s_state = 1
            else
                s_state =0
            end
        end
    end

    PrintDbgStr(string.format(
        "��������� ��������� ��������: %s:%s, %s:%s",
            greenf_dt.hour, greenf_dt.min,
            redf_dt.hour, redf_dt.min
        )
    )
    PrintDbgStr(string.format(
        "���������: ���:%s, �����:%s",
            b_state, s_state
        )
    )
end


function greenFractalMatch(val)
    -- �������� ��� ��� ������� �����������
    if not (greenf_dt.day >= trade_date.day and (greenf_dt.hour > START_TIME.hour or (greenf_dt.hour == START_TIME.hour and greenf_dt.min >= START_TIME.min))) then
        return false
    end

    -- ������� �������� ���������� ThreeMOVie � ������ �������� ��������
    local t0, count, l = getCandlesByIndex("3MA", 0, greenf_idx, 1)
    local t1, count, l = getCandlesByIndex("3MA", 1, greenf_idx, 1)
    local t2, count, l = getCandlesByIndex("3MA", 2, greenf_idx, 1)
    v0 = t0[0].close
    v1 = t1[0].close
    v2 = t2[0].close

    -- �������� ��� ���� ������� ������� ���� ���� �������
    if val > v0 and val > v1 and val > v2 then
        return true
    end

    return false
end


function redFractalMatch(val)
    -- �������� ��� ��� ������� �� ����������� ������
    if not (redf_dt.day >= trade_date.day and (redf_dt.hour > START_TIME.hour or (redf_dt.hour == START_TIME.hour and redf_dt.min >= START_TIME.min))) then
        return false
    end

    -- ������� �������� ���������� ThreeMOVie � ������ �������� ��������
    local t0, count, l = getCandlesByIndex("3MA", 0, redf_idx, 1)
    local t1, count, l = getCandlesByIndex("3MA", 1, redf_idx, 1)
    local t2, count, l = getCandlesByIndex("3MA", 2, redf_idx, 1)

    v0 = t0[0].close
    v1 = t1[0].close
    v2 = t2[0].close

    -- �������� ��� ���� ������� ������� ���� ���� �������
    if val < v0 and val < v1 and val < v2 then
        return true
    end

    return false
end


-- ������� ������������ ������������� ������ �����
function getStopSize()
    local N = getNumCandles("Price")
    local t, count, l = getCandlesByIndex("Price", 0, N-numCandlesForStop, numCandlesForStop) -- �������� ��������� 163 �����

    local sum = 0
    for i, row in ipairs(t) do
        sum = sum + (row.high - row.low) / row.low  -- ������������� ������ �����
    end

    return STOP_MULTIPLIER * sum / count -- ����� ������������� �������� ����� �������� �� ���������� ������
end


function searchNewFractals(i)
    -- ���������� ���� ������� ����� �����
    -- ��������� ������ ����� ����� i-4 (��� �������� ����� 2 ����������� ����������� �����)

    local tbl, count, l = getCandlesByIndex("Fractal", 0, i-4, 1)
    v = tbl[0]
    PrintDbgStr("��������� ������� " .. v.open .. " " .. v.high .. " " .. v.low .. " ".. v.close .. " " .. v.datetime.hour .. ":" .. v.datetime.min)

    if i > greenf_idx and v.high > 0 then
        -- ���������� �������
        greenf_idx = i-3
        greenf_dt = v.datetime
        PrintDbgStr("����� ������� " .. v.high .. " " .. v.datetime.hour .. ":" .. v.datetime.min)

        if b_state ~= 0 then
            -- ���������� ��� ���������
            b_state = 0
            high = 0
            high_idx = 0
            PrintDbgStr("����� ��������!")
        end

        -- ���� ��� ������� ������� ���� ������� -- ��������� ���
        if greenFractalMatch(v.high) then
            greenf_val = v.high
            b_state = 1
            PrintDbgStr("������� ��������!")
        end
    end

    if i > redf_idx and v.low > 0 then
        -- ���������� �������
        redf_idx = i-3
        redf_dt = v.datetime
        PrintDbgStr("����� ������� " .. v.low .. " " .. v.datetime.hour .. ":" .. v.datetime.min)

        if s_state ~= 0 then
            -- ���������� ��� ���������
            s_state = 0
            low = 0
            low_idx = 0
            PrintDbgStr("����� ��������!")
        end

        -- ���� ��� ������� ������� ���� ������� -- ��������� ���
        if redFractalMatch(v.low) then
            redf_val = v.low
            s_state = 1
            PrintDbgStr("������� ��������!")
        end
    end

end


function getQuantity(operation, price)
    -- ��������� ����� �������� �������
    for i = 0,getNumberOf("futures_client_limits") - 1 do
        local x = getItem("futures_client_limits", i)
        if x.trdaccid == ACCOUNT and x.limit_type == 0 then
            ACCOUNT_BALANCE = x.cbplplanned
            PrintDbgStr("������ �����: "..ACCOUNT_BALANCE)
            break
        end
    end

    -- ������� ��� �������� �� �����
    local BGO = tonumber(getParamEx("SPBFUT", INSTRUMENT, "BUYDEPO").param_value)
    PrintDbgStr("���: ".. tostring(BGO))

    local PREVPRICE = tonumber(getParamEx("SPBFUT", INSTRUMENT, "PREVPRICE").param_value) -- ���� ��������
    local STEPPRICE = tonumber(getParamEx("SPBFUT", INSTRUMENT, "STEPPRICE").param_value) -- ��������� ���� ����
    local SEC_PRICE_STEP = tonumber(getParamEx("SPBFUT", INSTRUMENT, "SEC_PRICE_STEP").param_value) -- ��� ����

    PrintDbgStr("������: "..tostring(PREVPRICE).." ".. tostring(STEPPRICE) .." " ..tostring(SEC_PRICE_STEP))

    local GO = BGO;

    -- �������, ���� ���� ������ ������ ���� ��������
    -- �� = (��� + (���� ������ - ���� ��������)) * (��������� ���� ����/��� ����).
    if operation == "B" and price > PREVPRICE then
       GO = (BGO + (price - PREVPRICE)) * (STEPPRICE / SEC_PRICE_STEP)
    end

    -- ��� ������ �� �������, ���� ���� ������ ��������
    -- �� = (��� + (���� �������� - ���� ������)) * (��������� ���� ����/��� ����).

    if operation == "S" and price < PREVPRICE then
        GO = (BGO + (PREVPRICE - price)) * (STEPPRICE / SEC_PRICE_STEP)
    end

    PrintDbgStr("���� ��: ".. GO)

    return math.floor(ACCOUNT_BALANCE / GO)
end

function doBuy(curPrice)
    local price = curPrice + BUFFER -- ���� ������ �� �������
    local q = getQuantity("B", price)

    PrintDbgStr("��������! "..tostring(q))

    -- ��������� ������������� ������ �����
    local relStopSize = getStopSize()
    PrintDbgStr("���. ������ �����: " .. relStopSize)

    local stop_price = math.floor(price - price * relStopSize) -- ������� �����

    -- ������
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
        --["TYPE"]        = L  -- ��� ���� � ������� ������, �� ���� ��� ��� ������
    }

    -- ����-������
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
    local price = curPrice - BUFFER -- ���� ������ �� �������
    local q = getQuantity("S", price)

    PrintDbgStr("�������! "..tostring(q))

    -- ��������� ������������� ������ �����
    local relStopSize = getStopSize()
    PrintDbgStr("���. ������ �����: " .. relStopSize)

    local stop_price = math.floor(price + price * relStopSize) -- ������� �����

    -- ������
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
        --["TYPE"]        = L  -- ��� ���� � ������� ������, �� ���� ��� ��� ������
    }

    -- ����-������
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


-- ������� ���������� ��� ������ ���������� ����
function NewPrice(i)

    -- ������ �� ������ ���� ���� �����������
    if not Run then
        return
    end

    local curPrice = DS:C(i) -- ����
    local dt = DS:T(i) -- ����� ����� �����

    -- ����� ����� -- ���������� ����������� ��������
    if last_idx < i then
        PrintDbgStr("������ ����� �����, ����� ".. dt.hour ..":"..dt.min.. ", ���������: " .. b_state .. " " .. s_state)

        last_idx = i

        -- �������� END_TIME
        if dt.hour > END_TIME.hour or (dt.hour == END_TIME.hour and dt.min >= END_TIME.min) then
            PrintDbgStr("END_TIME ���������! ���������� ������...")
            Run = false
            return
        end

        -- ���� ���� ��������� 2 -- ���������� �� 0 (�������� ��� �� �� ����� �� ������� ����� ������ ����/��� ���������� �����)
        if b_state == 2 then
            PrintDbgStr("����� �������� �������")
            b_state = 0
        end
        if s_state == 2 then
            PrintDbgStr("����� �������� �������")
            s_state = 0
        end

        -- �������� �������� ����� ���������. ���� ����� -- �������� �������
        searchNewFractals(i)

        -- ���� �� � ������� 1 -- ��������� ������� ����� �� ����� ������� �)
        if b_state == 1 or s_state == 1 then
            local tbl, count, l = getCandlesByIndex("Price", 0, i-2, 1)
            v = tbl[0]
            if b_state == 1 then
                if v.close > greenf_val then
                    b_state = 2
                    high = v.high
                    PrintDbgStr("��������� 2 ��� �������� ��������!")
                end
            end

            if s_state == 1 then
                if v.close < redf_val then
                    s_state = 2
                    low = v.low
                    PrintDbgStr("��������� 2 ��� �������� ��������!")
                end
            end
        end
    end

    -- ���� �� � ������� 2 -- ��������� ������� ���� �� ������� �)
    if b_state == 2 then
        if curPrice > high then
            -- ��������
            doBuy(high)
            -- �����
            Run = false
            return
        end
    end

    if s_state == 2 then
        if curPrice < low then
            -- �������
            doSell(low)
            -- �����
            Run = false
            return
        end
    end

end


Run = true

-- �������� ������� (����� ����� ����� �������)
function main()
    while Run do
        sleep(200)
    end
    PrintDbgStr("���������� ������")
end

function OnStop()
    Run = false
end