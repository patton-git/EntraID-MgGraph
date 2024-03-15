## 
## Microsoft.Graph에서 사용하는 변수와 기능의 개수들이 많기 때문에, 기본값 4096으로는 제한이 걸려서 설치가 불가능할 수 있음.
$MaximumVariableCount = 10000 
$MaximumFunctionCount = 10000 

## Microsoft.Graph 모듈 설치하기
Install-Module Microsoft.Graph -Scope CurrentUser 

## Microsoft.Graph 모듈 로드하기
import-module microsoft.graph

## 사용자들에 대한 전체 읽기 권한을 가지고 연결
Connect-MgGraph -scopes "User.Read.All" -NoWelcome

## 사용자 타입 Guest를 제외하고, 최종 변경일이 오래된 순서대로 정렬하여, 
$currentStatus = Get-MgUser -All -Property usertype,DisplayName,Mail,LastPasswordChangeDateTime | where {$_.usertype -ne "guest"} | Select-Object DisplayName,Mail,LastPasswordChangeDateTime | Sort-Object -Property LastPasswordChangeDateTime
# UTC 기준의 시간값을 KST (+9)으로 변경
$currentStatus = $currentStatus.lastPasswordChangeDateTime.AddHours(9)

## 현재 시각을 정보를 파일명에 반영함
$filename = "lastPasswordChangeDate_" + (get-date -Format "yyyy-mm-dd_HH-mm-ss") + ".csv"
## UTF-8 방식을 이용하여 한글 깨짐을 방지함.
$currentStatus | Export-Csv -Path $filename -Encoding UTF8 -NoTypeInformation
