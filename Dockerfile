# Этап 1: Builder для установки Chrome и зависимостей
FROM python:3.11-slim as builder

ENV TZ="Europe/Moscow"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Устанавливаем только то, что нужно для скачивания и установки Chrome
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        # Минимальные зависимости для dpkg и apt-get -f install
        dpkg \
        apt-utils && \
    # Устанавливаем Chrome и его зависимости
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    dpkg -i --force-depends google-chrome-stable_current_amd64.deb || apt-get install -f -y --no-install-recommends && \
    # Очистка не так критична в builder-стадии, но не помешает
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /google-chrome-stable_current_amd64.deb

# Этап 2: Финальный образ
FROM python:3.11-slim

LABEL developer="Duff89"

# Set timezone
ENV TZ="Europe/Moscow"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV PATH="/usr/local/bin:$PATH"
ENV LANG="C.UTF-8"

WORKDIR /parse_avito

# Устанавливаем только RUNTIME зависимости Chrome, которые не были установлены через .deb
# Сначала обновим список пакетов
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        fonts-liberation \
        libasound2 \
        libatk-bridge2.0-0 \
        libatk1.0-0 \
        libatspi2.0-0 \
        libcups2 \
        libdbus-1-3 \
        libdrm2 \
        libgbm1 \
        libgtk-3-0 \
        libnspr4 \
        libnss3 \
        libwayland-client0 \
        libxcomposite1 \
        libxdamage1 \
        libxfixes3 \
        libxkbcommon0 \
        libxrandr2 \
        xdg-utils \
        libu2f-udev \
        libvulkan1 \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Копируем установленный Chrome из builder-стадии
# Пути могут потребовать уточнения в зависимости от того, куда Chrome ставится
COPY --from=builder /opt/google/chrome /opt/google/chrome
COPY --from=builder /usr/bin/google-chrome* /usr/bin/

# Копируем requirements и устанавливаем Python зависимости (как и раньше, это хорошо кешируется)
COPY requirements.txt /parse_avito/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Копируем остальной код приложения
# Используем один COPY для примера, но можно и несколько, как у вас было
COPY custom_exception.py /parse_avito/custom_exception.py
COPY db_service.py /parse_avito/db_service.py
COPY lang.py /parse_avito/lang.py
COPY locator.py /parse_avito/locator.py
COPY parser_cls.py /parse_avito/parser_cls.py
COPY settings.ini /parse_avito/settings.ini
COPY user_agent_pc.txt /parse_avito/user_agent_pc.txt
COPY xlsx_service.py /parse_avito/xlsx_service.py
COPY entrypoint.sh /parse_avito/entrypoint.sh
COPY version.py /parse_avito/version.py
# Или одной командой:
# COPY . /parse_avito/

# Делаем entrypoint исполняемым
RUN chmod +x /parse_avito/entrypoint.sh

ENTRYPOINT ["sh", "entrypoint.sh"]