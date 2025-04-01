#!/bin/bash
set -e # Выходить немедленно, если команда завершается с ненулевым статусом

# Проверяем, передана ли переменная IMAGE_TAG
if [ -z "$IMAGE_TAG" ]; then
  echo "Error: IMAGE_TAG environment variable is not set."
  exit 1
fi

# Проверяем наличие необходимых секретов (пример)
if [ -z "$URL_AVITO" ]; then echo "Error: URL_AVITO is not set."; exit 1; fi
if [ -z "$CHAT_ID_TG" ]; then echo "Error: CHAT_ID_TG is not set."; exit 1; fi
if [ -z "$TG_TOKEN" ]; then echo "Error: TG_TOKEN is not set."; exit 1; fi
# ... добавьте проверки для остальных критичных переменных ...

CONTAINER_NAME="avito-parser-test-${GITHUB_RUN_ID:-local}" # Добавляем дефолтное значение для локального запуска
ENV_FILE=".env.test"
PARSING_COMPLETE_PATTERN="Парсинг завершен"
FOUND_AD_PATTERN="SUCCESS | __main__:__pretty_log"
TIMEOUT_SECONDS=400
CHECK_INTERVAL=10

echo "Creating $ENV_FILE..."
# Используем переменные окружения, переданные скрипту
{
  echo "URL_AVITO=$URL_AVITO"
  echo "CHAT_ID_TG=$CHAT_ID_TG"
  echo "TG_TOKEN=$TG_TOKEN"
  echo "NUM_ADS_AVITO=$NUM_ADS_AVITO"
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
} > "$ENV_FILE"
echo "$ENV_FILE created."

cleanup() {
  echo "Cleaning up test container $CONTAINER_NAME..."
  docker stop "$CONTAINER_NAME" || echo "Container $CONTAINER_NAME was not running."
  docker rm "$CONTAINER_NAME" || echo "Container $CONTAINER_NAME could not be removed (may already be gone)."
  rm -f "$ENV_FILE"
  echo "Cleanup finished."
}
trap cleanup EXIT # Выполнить cleanup при выходе из скрипта (успешном или с ошибкой)

echo "Starting container $CONTAINER_NAME from image $IMAGE_TAG..."
# Убедимся, что файл .env существует перед его использованием
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found!"
    exit 1
fi
docker run -d --name "$CONTAINER_NAME" --env-file "$ENV_FILE" "$IMAGE_TAG"

echo "Waiting up to $TIMEOUT_SECONDS seconds for container to produce '$PARSING_COMPLETE_PATTERN' OR '$FOUND_AD_PATTERN' in logs..."
SECONDS=0
SUCCESS=false
while [ $SECONDS -lt $TIMEOUT_SECONDS ]; do
  # Проверяем, запущен ли контейнер
  if ! docker ps -q -f name="^/${CONTAINER_NAME}$"; then
    echo "Error: Container $CONTAINER_NAME stopped unexpectedly."
    echo "--- Container Logs ---"
    docker logs "$CONTAINER_NAME" || echo "Could not retrieve logs for stopped container."
    echo "----------------------"
    exit 1 # Выходим с ошибкой, если контейнер упал
  fi
  # Ищем паттерны в логах
  if docker logs "$CONTAINER_NAME" 2>&1 | grep -q -E "$PARSING_COMPLETE_PATTERN|$FOUND_AD_PATTERN"; then
    echo "Success: Found '$PARSING_COMPLETE_PATTERN' or '$FOUND_AD_PATTERN' in logs."
    echo "--- Container Logs (Last 20 lines) ---"
    docker logs "$CONTAINER_NAME" | tail -n 20
    echo "--------------------------------------"
    SUCCESS=true
    break # Выходим из цикла при успехе
  fi
  sleep $CHECK_INTERVAL
  SECONDS=$((SECONDS + CHECK_INTERVAL))
  echo "Still waiting... (${SECONDS}/${TIMEOUT_SECONDS} seconds)"
done

# Проверяем результат после цикла
if [ "$SUCCESS" = false ]; then
  echo "Error: Timeout ($TIMEOUT_SECONDS seconds) reached waiting for '$PARSING_COMPLETE_PATTERN' or '$FOUND_AD_PATTERN'."
  echo "--- Container Logs ---"
  docker logs "$CONTAINER_NAME" || echo "Could not retrieve logs for running container."
  echo "----------------------"
  exit 1 # Выходим с ошибкой, если таймаут
fi

# Явный выход с кодом 0 при успехе (хотя set -e позаботится об ошибках)
exit 0
