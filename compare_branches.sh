#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <repo_url> <branch1> <branch2>" >&2
    exit 1
fi

repo_url="$1"
branch1="$2"
branch2="$3"

echo "Repository: $repo_url"
echo "Branch 1: $branch1"
echo "Branch 2: $branch2"

temp_dir="$(mktemp -d)"

trap 'rm -rf -- "$temp_dir"' EXIT
git init -q "$temp_dir"

if ! git -C "$temp_dir" fetch -q --depth=1 --filter=blob:none --no-tags \
    "$repo_url" \
    "refs/heads/$branch1:refs/heads/compare-first" \
    "refs/heads/$branch2:refs/heads/compare-second"; then

    echo "Ошибка: не удалось загрузить ветки. Проверьте URL репозитория и названия веток." >&2
    exit 1
fi

diff_file="$temp_dir/diff.txt"

git --no-pager -C "$temp_dir" diff --name-status --no-renames \
    compare-first compare-second > "$diff_file"

report_file="diff_report_${branch1}_vs_${branch2}.txt"

{
    echo "Отчет о различиях между ветками"
    echo "================================"
    echo "Репозиторий: $repo_url"
    echo "Ветка 1: $branch1"
    echo "Ветка 2: $branch2"
    echo "Дата генерации: $(date '+%d.%m.%Y %H:%M:%S')"
    echo "================================"
    echo
    echo "СПИСОК ИЗМЕНЕННЫХ ФАЙЛОВ:"

    cat "$diff_file"

    echo
    echo "СТАТИСТИКА:"

    awk '
        $1 == "A" { added++ }
        $1 == "D" { deleted++ }
        $1 == "M" { modified++ }
        NF > 0 { total++ }
        END {
            printf "Всего измененных файлов: %d\n", total
            printf "Добавлено (A): %d\n", added
            printf "Удалено (D): %d\n", deleted
            printf "Изменено (M): %d\n", modified
        }
    ' "$diff_file"

} > "$report_file"


echo "Отчет сохранен: $report_file"
