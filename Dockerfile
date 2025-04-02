FROM python:3.11-slim as builder

ENV TZ="Europe/Moscow"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
        ca-certificates \
        dpkg \
        apt-utils && \
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    dpkg -i --force-depends google-chrome-stable_current_amd64.deb || apt-get install -f -y --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /google-chrome-stable_current_amd64.deb

FROM python:3.11-slim

ENV TZ="Europe/Moscow"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

ENV PATH="/usr/local/bin:$PATH"
ENV LANG="C.UTF-8"

WORKDIR /parse_avito

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

COPY --from=builder /opt/google/chrome /opt/google/chrome
COPY --from=builder /usr/bin/google-chrome* /usr/bin/
COPY requirements.txt /parse_avito/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt
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

RUN chmod +x /parse_avito/entrypoint.sh

ENTRYPOINT ["sh", "entrypoint.sh"]