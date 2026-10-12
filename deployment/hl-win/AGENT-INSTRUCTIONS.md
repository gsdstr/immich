# Инструкция для ИИ-агента на хосте `hl-win` (Windows / Docker Desktop)

> **Назначение документа**: Данная инструкция предназначена для автономного или полуавтономного агента, выполняющего задачи на машине `hl-win` (Windows host с Docker Desktop). Документ регламентирует управление контейнерами, сетевыми портами, бэкапами и сохранностью файлов фотоархива.

---

## 1. Роль и границы ответственности `hl-win`

Хост `hl-win` является **инфраструктурным сервером хранения и базы данных**.
- **В зоне ответственности `hl-win`**:
  1. Постоянные сервисы данных: PostgreSQL 14 (`immich_postgres` с расширением `pgvector`), Redis (`immich_redis`), сервис бэкапов (`immich_db_backup`).
  2. Физическое хранение оригиналов фото (`UPLOAD_LOCATION`, например `D:\Photos\Immich`).
  3. Запуск боевой версии `immich-server` и `immich-machine-learning` в нерабочее (не dev) время.
- **ВНЕ зоны ответственности `hl-win`**:
  1. Правка исходного кода Immich (разработка ведется на Mac).
  2. Git-ветки и отправка PR в upstream (управляются с Mac).
  3. Локальная сборка Docker-образов из исходников (образы собираются через GitHub Actions в ветке `deploy/hl-win` и скачиваются из `ghcr.io/gsdstr/immich-server:latest`).

---

## 2. Размещение и файлы окружения

Рабочая папка деплоя на `hl-win` (например, `C:\opt\immich` или `D:\immich\deployment`):
```text
deployment/
├── docker-compose.yml       # Конфигурация всех сервисов с профилями
├── .env                     # Локальные переменные окружения
├── start-full.cmd           # Скрипт запуска боевого режима
├── start-infra.cmd          # Скрипт перевода в режим инфраструктуры для dev
└── backups/                 # Директория ежедневных дампов БД (ротация 7 дней)
```

### Конфигурация `.env` на `hl-win`
```dotenv
UPLOAD_LOCATION=D:\Photos\Immich
DB_PASSWORD=your_secure_postgres_password
DB_USERNAME=postgres
DB_DATABASE_NAME=immich
IMMICH_SERVER_IMAGE=ghcr.io/gsdstr/immich-server:latest
```

---

## 3. Режимы работы и команды управления

### Режим А: «Инфраструктура для разработки» (когда пользователь кодит на Mac)
> **Критическое правило**: Контейнеры `immich-server` и `immich-machine-learning` на `hl-win` **ДОЛЖНЫ БЫТЬ ОСТАНОВЛЕНЫ**, чтобы не конкурировать с Mac за очереди Redis (BullMQ) и не блокировать таблицы в БД.

**Запуск**:
```cmd
start-infra.cmd
```
*Или вручную:*
```cmd
docker compose stop immich-server immich-machine-learning
docker compose up -d database redis db-backup
```
**Проверка готовности**:
```cmd
docker compose ps
```
Должны работать только: `immich_postgres` (порт 5432), `immich_redis` (порт 6379), `immich_db_backup`.

---

### Режим Б: «Боевой режим» (Full Production)
Запускает полный стек, включая сервер приложений и контейнер ML.

**Запуск**:
```cmd
start-full.cmd
```
*Или вручную:*
```cmd
docker compose --profile app up -d
```

---

### Обновление сервера до новой кастомной версии из GHCR
Когда в ветку `deploy/hl-win` пушатся новые доработки, GitHub Actions публикует свежий образ. Для обновления на `hl-win`:
```cmd
docker compose pull immich-server
docker compose --profile app up -d
docker compose ps
```

---

## 4. Сеть и фаервол Windows

Для того чтобы Mac имел прямой доступ к инфраструктуре по локальной сети:
1. Порты `5432` (PostgreSQL) и `6379` (Redis) проброшены в `docker-compose.yml` наружу (`0.0.0.0:...`).
2. В Windows Defender Firewall должны быть разрешены входящие подключения для портов 5432 и 6379 из локальной подсети (или для частного профиля сети):
   ```powershell
   # Проверка / открытие портов в PowerShell (от имени Администратора при необходимости):
   New-NetFirewallRule -DisplayName "Immich Dev Postgres" -Direction Inbound -Protocol TCP -LocalPort 5432 -Action Allow
   New-NetFirewallRule -DisplayName "Immich Dev Redis" -Direction Inbound -Protocol TCP -LocalPort 6379 -Action Allow
   ```

---

## 5. Бэкапы и безопасность данных

1. **Автоматический бэкап**:
   - Контейнер `immich_db_backup` автоматически делает дамп базы каждое утро в `05:00`.
   - Глубина хранения — 7 дней (`BACKUP_KEEP_DAYS: 7`), старые дампы ротируются автоматически.
   - Дампы сохраняются в папку `./backups/`.
2. **Ручной бэкап перед подозрительными операциями**:
   ```cmd
   docker exec -t immich_postgres pg_dump -U postgres immich > .\backups\manual_pre_migration_%date%.sql
   ```
3. **Восстановление из дампа (при аварии)**:
   ```cmd
   # Остановить приложения
   docker compose stop immich-server immich-machine-learning
   # Восстановить базу
   cat .\backups\immich-backup-YYYY-MM-DD.sql | docker exec -i immich_postgres psql -U postgres -d immich
   ```

---

## 6. Жесткие запреты для агента на `hl-win` (Hard Rules)

1. ❌ **НИКОГДА** не удалять и не перезаписывать файлы в директории `UPLOAD_LOCATION` (`D:\Photos\Immich`). Любые операции с фото — только чтение.
2. ❌ **НИКОГДА** не запускать `immich-server` на `hl-win` одновременно с локальным dev-сервером на Mac при общей очереди Redis.
3. ❌ **НИКОГДА** не выполнять `docker compose down -v` (удаление томов данных `pgdata`). Для перезапуска использовать только `docker compose restart` или `docker compose stop / up`.
4. ❌ **НИКОГДА** не пересобирать образы локально на Windows через `docker build` (сборка выполняется централизованно в GitHub Actions).
