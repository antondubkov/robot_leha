local INSTRUMENT = "SiZ6"
local ACCOUNT = "SPBFUT00LLD"
local CLIENT_CODE = "SPBFUT00LLD" -- ��� �������

local CLOSE_TIME = {hour=15, min=20} -- ����� ��������
local QUANTITY = 1; -- ���������� ��� ��������
local OPERATION = "B"; -- "B" -- ������, "S" -- �������

local BUFFER = 100 -- �����/���������������


-- ���������� ������ ��� ������� ������
function OnInit()
    -- �������������� data source
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M5)
    -- ���������� �� ���������� ���� INSTRUMENT (SiZ6)
    DS:SetUpdateCallback(NewPrice)
    PrintDbgStr("C����� �������� �������! ".. OPERATION .. " " .. tostring(QUANTITY) .. " � " .. CLOSE_TIME.hour .. ":" .. CLOSE_TIME.min)
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
    if dt.hour > CLOSE_TIME.hour or (dt.hour == CLOSE_TIME.hour and dt.min >= CLOSE_TIME.min) then
        PrintDbgStr("����� �������� ���������!")
        doClose(curPrice)
        Run = false -- ���������� ������!!!
    end
end


Run = true

-- �������� ������� (����� ����� ����� �������)
function main()
    while Run do
        sleep(200)
    end
end

function OnStop()
    Run = false
end