# Lit Messenger

Твой приватный мессенджер: дизайн в стиле Telegram, «жидкое стекло» (glass-эффект),
бэкенд на твоём VDS с MySQL и хостингом файлов.

## Что есть
- Личные (1:1) и групповые чаты
- Глобальный поиск как в Telegram: чаты + контакты + сообщения
- Регистрация/вход (JWT), переписка с текстом и фото
- Стеклянный UI (`.ultraThinMaterial`); на iOS 26 автоматически «liquid glass»
- Сборка IPA в GitHub Actions → установка через Sideloadly (без сертификатов/TestFlight)

## Структура
```
backend/   Node.js + Express + MySQL (REST API + раздача файлов)
ios/       iOS-приложение (SwiftUI, XcodeGen)
.github/   GitHub Actions — сборка IPA
```

API: `http://157.228.137.204/api` · Файлы: `http://157.228.137.204/files/<имя>`

## 1. База и бэкенд на VDS
Данные MySQL уже прописаны в `backend/.env` (он в `.gitignore`, поэтому не попадает в репозиторий):
```
DB_HOST=127.0.0.1  DB_USER=litmobiledb_2  DB_NAME=litmobiledb
DB_PASSWORD=<пароль из backend/.env на твоём сервере>
```
> ⚠️ Реальный пароль не коммитится. На VDS создай `backend/.env` с этими значениями
> (он уже есть локально у тебя / в этом проекте), иначе `install.sh` возьмёт плейсхолдер из `.env.example`.

Деплой на сервак (из папки `backend/`):
```bash
cd backend
chmod +x install.sh
./install.sh
```
Ставит Docker, поднимает контейнер (`network_mode: host`, чтобы видеть MySQL на `127.0.0.1`),
создаёт таблицы. Проверка: `curl http://157.228.137.204/api/me` → 401 (сервер жив).
Логи: `docker compose logs -f`. Схему можно пересоздать: `docker compose exec -T backend node src/db_init.js`

## 2. iOS: сборка IPA и установка через Sideloadly
1. Залить репозиторий в GitHub.
2. Push в `main` (или `workflow_dispatch`) запускает `.github/workflows/ios.yml`.
   Он генерирует Xcode-проект, собирает **неподписанный** IPA под устройство и выкладывает
   артефакт `LitMessenger.ipa`.
3. Скачать артефакт из Runs → вкладка Artifacts.
4. Открыть **Sideloadly**, закинуть `LitMessenger.ipa`, ввести свой Apple ID —
   Sideloadly сам подпишет и поставит на iPhone. (Бесплатный аккаунт = перевыпуск раз в 7 дней.)

Локально:
```bash
brew install xcodegen
xcodegen generate --spec ios/project.yml --project ios/
open ios/LitMessenger.xcodeproj
```

## 3. API кратко
- `POST /api/register`, `POST /api/login`, `GET /api/me`, `GET /api/users?q=`
- `GET /api/chats` — список; `POST /api/chats` — личный (`with_user_id`) или группа (`type:"group"`, `title`, `member_ids`)
- `GET /api/chats/search?q=` — глобальный поиск (users/chats/messages)
- `POST /api/chats/:id/members`, `DELETE /api/chats/:id/members/:uid`, `PATCH /api/chats/:id` (переименовать группу)
- `GET /api/chats/:id/messages`, `POST /api/chats/:id/messages`, `POST /api/upload` (фото)
