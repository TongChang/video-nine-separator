#!/bin/bash
set -e

# 現在の日時を取得してファイル名を生成
current_datetime=$(date "+%Y%m%d%H%M%S")
output_filename="output_${current_datetime}.mp4"

# 入力ファイルのパターンを指定
input_pattern="/app/input/*.mp4"

# 入力ファイルを配列に格納
input_files=(${input_pattern})

# 入力ファイルの数をチェック
if [ ${#input_files[@]} -ne 9 ]; then
    echo "エラー: 9つの入力ファイルが必要です。見つかったファイル数: ${#input_files[@]}"
    ls -l /app/input
    exit 1
fi

# 最長の動画の長さを取得
max_duration=0
for file in "${input_files[@]}"; do
    duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file")
    duration=${duration%.*} # 小数点以下を切り捨て
    if ((duration > max_duration)); then
        max_duration=$duration
    fi
done

echo "最長の動画の長さ: ${max_duration}秒"

# FFmpegコマンドを構築
ffmpeg_command="ffmpeg"
for file in "${input_files[@]}"; do
    ffmpeg_command+=" -i \"$file\""
done

filter_complex="nullsrc=size=1080x1920:d=${max_duration} [base];"
for i in {0..8}; do
    filter_complex+="[$i:v] setpts=PTS-STARTPTS, scale=360x640, pad=width=360:height=640:color=black, loop=loop=-1:size=${max_duration}*30:start=0 [video$i];"
done

overlay_positions=("0:0" "360:0" "720:0" "0:640" "360:640" "720:640" "0:1280" "360:1280" "720:1280")
tmp_name="tmp1"
filter_complex+="[base][video0] overlay=shortest=0:x=${overlay_positions[0]%:*}:y=${overlay_positions[0]#*:} [$tmp_name];"

for i in {1..8}; do
    next_tmp=$([[ $i -eq 8 ]] && echo "outv" || echo "tmp$((i + 1))")
    filter_complex+="[$tmp_name][video$i] overlay=shortest=0:x=${overlay_positions[$i]%:*}:y=${overlay_positions[$i]#*:} [$next_tmp];"
    tmp_name=$next_tmp
done

ffmpeg_command+=" -filter_complex \"${filter_complex%?}\""
ffmpeg_command+=" -map \"[outv]\" -map 0:a -c:v libx264 -preset fast -crf 23 -c:a aac -t ${max_duration} \"/app/output/${output_filename}\""

# FFmpegコマンドを実行
echo "FFmpegコマンドを実行中..."
echo "コマンド: $ffmpeg_command"
eval $ffmpeg_command

echo "処理が完了しました。出力ファイル: /app/output/${output_filename}"
