#!/bin/bash

# Выходить немедленно, если команда завершается с ненулевым статусом.
set -e

TIMEOUT=120
INTERVAL=5 
EXPECTED_LOG_STRING="Poco F6"
CONTAINER_NAME="avito-parser-test-${GITHUB_RUN_ID:-$(date +%s)}"

# --- Функции ---
# Функция очистки ресурсов
cleanup() {
  echo "Очистка тестового контейнера ${CONTAINER_NAME}..."
  # Останавливаем контейнер, игнорируем ошибки, если он уже остановлен
  docker stop "$CONTAINER_NAME" > /dev/null 2>&1 || true
  # Удаляем контейнер, игнорируем ошибки, если он уже удален
  docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
  # Удаляем временный файл .env.test
  rm -f .env.test
  echo "Очистка завершена."
}

# --- Основной скрипт ---

# Устанавливаем ловушку (trap), чтобы гарантировать выполнение cleanup при любом выходе из скрипта
# EXIT - нормальное завершение, INT - прерывание (Ctrl+C), TERM - сигнал завершения
trap cleanup EXIT INT TERM

# 1. Создание файла .env.test
echo "Создание файла .env.test..."
# Проверка наличия обязательных переменных окружения (хорошая практика)
: "${IMAGE_TAG:?Переменная IMAGE_TAG не установлена}"
: "${GITHUB_RUN_ID:?Переменная GITHUB_RUN_ID не установлена}"
: "${URL_AVITO:?Переменная URL_AVITO не установлена}"
: "${CHAT_ID_TG:?Переменная CHAT_ID_TG не установлена}"
: "${TG_TOKEN:?Переменная TG_TOKEN не установлена}"
: "${NUM_ADS_AVITO:?Переменная NUM_ADS_AVITO не установлена}"
: "${FREQ_AVITO:?Переменная FREQ_AVITO не установлена}"
: "${KEYS_AVITO:?Переменная KEYS_AVITO не установлена}"
: "${MAX_PRICE_AVITO:?Переменная MAX_PRICE_AVITO не установлена}"
: "${MIN_PRICE_AVITO:?Переменная MIN_PRICE_AVITO не установлена}"
# Добавьте проверки для остальных переменных при необходимости

# Используем cat с Here Document для создания файла .env.test
cat << EOF > .env.test
URL_AVITO=${URL_AVITO}
CHAT_ID_TG=${CHAT_ID_TG}
TG_TOKEN=${TG_TOKEN}
NUM_ADS_AVITO=${NUM_ADS_AVITO}
FREQ_AVITO=${FREQ_AVITO}
KEYS_AVITO=${KEYS_AVITO}
MAX_PRICE_AVITO=${MAX_PRICE_AVITO}
MIN_PRICE_AVITO=${MIN_PRICE_AVITO}
GEO_AVITO=${GEO_AVITO}
PROXY_AVITO=${PROXY_AVITO}
PROXY_CHANGE_IP_AVITO=${PROXY_CHANGE_IP_AVITO}
NEED_MORE_INFO_AVITO=${NEED_MORE_INFO_AVITO}
DEBUG_MODE_AVITO=${DEBUG_MODE_AVITO}
FAST_SPEED_AVITO=${FAST_SPEED_AVITO}
KEYS_BLACK_AVITO=${KEYS_BLACK_AVITO}
MAX_VIEW_AVITO=${MAX_VIEW_AVITO}
EOF
echo "Файл .env.test создан."

# 2. Запуск Docker контейнера
echo "Запуск контейнера ${CONTAINER_NAME} из образа ${IMAGE_TAG}..."
# Используем -d для запуска в фоновом (detached) режиме
# Используем --env-file для загрузки переменных из файла .env.test
# Используем --name для присвоения имени контейнеру
DOCKER_RUN_ID=$(docker run -d --name "$CONTAINER_NAME" --env-file .env.test "$IMAGE_TAG")
echo "ID запущенного контейнера: $DOCKER_RUN_ID"

# 3. Ожидание появления ожидаемой строки в логах
echo "Ожидание до ${TIMEOUT} секунд появления '${EXPECTED_LOG_STRING}' в логах контейнера ${CONTAINER_NAME}..."
ELAPSED=0
FOUND=0
# Цикл ожидания
while [ $ELAPSED -lt $TIMEOUT ]; do
  # Проверяем логи на наличие ожидаемой строки.
  # grep -q работает в "тихом" режиме (не выводит найденные строки, только возвращает код успеха/неудачи)
  # 2>&1 перенаправляет stderr в stdout, чтобы grep мог обработать и ошибки docker logs
  if docker logs "$CONTAINER_NAME" 2>&1 | grep -q "${EXPECTED_LOG_STRING}"; then
    echo "Строка '${EXPECTED_LOG_STRING}' найдена в логах."
    FOUND=1
    break # Выходим из цикла, так как строка найдена
  fi

  # Проверяем, работает ли еще контейнер
  # docker ps -q находит ID запущенных контейнеров
  # --filter name="^/${CONTAINER_NAME}$" фильтрует по точному имени контейнера (с / в начале)
  if ! docker ps -q --filter name="^/${CONTAINER_NAME}$"; then
     echo "Ошибка: Контейнер ${CONTAINER_NAME} неожиданно остановился."
     echo "--- Последние логи контейнера ---"
     # Пытаемся получить логи, даже если контейнер остановлен
     docker logs "$CONTAINER_NAME" || echo "Не удалось получить логи остановленного контейнера."
     echo "---------------------------"
     # Выходим с ошибкой, так как контейнер упал
     # cleanup будет вызван автоматически через trap
     exit 1
  fi

  # Ждем перед следующей проверкой
  sleep $INTERVAL
  # Увеличиваем счетчик прошедшего времени
  ELAPSED=$((ELAPSED + INTERVAL))
  echo "Все еще ожидаем... (${ELAPSED}/${TIMEOUT} секунд)"
done

# 4. Проверка результата и выход
if [ $FOUND -eq 1 ]; then
  echo "Тест контейнера успешно завершен."
  # Опционально: выводим фрагмент логов вокруг найденной строки для контекста
  echo "--- Фрагмент логов (${EXPECTED_LOG_STRING}) ---"
  # grep -C 5 показывает 5 строк до и после найденной строки
  docker logs "$CONTAINER_NAME" 2>&1 | grep "${EXPECTED_LOG_STRING}" -C 5 || true # Игнорируем ошибку grep, если вдруг строка исчезла
  echo "----------------------------------"
  # Выходим с кодом 0 (успех)
  # cleanup будет вызван автоматически через trap
  exit 0
else
  # Если цикл завершился по таймауту
  echo "Ошибка: Таймаут (${TIMEOUT} секунд) достигнут во время ожидания '${EXPECTED_LOG_STRING}'."
  echo "--- Полные логи контейнера ---"
  # Выводим все логи для диагностики
  docker logs "$CONTAINER_NAME"
  echo "---------------------------"
  # Выходим с кодом 1 (ошибка)
  # cleanup будет вызван автоматически через trap
  exit 1
fi

# Ловушка trap вызовет функцию cleanup здесь при любом коде выхода (0 или 1)