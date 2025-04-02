#!/bin/bash
set -e 

if [ -z "$IMAGE_TAG" ]; then
  echo "Ошибка: Переменная окружения IMAGE_TAG не установлена."
  exit 1
fi


if [ -z "$URL_AVITO" ]; then echo "Ошибка: URL_AVITO не установлена."; exit 1; fi
if [ -z "$CHAT_ID_TG" ]; then echo "Ошибка: CHAT_ID_TG не установлена."; exit 1; fi
if [ -z "$TG_TOKEN" ]; then echo "Ошибка: TG_TOKEN не установлена."; exit 1; fi

CONTAINER_NAME_TEST="avito-parser-test-${GITHUB_RUN_ID:-local}"
ENV_FILE_TEST=".env.test"
FOUND_AD_PATTERN_TEST="F6"
TIMEOUT_SECONDS_TEST=300
CHECK_INTERVAL_TEST=10

echo "Создание файла $ENV_FILE_TEST..."
{
  echo "URL_AVITO=$URL_AVITO"
  echo "CHAT_ID_TG=$CHAT_ID_TG_TEST"
  echo "TG_TOKEN=$TG_TOKEN_TEST"
  echo "NUM_ADS_AVITO=5"
  echo "FREQ_AVITO=$FREQ_AVITO"
  echo "KEYS_AVITO=$KEYS_AVITO"
  echo "MAX_PRICE_AVITO=$MAX_PRICE_AVITO"
  echo "MIN_PRICE_AVITO=$MIN_PRICE_AVITO"
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
trap cleanup EXIT

echo "Запуск контейнера $CONTAINER_NAME_TEST из образа $IMAGE_TAG..."
if [ ! -f "$ENV_FILE_TEST" ]; then
    echo "Ошибка: Файл $ENV_FILE_TEST не найден!"
    exit 1
fi
docker run -d --name "$CONTAINER_NAME_TEST" --env-file "$ENV_FILE_TEST" "$IMAGE_TAG"

echo "Ожидание до $TIMEOUT_SECONDS_TEST секунд появления '$FOUND_AD_PATTERN_TEST' в логах контейнера $CONTAINER_NAME_TEST..."
SECONDS=0
SUCCESS=false
while [ $SECONDS -lt $TIMEOUT_SECONDS_TEST ]; do
  # Проверяем, жив ли контейнер
  if ! docker ps -q -f name="^/${CONTAINER_NAME_TEST}$" > /dev/null; then
    echo "Ошибка: Контейнер $CONTAINER_NAME_TEST неожиданно остановился."
    echo "--- Логи контейнера ---"
    docker logs "$CONTAINER_NAME_TEST" # Не подавляем вывод ошибок, если логи недоступны
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
  docker logs "$CONTAINER_NAME_TEST" # Не подавляем вывод ошибок, если логи недоступны
  echo "----------------------"
  exit 1 # Выходим с ошибкой, если таймаут
fi

# Явный выход с кодом 0 при успехе (хотя set -e позаботится об ошибках)
echo "Тест успешно пройден."
exit 0