#!/bin/bash

# Bashdoro: A minimal Pomodoro timer 

# Check if figlet is installed
if ! command -v figlet >/dev/null 2>&1; then
    echo "Error: figlet is required but not installed."
    echo "Install it with: sudo apt install figlet (Ubuntu/Debian) or brew install figlet (macOS)"
    exit 1
fi

# Check if tput is available and terminal supports colors
if command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -gt 0 ]; then
    RED=$(tput setaf 1)    # Red for session info
    GREEN=$(tput setaf 2)  # Green for timer
    YELLOW=$(tput setaf 3) # Yellow for status
    CYAN=$(tput setaf 6)   # Cyan for borders
    MAGENTA=$(tput setaf 5) # Magenta for motivational message
    NC=$(tput sgr0)        # Reset color
else
    RED=""
    GREEN=""
    YELLOW=""
    CYAN=""
    MAGENTA=""
    NC=""
fi

MOTIVATIONAL_MESSAGES=(
    "Keep pushing forward!"
    "You're doing great!"
    "Stay focused, you got this!"
    "One step at a time!"
    "Great work, keep it up!"
)

# center text horizontally
center_text() {
    local text="$1"
    local width=$(tput cols)
    local padding=$(( (width - ${#text}) / 2 ))
    printf "%${padding}s%s%${padding}s\n" "" "$text" ""
}

#  number to ASCII 
number_to_ascii() {
    local num="$1"
    local ascii_art
    local spaced_num=$(echo "$num" | sed 's/:/ : /')
    ascii_art=$(figlet -f big "$spaced_num")
    while IFS= read -r line; do
        center_text "${GREEN}${line}${NC}"
    done <<< "$ascii_art"
}

get_timer_height() {
    local num="$1"
    local spaced_num=$(echo "$num" | sed 's/:/ : /')
    local ascii_art
    ascii_art=$(figlet -f big "$spaced_num")
    echo "$ascii_art" | wc -l
}

display_timer() {
    local minutes=$1
    local seconds=$2
    local status=$3
    local session=$4
    local timer_type=$5
    local message_index=$6

    # terminal dimensions
    local term_height=$(tput lines)
    local term_width=$(tput cols)

    # height of UI
    local time_str=$(printf "%02d:%02d" $minutes $seconds)
    local timer_height=$(get_timer_height "$time_str") 
    local ui_elements=10 
    local total_ui_height=$((timer_height + ui_elements))

    #  padding to center vertically
    local top_padding=$(( (term_height - total_ui_height) / 2 ))
    [ $top_padding -lt 0 ] && top_padding=0

    #  cursor to top-left corner without clearing
    tput cup 0 0

    #  top padding for vertical centering
    for ((i = 0; i < top_padding; i++)); do
        printf "\n"
    done

    #  UI with regular text for non-timer elements
    center_text "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    center_text "${CYAN}┃            Bashdoro: $timer_type             ┃${NC}"
    center_text "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    printf "\n"
    center_text "${RED}Session $session of $SESSIONS_BEFORE_LONG_BREAK${NC}"
    printf "\n"
    center_text "${YELLOW}$status${NC}"
    printf "\n"
    center_text "${MAGENTA}${MOTIVATIONAL_MESSAGES[$message_index]}${NC}"
    printf "\n"
    number_to_ascii "$time_str"
    printf "\n"
    center_text "${CYAN}┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓${NC}"
    center_text "${CYAN}┃     P: Pause  |  R: Restart  |  Q: Quit      ┃${NC}"
    center_text "${CYAN}┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛${NC}"
    printf "\n"
}

play_work_sound() {
    for ((i = 0; i < 5; i++)); do
        printf "\a"
        sleep 0.2
    done
}

play_break_sound() {
    for ((i = 0; i < 3; i++)); do
        printf "\a"
        sleep 0.5
    done
}

#  initial menu and set timer durations
set_timer_durations() {
    clear
    echo "Welcome to Bashdoro!"
    echo "Select a timer configuration:"
    echo "1) 25 min work / 5 min break (default)"
    echo "2) 50 min work / 10 min break"
    echo "3) Custom durations"
    echo -n "Enter your choice (1-3): "
    read choice

    case $choice in
        1)
            WORK_DURATION=25
            BREAK_DURATION=5
            LONG_BREAK_DURATION=15
            ;;
        2)
            WORK_DURATION=50
            BREAK_DURATION=10
            LONG_BREAK_DURATION=30
            ;;
        3)
            echo -n "Enter work duration (minutes): "
            read WORK_DURATION
            echo -n "Enter break duration (minutes): "
            read BREAK_DURATION
            echo -n "Enter long break duration (minutes): "
            read LONG_BREAK_DURATION
            # Validate inputs
            if ! [[ "$WORK_DURATION" =~ ^[0-9]+$ ]] || ! [[ "$BREAK_DURATION" =~ ^[0-9]+$ ]] || ! [[ "$LONG_BREAK_DURATION" =~ ^[0-9]+$ ]]; then
                echo "Invalid input. Using default 25/5."
                WORK_DURATION=25
                BREAK_DURATION=5
                LONG_BREAK_DURATION=15
            fi
            ;;
        *)
            echo "Invalid choice. Using default 25/5."
            WORK_DURATION=25
            BREAK_DURATION=5
            LONG_BREAK_DURATION=15
            ;;
    esac
    clear
}


