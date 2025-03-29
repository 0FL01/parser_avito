FROM python:3.11-slim

LABEL developer="Duff89"

# Set timezone
ENV TZ="Europe/Moscow"
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

ENV PATH="/usr/local/bin:$PATH"
ENV LANG="C.UTF-8"

WORKDIR /parse_avito

# Copy requirements first for caching
COPY requirements.txt /parse_avito/requirements.txt
# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install system dependencies and Google Chrome in one layer
RUN set -ex && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget \
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
        libcurl4 && \
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    dpkg -i --force-depends google-chrome-stable_current_amd64.deb || apt-get install -f -y --no-install-recommends && \
    apt-get autoremove -y --purge wget && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /google-chrome-stable_current_amd64.deb

# Copy the rest of the application code
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

# Make entrypoint executable
RUN chmod +x /parse_avito/entrypoint.sh

ENTRYPOINT ["sh", "entrypoint.sh"]
