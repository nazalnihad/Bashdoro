#!/bin/bash

if ! command -v figlet >/dev/null 2>&1; then
    echo "Error: figlet required. Install with: sudo pacman -S figlet (Arch Linux)"
    exit 1
fi

# Colors
if command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -gt 0 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    MAGENTA=$(tput setaf 5)
    NC=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" CYAN="" MAGENTA="" NC=""
fi

# Messages
MOTIVATIONAL_MESSAGES=("Keep pushing forward!" "You're doing great!" "Stay focused, you got this!" "One step at a time!" "Great work, keep it up!")
 
print_centered() {
    local text="$1" color="$2"
    local width=$(tput cols)
    while IFS= read -r line; do
        printf "%$(( (width - ${#line}) / 2 ))s${color}%s${NC}\n" "" "$line"
    done <<< "$text"
}

display_timer() {
    local minutes=$1 seconds=$2 status=$3 session=$4 type=$5 msg_idx=$6
    local time_str=$(printf "%02d:%02d" $minutes $seconds)
    local ascii=$(figlet -f epic "$(echo "$time_str" | sed 's/:/ : /')")
    local ui_height=$(( $(echo "$ascii" | wc -l) + 10 ))
    local top_pad=$(( ( $(tput lines) - ui_height ) / 2 ))
    [ $top_pad -lt 0 ] && top_pad=0

    tput cup 0 0
    for ((i=0; i<top_pad; i++)); do echo; done
    print_centered "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" "$CYAN"
    print_centered "┃                Bashdoro: $type             ┃" "$CYAN"
    print_centered "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" "$CYAN"
    echo
    print_centered "Session $session of $SESSIONS_BEFORE_LONG_BREAK" "$RED"
    echo
    print_centered "$status" "$YELLOW"
    echo
    print_centered "${MOTIVATIONAL_MESSAGES[$msg_idx]}" "$MAGENTA"
    echo
    print_centered "$ascii" "$GREEN"
    echo
    print_centered "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" "$CYAN"
    print_centered "┃     P: Pause  |  R: Restart  |  Q: Quit       ┃" "$CYAN"
    print_centered "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" "$CYAN"
    echo
}

play_work_sound() {
    for ((i=0; i<5; i++)); do printf "\a"; sleep 0.2; done
}

play_break_sound() {
    for ((i=0; i<3; i++)); do printf "\a"; sleep 0.5; done
}

# Read single key, consume escape sequences
read_key() {
    local timeout="$1" key
    if [ "$timeout" = "0" ]; then
        read -r -n 1 -s key
    else
        read -t "$timeout" -r -n 1 -s key
    fi
    [ -z "$key" ] && echo "" && return
    [ "$key" = $'\033' ] && read -t 0.1 -r -n 3 -s extra && echo "" && return
    echo "$key"
}

set_timer_durations() {
    clear
    echo "Welcome to Bashdoro!"
    echo "1) 25 min work / 5 min break (default)"
    echo "2) 50 min work / 10 min break"
    echo "3) Custom durations"
    echo -n "Enter choice (1-3 or q to quit): "
    read choice
    [ "$choice" = "q" ] || [ "$choice" = "Q" ] && clear && exit 0

    case $choice in
        1)
            WORK_DURATION=25
            BREAK_DURATION=5
            LONG_BREAK_DURATION=15
            SESSIONS_BEFORE_LONG_BREAK=4
            ;;
        2)
            WORK_DURATION=50
            BREAK_DURATION=10
            LONG_BREAK_DURATION=30
            SESSIONS_BEFORE_LONG_BREAK=4
            ;;
        3)
            echo -n "Work duration (minutes, q to quit): "
            read WORK_DURATION
            [ "$WORK_DURATION" = "q" ] || [ "$WORK_DURATION" = "Q" ] && clear && exit 0
            echo -n "Break duration (minutes, q to quit): "
            read BREAK_DURATION
            [ "$BREAK_DURATION" = "q" ] || [ "$BREAK_DURATION" = "Q" ] && clear && exit 0
            echo -n "Long break duration (minutes, q to quit): "
            read LONG_BREAK_DURATION
            [ "$LONG_BREAK_DURATION" = "q" ] || [ "$LONG_BREAK_DURATION" = "Q" ] && clear && exit 0
            echo -n "Sessions before long break (default 4, q to quit): "
            read SESSIONS_BEFORE_LONG_BREAK
            [ "$SESSIONS_BEFORE_LONG_BREAK" = "q" ] || [ "$SESSIONS_BEFORE_LONG_BREAK" = "Q" ] && clear && exit 0
            if ! [[ "$WORK_DURATION" =~ ^[0-9]+$ ]] || ! [[ "$BREAK_DURATION" =~ ^[0-9]+$ ]] || ! [[ "$LONG_BREAK_DURATION" =~ ^[0-9]+$ ]]; then
                echo "Invalid duration. Using default 25/5."
                WORK_DURATION=25
                BREAK_DURATION=5
                LONG_BREAK_DURATION=15
            fi
            if ! [[ "$SESSIONS_BEFORE_LONG_BREAK" =~ ^[0-9]+$ ]] || [ "$SESSIONS_BEFORE_LONG_BREAK" -lt 1 ]; then
                echo "Invalid session count. Using default 4."
                SESSIONS_BEFORE_LONG_BREAK=4
            fi
            ;;
        *)
            echo "Invalid choice. Using default 25/5."
            WORK_DURATION=25
            BREAK_DURATION=5
            LONG_BREAK_DURATION=15
            SESSIONS_BEFORE_LONG_BREAK=4
            ;;
    esac
    clear
}