pomodoro() {
    local test_mode=$1
    local session_count=0
    local paused=0
    local work_duration=$WORK_DURATION
    local break_duration=$BREAK_DURATION
    local message_index=0

    if [ "$test_mode" = "test" ]; then
        work_duration=1
        break_duration=1
        LONG_BREAK_DURATION=1
    fi

    while true; do
        ((session_count++))
        # Work session
        local seconds=$((work_duration * 60))
        while [ $seconds -gt 0 ]; do
            display_timer $((seconds / 60)) $((seconds % 60)) "Working" $session_count "Pomodoro" $message_index
            read -t 1 -n 1 -s key
            case $key in
                p|P) 
                    paused=$((1 - paused))
                    if [ $paused -eq 1 ]; then
                        display_timer $((seconds / 60)) $((seconds % 60)) "Paused" $session_count "Pomodoro" $message_index
                        while [ $paused -eq 1 ]; do
                            read -n 1 -s key
                            case $key in
                                p|P) paused=0 ;;
                                r|R) seconds=$((work_duration * 60)); paused=0 ;;
                                q|Q) clear; exit 0 ;;
                            esac
                        done
                    fi
                    ;;
                r|R) seconds=$((work_duration * 60)) ;;
                q|Q) clear; exit 0 ;;
            esac
            if [ $paused -eq 0 ]; then
                ((seconds--))
                if [ $((seconds % 60)) -eq 0 ]; then
                    message_index=$(( (message_index + 1) % ${#MOTIVATIONAL_MESSAGES[@]} ))
                fi
            fi
        done
        play_work_sound
        clear
        center_text "Work session $session_count complete!"
        sleep 2

        # Break session
        if [ $session_count -eq $SESSIONS_BEFORE_LONG_BREAK ]; then
            seconds=$((LONG_BREAK_DURATION * 60))
            session_count=0
            timer_type="Long Break"
        else
            seconds=$((break_duration * 60))
            timer_type="Short Break"
        fi
        while [ $seconds -gt 0 ]; do
            display_timer $((seconds / 60)) $((seconds % 60)) "Break" $session_count "$timer_type" $message_index
            read -t 1 -n 1 -s key
            case $key in
                p|P) 
                    paused=$((1 - paused))
                    if [ $paused -eq 1 ]; then
                        display_timer $((seconds / 60)) $((seconds % 60)) "Paused" $session_count "$timer_type" $message_index
                        while [ $paused -eq 1 ]; do
                            read -n 1 -s key
                            case $key in
                                p|P) paused=0 ;;
                                r|R) seconds=$((break_duration * 60)); paused=0 ;;
                                q|Q) clear; exit 0 ;;
                            esac
                        done
                    fi
                    ;;
                r|R) seconds=$((break_duration * 60)) ;;
                q|Q) clear; exit 0 ;;
            esac
            if [ $paused -eq 0 ]; then
                ((seconds--))
                if [ $((seconds % 60)) -eq 0 ]; then
                    message_index=$(( (message_index + 1) % ${#MOTIVATIONAL_MESSAGES[@]} ))
                fi
            fi
        done
        play_break_sound
        clear
        center_text "$timer_type complete!"
        sleep 2
    done
}

clear
set_timer_durations

if [ "$1" = "--test" ]; then
    pomodoro "test"
else
    pomodoro "normal"
fi
