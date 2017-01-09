require "settings" -- ����� ����������, ��� ������� � ����� ������

local CLOSE_TIME = {hour=15, min=20} -- ����� ��������
local QUANTITY = 1; -- ���������� ��� ��������
local OPERATION = "B"; -- "B" -- ������, "S" -- �������

local trade_date = {}


-- ���������� ������ ��� ������� ������
function OnInit()

	-- �������� ������� ����
	trade_date = os.date("*t", os.time())
    -- �������������� data source
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M1)
    -- ���������� �� ���������� ���� INSTRUMENT (SiZ6)
    DS:SetUpdateCallback(NewPrice)
    PrintDbgStr("C����� �������� �������!".. trade_date.day .." ".. OPERATION .. " " .. tostring(QUANTITY) .. " � " .. CLOSE_TIME.hour .. ":" .. CLOSE_TIME.min)
end



function doClose(curPrice)
    PrintDbgStr("�����������!")

    local price; -- ���� ������
    if OPERATION == "B" then
        price = curPrice + BUFFER -- ���� ������ �� �������
    else
        price = curPrice - BUFFER -- ���� ������ �� �������
    end
    -- ������
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

function NewPrice(i)  -- ������� ���������� ��� ������ ���������� ����
    local curPrice = DS:C(i)
    local dt = DS:T(i)
    if Run and dt.day == trade_date.day and (dt.hour > CLOSE_TIME.hour or (dt.hour == CLOSE_TIME.hour and dt.min >= CLOSE_TIME.min)) then
        Run = false -- ���������� ������!!!
        PrintDbgStr("����� �������� ���������!")
        doClose(curPrice)
    end
end


Run = true

-- �������� ������� (����� ����� ����� �������)
function main()
    while Run do
        sleep(1000)
    end
end

function OnStop()
    Run = false
end