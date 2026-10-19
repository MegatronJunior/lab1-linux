#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Использование: $0 <log_file> <search_word>" >&2
    exit 1
fi

log_file="$1"
search_word="$2"

if [ ! -f "$log_file" ]; then
    echo "Ошибка: файл '$log_file' не существует." >&2
    exit 1
fi

if [ -z "$search_word" ]; then
    echo "Ошибка: поисковое слово не может быть пустым." >&2
    exit 1
fi

echo "Файл: $log_file"
echo "Искомое слово: $search_word"

matches_file="log_matches.txt"
count_file="log_count.txt"

grep -F -- "$search_word" "$log_file" > "$matches_file" || [ "$?" -eq 1 ]

wc -l < "$matches_file" > "$count_file"

echo "Найденные строки сохранены в $matches_file"
echo "Количество совпадений сохранено в $count_file"
