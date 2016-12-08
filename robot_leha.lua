
local INSTRUMENT = "SiZ6"
local START_TIME = "1030" -- ����� ������ ������ �����
local END_TIME = "1800" -- ����� ����� ������ �����
local numCandlesForStop = 163 -- ����� ������ ��� ������� ������� �����

local relStopSize; -- ������������� ������ �����

local greenState, redState; -- ������� ������ ����� ����� (0 -- ������, 1 -- ������ ������� ����� ������� �), 2 -- ������� ����� (������� �))
local greenFractal, redFractal; -- �������� ��������� ��������� ��������� ����� ������� �) (������� ����/���� ���� �������)
local candleHigh, candleLow; -- �������� ����� �� ������� �) ������� ������ ���� ������� ��������� ������

--[[

�������:
- ���������� �������� ��������� ��������� ��������� ��� ���������� ������� �), ������� � ��������� 1
- ����� ���������� ����� ������� �� ��������������� ������� �) -- ���� ������� �� 0
- ���� ����� ������� ����� ������� �) -- ���������� ��������, ������� � ��������� 1 (���� ���� � ������)

- ���� � ��������� 1, ��� �������� ����� -- �������� �� ���������� ������� �), ������� � ��������� 2 (��������� ����� �����!)
- ���� � ��������� 2, ������� �� ����� ����� -- ���� ��� ��������� ���/���� ���������� ����� -- ��� (������ ������ � �����)
- ���� � ��������� 2 ����� ������������� -- ����� �� ��������� 0

- ������� ����������� ������

--]]


-- ������� ���������� ������ ��� ������� ������

function OnInit()
    -- ��������� ������������� ������ �����
    relStopSize = getStopSize()
    PrintDbgStr("���. ������ �����: " .. relStopSize)

    -- ���������� �� ���������� ���� SiZ6
    DS = CreateDataSource("SPBFUT", INSTRUMENT, INTERVAL_M5)
    lastBarIndex = DS:Size()
    PrintDbgStr("DS Size: " .. lastBarIndex)
    DS:SetUpdateCallback(NewPrice)
end


-- ������� ������������ ������������� ������ �����

function getStopSize()
    local N = getNumCandles("Price")
    local t, count, l = getCandlesByIndex("Price", 0, N-numCandlesForStop, numCandlesForStop) -- �������� ��������� 163 �����

    local sum = 0
    for i, row in ipairs(t) do
        sum = sum + (row.high - row.low) / row.low  -- ������������� ������ �����
    end

    return 3.75 * sum / count -- ����� ������������� �������� ����� �������� �� ���������� ������
end


-- ������� ���������� ��� ������ ���������� ����

function NewPrice(i)
    PrintDbgStr("New Price: " .. DS:C(i) .. " �����: " .. i)

    -- ������� �������� ���������� ThreeMOVie � ���� ������
    local t0, count, l = getCandlesByIndex("3MA", 0, i-1, 1)
    local t1, count, l = getCandlesByIndex("3MA", 1, i-1, 1)
    local t2, count, l = getCandlesByIndex("3MA", 2, i-1, 1)
    PrintDbgStr(string.format(
        "�����: %s %s %s",
        string.format('%.1f', t0[0].close),
        string.format('%.1f', t1[0].close),
        string.format('%.1f', t2[0].close)
    ))
    PrintDbgStr("DDDD"..t0[0].datetime.hour..t0[0].datetime.min )

    -- ������� �������� �������� � ������ ������
    local f, count, l = getCandlesByIndex("Fractal", 0, i-15, 15)
    for k, v in pairs(f) do
        PrintDbgStr(string.format(
            "�������: %s %s %s %s -- %s:%s",
                v.open, v.high, v.low, v.close,
                v.datetime.hour, v.datetime.min
            )
        )
    end

end


-- �������� ������� (����� ����� ����� �������)
function main()
    Run = true
    while Run do
        sleep(200)
    end
end

function OnStop()
    Run = false
end