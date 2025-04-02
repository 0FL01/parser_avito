#!/bin/bash
set -e # Выходить немедленно, если команда завершается с ненулевым статусом

# Проверяем, передана ли переменная IMAGE_TAG
if [ -z "$IMAGE_TAG" ]; then
  echo "Ошибка: Переменная окружения IMAGE_TAG не установлена."
  exit 1
fi

# Проверяем наличие необходимых секретов (пример)
# Эти переменные используются для создания .env.test файла,
# поэтому их имена остаются оригинальными на входе скрипта.
if [ -z "$URL_AVITO" ]; then echo "Ошибка: URL_AVITO не установлена."; exit 1; fi
if [ -z "$CHAT_ID_TG" ]; then echo "Ошибка: CHAT_ID_TG не установлена."; exit 1; fi
if [ -z "$TG_TOKEN" ]; then echo "Ошибка: TG_TOKEN не установлена."; exit 1; fi
# ... добавьте проверки для остальных критичных переменных ...

# Переменные для тестового окружения с суффиксом _TEST
CONTAINER_NAME_TEST="avito-parser-test-${GITHUB_RUN_ID:-local}" # Добавляем дефолтное значение для локального запуска
ENV_FILE_TEST=".env.test"
# Паттерн для поиска УСПЕШНОГО сообщения в логах
FOUND_AD_PATTERN_TEST="SUCCESS | __main__:__pretty_log"
TIMEOUT_SECONDS_TEST=400
CHECK_INTERVAL_TEST=10

echo "Создание файла $ENV_FILE_TEST..."
# Используем переменные окружения, переданные скрипту,
# но записываем их в файл с суффиксом _TEST
{
  echo "URL_AVITO_TEST=$URL_AVITO"
  echo "CHAT_ID_TG_TEST=$CHAT_ID_TG"
  echo "TG_TOKEN=$TG_TOKEN"
  echo "NUM_ADS_AVITO=$NUM_ADS_AVITO"
  echo "FREQ_AVITO=$FREQ_AVITO"
  echo "KEYS_AVITO_TEST=$KEYS_AVITO"
  echo "MAX_PRICE_AVITO_TEST=$MAX_PRICE_AVITO"
  echo "MIN_PRICE_AVITO_TEST=$MIN_PRICE_AVITO"
  echo "GEO_AVITO=$GEO_AVITO"
  echo "PROXY_AVITO=$PROXY_AVITO"
  echo "PROXY_CHANGE_IP_AVITO=$PROXY_CHANGE_IP_AVITO"
  echo "NEED_MORE_INFO_AVITO=$NEED_MORE_INFO_AVITO"
  echo "DEBUG_MODE_AVITO=$DEBUG_MODE_AVITO"
  echo "FAST_SPEED_AVITO=$FAST_SPEED_AVITO"
  echo "KEYS_BLACK_AVITO=$KEYS_BLACK_AVITO"
  echo "MAX_VIEW_AVITO=$MAX_VIEW_AVITO"
} > "$ENV_FILE_TEST"
echo "Файл $ENV_FILE_TEST создан."

cleanup() {
  echo "Очистка тестового контейнера $CONTAINER_NAME_TEST..."
  docker stop "$CONTAINER_NAME_TEST" || echo "Контейнер $CONTAINER_NAME_TEST не был запущен."
  docker rm "$CONTAINER_NAME_TEST" || echo "Контейнер $CONTAINER_NAME_TEST не удалось удалить (возможно, уже удален)."
  rm -f "$ENV_FILE_TEST"
  echo "Очистка завершена."
}
trap cleanup EXIT # Выполнить cleanup при выходе из скрипта (успешном или с ошибкой)

echo "Запуск контейнера $CONTAINER_NAME_TEST из образа $IMAGE_TAG..."
# Убедимся, что файл .env.test существует перед его использованием
if [ ! -f "$ENV_FILE_TEST" ]; then
    echo "Ошибка: Файл $ENV_FILE_TEST не найден!"
    exit 1
fi
# Запускаем контейнер в фоновом режиме (-d) с именем и файлом переменных окружения
docker run -d --name "$CONTAINER_NAME_TEST" --env-file "$ENV_FILE_TEST" "$IMAGE_TAG"

echo "Ожидание до $TIMEOUT_SECONDS_TEST секунд появления '$FOUND_AD_PATTERN_TEST' в логах контейнера $CONTAINER_NAME_TEST..."
SECONDS=0
SUCCESS=false
while [ $SECONDS -lt $TIMEOUT_SECONDS_TEST ]; do
  # Проверяем, запущен ли контейнер
  if ! docker ps -q -f name="^/${CONTAINER_NAME_TEST}$"; then
    echo "Ошибка: Контейнер $CONTAINER_NAME_TEST неожиданно остановился."
    echo "--- Логи контейнера ---"
    docker logs "$CONTAINER_NAME_TEST" || echo "Не удалось получить логи остановленного контейнера."
    echo "----------------------"
    exit 1 # Выходим с ошибкой, если контейнер упал
  fi

  # Ищем ТОЛЬКО паттерн успешного нахождения объявления в логах
  # grep -q вернет 0 (true в bash), если найдет совпадение
  if docker logs "$CONTAINER_NAME_TEST" 2>&1 | grep -q "$FOUND_AD_PATTERN_TEST"; then
    echo "Успех: Паттерн '$FOUND_AD_PATTERN_TEST' найден в логах."
    echo "--- Логи контейнера (последние 20 строк) ---"
    docker logs "$CONTAINER_NAME_TEST" | tail -n 20
    echo "------------------------------------------"
    SUCCESS=true
    break # Выходим из цикла при успехе
  fi

  sleep $CHECK_INTERVAL_TEST
  SECONDS=$((SECONDS + CHECK_INTERVAL_TEST))
  echo "Все еще ожидаем... (${SECONDS}/${TIMEOUT_SECONDS_TEST} секунд)"
done

# Проверяем результат после цикла
if [ "$SUCCESS" = false ]; then
  echo "Ошибка: Таймаут ($TIMEOUT_SECONDS_TEST секунд) достигнут во время ожидания '$FOUND_AD_PATTERN_TEST'."
  echo "--- Логи контейнера ---"
  docker logs "$CONTAINER_NAME_TEST" || echo "Не удалось получить логи работающего контейнера."
  echo "----------------------"
  exit 1 # Выходим с ошибкой, если таймаут
fi

# Явный выход с кодом 0 при успехе (хотя set -e позаботится об ошибках)
echo "Тест успешно пройден."
exit 0