pomodoro() {
    local test_mode=$1
    local session_count=0 paused=0 msg_idx=0 state="work"
    local work_duration=$WORK_DURATION break_duration=$BREAK_DURATION long_break_duration=$LONG_BREAK_DURATION

    [ "$test_mode" = "test" ] && work_duration=1 && break_duration=1 && long_break_duration=1

    tput civis
    stty -echo
    trap 'tput cnorm; stty echo; clear' EXIT INT TERM

    while true; do
        local seconds duration type status msg
        case $state in
            work)
                ((session_count++))
                duration=$((work_duration * 60))
                type="Pomodoro"
                status="Working"
                msg="Work complete!"
                ;;
            short_break)
                duration=$((break_duration * 60))
                type="Short Break"
                status="Break"
                msg="Break done!"
                ;;
            long_break)
                duration=$((long_break_duration * 60))
                session_count=0
                type="Long Break"
                status="Break"
                msg="Break done!"
                ;;
        esac
        seconds=$duration
        local last_update=$(date +%s)

        while [ $seconds -gt 0 ]; do
            display_timer $((seconds / 60)) $((seconds % 60)) "$status" $session_count "$type" $msg_idx
            key=$(read_key 0.1)
            case $key in
                p|P)
                    paused=$((1 - paused))
                    if [ $paused -eq 1 ]; then
                        display_timer $((seconds / 60)) $((seconds % 60)) "Paused" $session_count "$type" $msg_idx
                        while [ $paused -eq 1 ]; do
                            key=$(read_key 0)
                            case $key in
                                p|P) paused=0 ;;
                                r|R) seconds=$duration; paused=0 ;;
                                q|Q) clear; exit 0 ;;
                                *) ;;
                            esac
                        done
                        last_update=$(date +%s)
                    fi
                    ;;
                r|R) seconds=$duration; last_update=$(date +%s) ;;
                q|Q) clear; exit 0 ;;
                *) ;;
            esac
            if [ $paused -eq 0 ]; then
                current_time=$(date +%s)
                if [ $((current_time - last_update)) -ge 1 ]; then
                    ((seconds--))
                    last_update=$current_time
                    [ $((seconds % 60)) -eq 0 ] && msg_idx=$(( (msg_idx + 1) % ${#MOTIVATIONAL_MESSAGES[@]} ))
                fi
            fi
        done

        [ "$state" = "work" ] && play_work_sound || play_break_sound
        clear
        print_centered "$(figlet -f big "$msg")" "$CYAN"
        sleep 2

        case $state in
            work)
                state=$([ $session_count -eq $SESSIONS_BEFORE_LONG_BREAK ] && echo "long_break" || echo "short_break")
                ;;
            *) state="work" ;;
        esac
    done
}

clear
set_timer_durations
[ "$1" = "--test" ] && pomodoro "test" || pomodoro "normal"