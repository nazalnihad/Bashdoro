#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOUNDS_DIR="$SCRIPT_DIR/sounds"

if ! command -v figlet >/dev/null 2>&1; then
    echo "Error: figlet required. Install with: sudo pacman -S figlet (Arch Linux)"
    exit 1
fi

# Check for audio support (prefer basic CLI players that don't spawn windows)
AUDIO_CMD=""
if command -v paplay >/dev/null 2>&1; then
    AUDIO_CMD="paplay"
elif command -v aplay >/dev/null 2>&1; then
    AUDIO_CMD="aplay"
elif command -v mpg123 >/dev/null 2>&1; then
    AUDIO_CMD="mpg123"
fi

# Colors
if command -v tput >/dev/null 2>&1 && [ "$(tput colors)" -gt 0 ]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    MAGENTA=$(tput setaf 5)
    BLUE=$(tput setaf 4)
    NC=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" CYAN="" MAGENTA="" BLUE="" NC=""
fi

# Global variables
MUSIC_MUTED=0
MUSIC_PID=""
LAST_COLS=0
LAST_LINES=0
RESIZED=0
STATUS_ROW=0
MESSAGE_ROW=0
TIMER_ROW_START=0
TIMER_ROW_LINES=0
MUSIC_SHOULD_RESUME=0
TIMER_PAUSED=0

# Messages
MOTIVATIONAL_MESSAGES=("Keep pushing forward!" "You're doing great!" "Stay focused, you got this!" "One step at a time!" "Great work, keep it up!")


# Play sound file helper (choose the simplest, non-GUI player)
play_sound_file() {
    local sound_file="$1"
    [ ! -f "$sound_file" ] && return

    local ext="${sound_file##*.}"

    if [ "$ext" = "mp3" ]; then
        if command -v mpg123 >/dev/null 2>&1; then
            nohup mpg123 -q "$sound_file" </dev/null >/dev/null 2>&1 &
        elif command -v paplay >/dev/null 2>&1; then
            # Some paplay builds handle mp3 via PulseAudio modules; try anyway
            nohup paplay "$sound_file" </dev/null >/dev/null 2>&1 &
        elif command -v aplay >/dev/null 2>&1; then
            # aplay doesn't play mp3; skip silently
            :
        fi
    else
        # Assume WAV or other raw format
        if command -v paplay >/dev/null 2>&1; then
            nohup paplay "$sound_file" </dev/null >/dev/null 2>&1 &
        elif command -v aplay >/dev/null 2>&1; then
            nohup aplay -q "$sound_file" </dev/null >/dev/null 2>&1 &
        elif command -v mpg123 >/dev/null 2>&1; then
            # mpg123 won't play wav; skip
            :
        fi
    fi
}

play_start_sound() {
    # Temporarily pause background music if playing (so sound effect is clear)
    if [ $MUSIC_MUTED -eq 0 ] && [ -n "$MUSIC_PID" ]; then
        stop_background_music
        MUSIC_SHOULD_RESUME=1
    fi
    if [ -f "$SOUNDS_DIR/start.wav" ]; then
        play_sound_file "$SOUNDS_DIR/start.wav"
    elif [ -f "$SOUNDS_DIR/start.mp3" ]; then
        play_sound_file "$SOUNDS_DIR/start.mp3"
    else
        for ((i=0; i<3; i++)); do printf "\a"; sleep 0.1; done
    fi
    # Resume music if it was playing
    if [ $MUSIC_SHOULD_RESUME -eq 1 ] && [ $MUSIC_MUTED -eq 0 ]; then
        play_background_music
        MUSIC_SHOULD_RESUME=0
    fi
}

play_stop_sound() {
    if [ $MUSIC_MUTED -eq 0 ] && [ -n "$MUSIC_PID" ]; then
        stop_background_music
        MUSIC_SHOULD_RESUME=1
    fi
    if [ -f "$SOUNDS_DIR/stop.wav" ]; then
        play_sound_file "$SOUNDS_DIR/stop.wav"
    elif [ -f "$SOUNDS_DIR/stop.mp3" ]; then
        play_sound_file "$SOUNDS_DIR/stop.mp3"
    else
        for ((i=0; i<3; i++)); do printf "\a"; sleep 0.15; done
    fi
    if [ $MUSIC_SHOULD_RESUME -eq 1 ] && [ $MUSIC_MUTED -eq 0 ]; then
        play_background_music
        MUSIC_SHOULD_RESUME=0
    fi
}

