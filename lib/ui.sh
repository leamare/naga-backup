draw_progress_bar() {
    local current=$1
    local total=$2
    local width=$(tput cols)
    local bar_width=$((width - 30))

    local percent=$((current * 100 / total))
    local filled=$((bar_width * current / total))
    local empty=$((bar_width - filled))

    printf "\r["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s." $(seq 1 $empty)
    printf "] %3d%%" "$percent"
}
