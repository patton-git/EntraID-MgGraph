# 필요한 모듈 로드하기
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.SignIns

# 접근해야할 로그정보로 범위 제한하여 인증
Connect-MgGraph -Scopes "AuditLog.Read.All" -NoWelcome

# 사용자로부터 최근 몇 일 동안 로그를 검토할지 입력 받기
$rangeDays = Read-Host "최근 몇 일 동안의 기록을 불러 올까요?"

# 입력된 값이 숫자인지 확인하고, 숫자로 변환
if ($rangeDays -match '^\d+$') {
    $days = [int]$rangeDays  # 정수로 변환
} else {
    Write-Host "숫자를 입력해주세요."
}
$startDate = (Get-Date).AddDays(-$days)

# -All 옵션이 없을 경우, 최근 1000개만 수집됨, -All 사용시 최대 65535개, 날자+시간값에 대한 크기 비교를 위해서 문자열 형 변환 필요
$RangedSignIn = Get-MgAuditLogSignIn -All -Filter "(createdDateTime ge $($startDate.ToString("yyyy-MM-ddTHH:mm:ssZ")))"

foreach ($event in $RangedSignIn) {
  if ($event.Location.CountryOrRegion -ne "KR") {
    # KST로 변환하여 +9 시간 추가
    $kstDateTime = $event.CreatedDateTime.AddHours(9)
    $filteredSignInLog = @{
      DateTime = $kstDateTime.ToString("yyyy-MM-dd HH:mm:ss") # 24시간 형식으로 변경
      CorrelationId = $event.CorrelationId
      User = $event.UserDisplayName
      Email = $event.UserPrincipalName
      App = $event.AppDisplayName
      Client = $event.ClientAppUsed
      Interactive = $event.IsInteractive
      IP = $event.IPAddress
      Location = $event.Location.CountryOrRegion
      ConditionalAccessStatus = $event.ConditionalAccessStatus
      LoginStatusCode = $event.status.ErrorCode
      LoginStatusReason = $event.status.FailureReason
    }

    $filteredSignInLogs += New-Object PSObject -Property $filteredSignInLog  # 배열에 객체 추가
  }
}

## 1차출력 파일명 결정
$filename = "filtered_" + $startDate.ToString("yyyy-MM-dd-HH-mm-ss") + ".csv"

## 필터링된 로그인 로그 내용을, 1차 출력 파일로 출력함
$filteredSignInLogs | Select-Object DateTime, CorrelationId, User, Email, App, Client, Interactive, IP, Location, ConditionalAccessStatus, LoginStatusCode, LoginStatusReason | Export-Csv -Path $filePath -Encoding UTF8 -NoTypeInformation

# 정보 추출후 연결해제
DisConnect-MgGraph


## 필터링된 로그로부터 날짜 및 IP 주소만을 저장할 해시 테이블을 정의합니다.
$dateIpMap = @{}

## 필터링된 로그 파일 CSV 읽기
Import-Csv -Path $filename | ForEach-Object {
    # 기존의 DateTime에서 시간값을 제외하고 날짜값만을 사용하도록 합니다.
    $date = $_.DateTime.Split(" ")[0]
    # IP 주소를 HashSet에 추가
    if (-not $dateIpMap.ContainsKey($date)) {
        $dateIpMap[$date] = @()
    }
    if (-not $dateIpMap[$date].Contains($_.IP)) {
        $dateIpMap[$date] += $_.IP
    }
}

# 동일 날짜에 다수의 중복된 접속 IP 정보를 제거하고 및 정렬처리한 해시 테이블 생성
$dateIpUniqueSortMap = @{}
foreach ($date in $dateIpMap.Keys) {
    $uniqueIPs = $dateIpMap[$date] | Sort-Object -Unique
    $dateIpUniqueSortMap[$date] = $uniqueIPs
}

# 해시 테이블의 키를 정렬하여, 추출된 날짜들이 정렬된 해시 테이블 생성
$dateIpMap = $dateIpUniqueSortMap.GetEnumerator() | Sort-Object Name | foreach-object {
    $ht = @{ }
    $_.Value | foreach-object { $ht[$_] = $null }
    New-Object PSObject -Property @{ Key = $_.Key; Value = $ht.Keys | Sort-Object }
}

# 일자별 중복제거된 IP들의 개수를 확인해서, 가장 많은 IP들의 개수를 확인함
$maxCount = 0
foreach ($key in $dateIpMap) {
    $count = $key.Value.Count
    if ($count -gt $maxCount) {
        $maxCount = $count
    }
}

# 산출물 출력을 위해서, 날짜 아래에 접속 IP들이 정렬된 형태의 값(column)을 가지도록, 2차원 배열에서 row를 추가하며 데이터를 정렬함.
$output = @()
for ($i = 0; $i -lt $maxCount; $i++) {
    $row = New-Object psobject
    foreach ($date in $dateIpMap) {
        if ($date.Value.Count -gt $i) {
            Add-Member -InputObject $row -MemberType NoteProperty -Name $date.Key -Value $date.Value[$i]
        } else {
            Add-Member -InputObject $row -MemberType NoteProperty -Name $date.Key -Value ""
        }
    }
    $output += $row
}

# 2차 산출물 파일 경로
# 이전 스크립트에서 사용했던 $startDate 변수를 이용해서, filtered 이후에 _DayIP를 추가하는 형태로 저장함.
$outputFile = "filtered_.dayIP_" + $startDate.ToString("yyyy-MM-dd-HH-mm-ss") + ".csv"

# 결과 파일에 작성
$output | Export-Csv -Path $outputFile -NoTypeInformation