play_background_music() {
    stop_background_music
    
    if [ "$MUSIC_MUTED" -eq 0 ]; then
        # Look for ambience file
        local ambience_file=""
        if [ -f "$SOUNDS_DIR/ambience.mp3" ]; then
            ambience_file="$SOUNDS_DIR/ambience.mp3"
        elif [ -f "$SOUNDS_DIR/ambience.wav" ]; then
            ambience_file="$SOUNDS_DIR/ambience.wav"
        elif [ -f "$SOUNDS_DIR/background.mp3" ]; then
            ambience_file="$SOUNDS_DIR/background.mp3"
        elif [ -f "$SOUNDS_DIR/background.wav" ]; then
            ambience_file="$SOUNDS_DIR/background.wav"
        fi

        [ -z "$ambience_file" ] && return

        local ext="${ambience_file##*.}"
        if [ "$ext" = "mp3" ] && command -v mpg123 >/dev/null 2>&1; then
            nohup mpg123 -q --loop -1 "$ambience_file" </dev/null >/dev/null 2>&1 &
            MUSIC_PID=$!
        elif [ "$ext" != "mp3" ] && command -v paplay >/dev/null 2>&1; then
            (
                trap 'exit 0' TERM INT
                while true; do
                    paplay "$ambience_file" 2>/dev/null || exit 0
                    sleep 0.05
                done
            ) </dev/null >/dev/null 2>&1 &
            MUSIC_PID=$!
        elif [ "$ext" != "mp3" ] && command -v aplay >/dev/null 2>&1; then
            (
                trap 'exit 0' TERM INT
                while true; do
                    aplay -q "$ambience_file" 2>/dev/null || exit 0
                    sleep 0.05
                done
            ) </dev/null >/dev/null 2>&1 &
            MUSIC_PID=$!
        else
            # No suitable player for this filetype
            MUSIC_PID=""
        fi
    fi
}

stop_background_music() {
    if [ -n "$MUSIC_PID" ] && [ "$MUSIC_PID" != "0" ]; then
        kill -TERM "$MUSIC_PID" 2>/dev/null
        sleep 0.02
        kill -KILL "$MUSIC_PID" 2>/dev/null
        wait "$MUSIC_PID" 2>/dev/null
        MUSIC_PID=""
    fi
    # Best-effort cleanup for loops
    pkill -f "mpg123.*ambience" 2>/dev/null
    pkill -f "mpg123.*background" 2>/dev/null
    pkill -f "paplay.*ambience" 2>/dev/null
    pkill -f "paplay.*background" 2>/dev/null
    pkill -f "aplay.*ambience" 2>/dev/null
    pkill -f "aplay.*background" 2>/dev/null
}

## Remove legacy duplicated sound functions referencing /tmp (cleaned)

toggle_background_music() {
    if [ "$MUSIC_MUTED" -eq 0 ]; then
        MUSIC_MUTED=1
        stop_background_music
    else
        MUSIC_MUTED=0
        if [ $TIMER_PAUSED -eq 0 ]; then
            play_background_music
        else
            MUSIC_SHOULD_RESUME=1
        fi
    fi
}
 
print_centered() {
    local text="$1" color="$2"
    local width=$(tput cols)
    # Ensure minimum width
    [ "$width" -lt 50 ] && width=50
    while IFS= read -r line; do
        local line_len=${#line}
        local padding=$(( (width - line_len) / 2 ))
        [ "$padding" -lt 0 ] && padding=0
        printf "%${padding}s${color}%s${NC}\n" "" "$line"
    done <<< "$text"
}

# Detect terminal size changes
has_terminal_resized() {
    local cols=$(tput cols)
    local lines=$(tput lines)
    if [ "$cols" -ne "$LAST_COLS" ] || [ "$lines" -ne "$LAST_LINES" ]; then
        LAST_COLS=$cols
        LAST_LINES=$lines
        return 0
    fi
    return 1
}

display_timer() {
    # Full UI render (stores rows for incremental updates)
    local minutes=$1 seconds=$2 status=$3 session=$4 type=$5 msg_idx=$6
    local time_str=$(printf "%02d:%02d" $minutes $seconds)
    local term_width=$(tput cols)
    local term_height=$(tput lines)

    local figlet_font="standard"
    if [ "$term_width" -ge 80 ]; then figlet_font="big"; elif [ "$term_width" -ge 60 ]; then figlet_font="standard"; else figlet_font="small"; fi
    local ascii=$(figlet -f "$figlet_font" -w "$term_width" "$time_str" 2>/dev/null)
    [ -z "$ascii" ] && ascii=$(figlet -f standard "$time_str" 2>/dev/null)

    local ascii_height=$(echo "$ascii" | wc -l)
    local ui_height=$((ascii_height + 15))
    local top_pad=$(( (term_height - ui_height) / 2 ))
    [ "$top_pad" -lt 0 ] && top_pad=0

    local type_text="Bashdoro: $type"
    local session_text="Session $session of $SESSIONS_BEFORE_LONG_BREAK"
    local music_status
    if [ $MUSIC_MUTED -eq 1 ]; then
        music_status="Muted"
    elif [ $TIMER_PAUSED -eq 1 ]; then
        music_status="Paused"
    else
        music_status="Playing"
    fi
    local control_text="P: Pause | R: Restart | M: Music $music_status | Q: Quit"

    local needed_width=${#control_text}
    [ ${#type_text} -gt $needed_width ] && needed_width=${#type_text}
    [ ${#session_text} -gt $needed_width ] && needed_width=${#session_text}
    needed_width=$((needed_width + 4))
    [ "$needed_width" -gt "$((term_width - 4))" ] && needed_width=$((term_width - 4))
    [ "$needed_width" -lt 40 ] && needed_width=40
    local border_width=$((needed_width - 2))
    local border_line=$(printf '━%.0s' $(seq 1 $border_width))

    clear

    CUR_ROW=0
    for ((i=0; i<top_pad; i++)); do echo; ((CUR_ROW++)); done
    print_centered "┏${border_line}┓" "$CYAN"; ((CUR_ROW++))
    local type_padded=$(printf "%-${border_width}s" "  $type_text")
    print_centered "┃${type_padded}┃" "$CYAN"; ((CUR_ROW++))
    print_centered "┗${border_line}┛" "$CYAN"; ((CUR_ROW++))
    echo; ((CUR_ROW++))
    print_centered "$session_text" "$RED"; ((CUR_ROW++))
    echo; ((CUR_ROW++))
    STATUS_ROW=$CUR_ROW
    print_centered "$status" "$YELLOW"; ((CUR_ROW++))
    echo; ((CUR_ROW++))
    MESSAGE_ROW=$CUR_ROW
    print_centered "${MOTIVATIONAL_MESSAGES[$msg_idx]}" "$MAGENTA"; ((CUR_ROW++))
    echo; ((CUR_ROW++))
    TIMER_ROW_START=$CUR_ROW
    while IFS= read -r line; do
        print_centered "$line" "$GREEN"; ((CUR_ROW++))
    done <<< "$ascii"
    TIMER_ROW_LINES=$ascii_height
    echo; ((CUR_ROW++))
    print_centered "┏${border_line}┓" "$CYAN"; ((CUR_ROW++))
    local control_padded=$(printf "%-${border_width}s" "  $control_text")
    print_centered "┃${control_padded}┃" "$CYAN"; ((CUR_ROW++))
    print_centered "┗${border_line}┛" "$CYAN"; ((CUR_ROW++))
    echo; ((CUR_ROW++))
    tput ed
}

update_timer() {
    # Incremental redraw: status + message + ascii timer only (no clear)
    local minutes=$1 seconds=$2 status=$3 msg_idx=$4
    local term_width=$(tput cols)
    local figlet_font="standard"
    if [ "$term_width" -ge 80 ]; then figlet_font="big"; elif [ "$term_width" -ge 60 ]; then figlet_font="standard"; else figlet_font="small"; fi
    local time_str=$(printf "%02d:%02d" $minutes $seconds)
    local ascii=$(figlet -f "$figlet_font" -w "$term_width" "$time_str" 2>/dev/null)
    [ -z "$ascii" ] && ascii=$(figlet -f standard "$time_str" 2>/dev/null)

    # Determine music status for incremental footer display if needed later (unused now)
    local music_status
    if [ $MUSIC_MUTED -eq 1 ]; then music_status="Muted"; elif [ $TIMER_PAUSED -eq 1 ]; then music_status="Paused"; else music_status="Playing"; fi

    # Overwrite status line
    tput cup $STATUS_ROW 0; printf "%$(tput cols)s" ""; tput cup $STATUS_ROW 0
    print_centered "$status" "$YELLOW"

    # Overwrite message line (rotated per minute externally)
    tput cup $MESSAGE_ROW 0; printf "%$(tput cols)s" ""; tput cup $MESSAGE_ROW 0
    print_centered "${MOTIVATIONAL_MESSAGES[$msg_idx]}" "$MAGENTA"

    # Overwrite timer ascii block
    local row=$TIMER_ROW_START
    while IFS= read -r line; do
        tput cup $row 0; printf "%$(tput cols)s" ""; tput cup $row 0
        print_centered "$line" "$GREEN"
        ((row++))
    done <<< "$ascii"
}

play_work_sound() {
    play_start_sound
}

play_break_sound() {
    play_stop_sound
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
    echo "${CYAN}Welcome to Bashdoro!${NC}"
    echo
    echo "1) 25 min work / 5 min break (default)"
    echo "2) 50 min work / 10 min break"
    echo "3) Custom durations"
    echo
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
    
    # Ask about background music
    echo
    echo -n "Enable background music (rain sounds)? (y/N): "
    read music_choice
    if [ "$music_choice" = "y" ] || [ "$music_choice" = "Y" ]; then
        MUSIC_MUTED=0
        echo "${GREEN}Background music enabled. Press 'M' during timer to toggle.${NC}"
    else
        MUSIC_MUTED=1
        echo "${YELLOW}Background music disabled. Press 'M' during timer to enable.${NC}"
    fi
    sleep 1
    clear
}

pomodoro() {
    local test_mode=$1
    local session_count=0 paused=0 msg_idx=0 state="work"
    local work_duration=$WORK_DURATION break_duration=$BREAK_DURATION long_break_duration=$LONG_BREAK_DURATION

    [ "$test_mode" = "test" ] && work_duration=1 && break_duration=1 && long_break_duration=1

    # Initialize terminal size tracking
    LAST_COLS=$(tput cols)
    LAST_LINES=$(tput lines)
    
    tput civis
    stty -echo
    trap 'tput cnorm; stty echo; stop_background_music; clear' EXIT INT TERM
    trap 'RESIZED=1' WINCH
    
    # Start background music if enabled
    play_background_music

    while true; do
        local seconds duration type status msg
        case $state in
            work)
                ((session_count++))
                duration=$((work_duration * 60))
                type="Pomodoro"
                status="Working"
                msg="Work complete!"
                play_start_sound
                ;;
            short_break)
                duration=$((break_duration * 60))
                type="Short Break"
                status="Break"
                msg="Break done!"
                play_stop_sound
                ;;
            long_break)
                duration=$((long_break_duration * 60))
                session_count=0
                type="Long Break"
                status="Break"
                msg="Break done!"
                play_stop_sound
                ;;
        esac
        seconds=$duration
        local last_update=$(date +%s)
        local last_second=$seconds
        display_timer $((seconds/60)) $((seconds%60)) "$status" $session_count "$type" $msg_idx

        while [ $seconds -gt 0 ]; do
            key=$(read_key 0.05)
            case $key in
                p|P)
                    paused=$((1 - paused))
                    if [ $paused -eq 1 ]; then
                        TIMER_PAUSED=1
                        # Pause background music (resume later)
                        if [ $MUSIC_MUTED -eq 0 ] && [ -n "$MUSIC_PID" ]; then
                            MUSIC_SHOULD_RESUME=1
                            stop_background_music
                        fi
                        display_timer $((seconds/60)) $((seconds%60)) "⏸ Paused" $session_count "$type" $msg_idx
                        while [ $paused -eq 1 ]; do
                            key=$(read_key 0.1)
                            [ "$RESIZED" = "1" ] && display_timer $((seconds/60)) $((seconds%60)) "⏸ Paused" $session_count "$type" $msg_idx && RESIZED=0
                            case $key in
                                p|P) paused=0; TIMER_PAUSED=0; 
                                     # Resume music if needed and unmuted
                                     if [ $MUSIC_SHOULD_RESUME -eq 1 ] && [ $MUSIC_MUTED -eq 0 ]; then
                                         play_background_music; MUSIC_SHOULD_RESUME=0; 
                                     fi
                                     display_timer $((seconds/60)) $((seconds%60)) "$status" $session_count "$type" $msg_idx ;;
                                r|R) seconds=$duration; paused=0; display_timer $((seconds/60)) $((seconds%60)) "$status" $session_count "$type" $msg_idx ;;
                                m|M) toggle_background_music; display_timer $((seconds/60)) $((seconds%60)) "⏸ Paused" $session_count "$type" $msg_idx ;;
                                q|Q) clear; exit 0 ;;
                                *) ;;
                            esac
                        done
                        last_update=$(date +%s)
                        last_second=$seconds
                    fi
                    ;;
                r|R) seconds=$duration; last_update=$(date +%s); last_second=$seconds; display_timer $((seconds/60)) $((seconds%60)) "$status" $session_count "$type" $msg_idx ;;
                m|M) toggle_background_music; display_timer $((seconds/60)) $((seconds%60)) "$status" $session_count "$type" $msg_idx ;;
                q|Q) clear; exit 0 ;;
                *) ;;
            esac

            # Resize handling
            if [ "$RESIZED" = "1" ]; then
                display_timer $((seconds/60)) $((seconds%60)) "$status" $session_count "$type" $msg_idx
                RESIZED=0
            fi

            # Tick
            local current_time=$(date +%s)
            if [ $paused -eq 0 ] && [ $((current_time - last_update)) -ge 1 ]; then
                ((seconds--))
                last_update=$current_time
                if [ $((seconds % 60)) -eq 0 ]; then
                    msg_idx=$(( (msg_idx + 1) % ${#MOTIVATIONAL_MESSAGES[@]} ))
                fi
                update_timer $((seconds/60)) $((seconds%60)) "$status" $msg_idx
            fi
        done

        [ "$state" = "work" ] && play_work_sound || play_break_sound
        clear
        
        # Choose figlet font based on terminal width for completion message
        local term_width=$(tput cols)
        local msg_font="standard"
        [ "$term_width" -ge 80 ] && msg_font="big"
        
        print_centered "$(figlet -f "$msg_font" -w "$term_width" "$msg" 2>/dev/null || figlet "$msg")" "$CYAN"
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
echo "${CYAN}╔════════════════════════════════════════╗${NC}"
echo "${CYAN}║         Welcome to Bashdoro!          ║${NC}"
echo "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

# Check for sounds directory
if [ ! -d "$SOUNDS_DIR" ]; then
    echo "${YELLOW}Creating sounds directory: $SOUNDS_DIR${NC}"
    mkdir -p "$SOUNDS_DIR"
fi

# Check for audio player
if [ -z "$AUDIO_CMD" ]; then
    echo "${YELLOW}⚠ No audio player found!${NC}"
    echo "${YELLOW}For sound support, install one of:${NC}"
    echo "  - ffplay:  ${CYAN}sudo pacman -S ffmpeg${NC}"
    echo "  - mpg123:  ${CYAN}sudo pacman -S mpg123${NC}"
    echo "  - paplay:  (usually pre-installed with PulseAudio)"
    echo
else
    echo "${GREEN}✓ Audio player found: $AUDIO_CMD${NC}"
fi

# Check for ambience file
if [ -f "$SOUNDS_DIR/ambience.mp3" ] || [ -f "$SOUNDS_DIR/ambience.wav" ]; then
    echo "${GREEN}✓ Background music found!${NC}"
else
    echo "${YELLOW}⚠ No background music found${NC}"
    echo "  Add your music file as: ${CYAN}$SOUNDS_DIR/ambience.mp3${NC}"
fi

# Check for custom sounds
if [ -f "$SOUNDS_DIR/start.wav" ] || [ -f "$SOUNDS_DIR/start.mp3" ]; then
    echo "${GREEN}✓ Custom start sound found${NC}"
fi

if [ -f "$SOUNDS_DIR/stop.wav" ] || [ -f "$SOUNDS_DIR/stop.mp3" ]; then
    echo "${GREEN}✓ Custom stop sound found${NC}"
fi

echo
sleep 2

set_timer_durations
[ "$1" = "--test" ] && pomodoro "test" || pomodoro "normal"