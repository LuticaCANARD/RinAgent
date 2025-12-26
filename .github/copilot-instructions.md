# Copilot instructions for RinAgent

Purpose: Enable AI coding agents to be productive quickly in this Rust workspace by capturing architecture, workflows, conventions, and integration points specific to this repo.

## Big picture
- Workspace crates: `rin_agent` (main), `entity` (SeaORM entities), `migration` (SeaORM migrations), `gemini_live_api` (Gemini types/helpers).
- Runtime: Discord bot (serenity + songbird) and Rocket web server run concurrently (spawned tasks); DB connection initialized once via `OnceCell`.
- Data: PostgreSQL via SeaORM; Redis available via `redis` + `r2d2` (pool in `libs/redis_driver.rs`).
- AI: Google Gemini API calls with tool/function-calling; custom tools live under `src/gemini/tools/*` and are registered via macros.

## Start-up & key flows
- Entry: `src/main.rs` initializes `.env`, DB (`model::db::driver::connect_to_db`), builds services (`api::instances::init_rin_services()`), starts:
  - Discord bot: `discord::discord_bot_manager::BotManager` (slash commands, voice). Event dispatch uses macros and a lazy registry.
  - Web server: `web::server::server::get_rocket().launch()` (Rocket routes under `src/web/*`).
- Cross-thread messaging: Tokio watch channels in `libs::thread_pipelines` (e.g., `GEMINI_FUNCTION_EXECUTION_ALARM`, `SCHEDULE_TO_DISCORD_PIPELINE`) propagate Gemini and scheduler results to Discord.

## Developer workflows
- Prereqs: Postgres and Redis (use `docker-compose.yml`: `rin_postgres` and `rin_redis`).
- Build/run (dev): `cargo run -p rin_agent` (ensure `.env` has `DATABASE_URL`, `DISCORD_TOKEN`, `GEMINI_API_KEY`, etc.).
- Release: `cargo build --release` then run the produced binary. Rocket binds inside the same process.
- DB migrations: use SeaORM CLI. Typical: `sea-orm-cli migrate up`. Entities: `sea-orm-cli generate entity --lib` from `rin_agent/entity/src`.
- Tests: workspace tests under `rin_agent/src/tests/*`. Run: `cargo test` (or target a file with `--test` filters).

## Conventions & patterns
- Logging: use `libs::logger::LOGGER` with `LogLevel` (avoid `println!`). Errors often mirrored to Discord via `service::discord_error_msg`.
- DI/service context: `rs_ervice` with `OnceLock` context (see `get_discord_service`). Prefer registering services in context builders vs global statics when extending.
- Discord commands:
  - Define each command module in `src/discord/commands/<name>.rs` exposing `register() -> CreateCommand` and `run(..) -> Result<...>`.
  - Register by adding the module to `define_lazy_static!(USING_COMMANDS, USING_ACTIVATE_COMMANDS, [...])` list in `discord_bot_manager.rs`.
  - Dispatch happens via `USING_ACTIVATE_COMMANDS` closure; follow existing error handling that builds embeds with a timestamp footer.
- Gemini integration:
  - Client: `src/gemini/gemini_client.rs` builds requests, handles function calling, accumulates `contents`, and retries until a terminal response (look for `response_msg` or text).
  - Tools: implement `get_command()` in `src/gemini/tools/<tool>.rs` returning `GeminiBotTools`; register in `load_gemini_tools!` macro in `setting/gemini_setting.rs`.
  - Config: models via `GEMINI_MODEL_PRO/FLASH`, generation via `GENERATE_CONF`, safety via `SAFETY_SETTINGS`, begin prompt via `get_begin_query(locale, user, guild, channel)`.
- Database: connect via `DATABASE_URL` once (`DB_CONNECTION_POOL: OnceCell<DatabaseConnection>`). Query examples in `discord_bot_manager.rs` using `entity::*` models.

## External integration points
- Discord: serenity gateway with intents incl. `GUILD_VOICE_STATES`; voice via songbird and a custom `VoiceHandler` stored in `TypeMap`.
- Gemini API: `reqwest` calls to `generativelanguage.googleapis.com` using `GEMINI_API_KEY`; function results may emit pipeline alarms to Discord.
- Web: Rocket app composed under `src/web/server/*` and `src/web/api/*` (serve APIs/static under `static/`).

## Environment & examples
- Required env vars (commonly used): `DATABASE_URL`, `DISCORD_TOKEN`, `DISCORD_CLIENT_ID`, `GEMINI_API_KEY`, `MANAGER_ID`, `GEMINI_THINKING_BUDGET`.
- Example: add a new Discord slash command
  1) Create `src/discord/commands/hello.rs` with `register()` and `run()` similar to `gemini_query`.
  2) Add `hello` to the macro list in `discord_bot_manager.rs`.
  3) Re-run; commands are (re)registered on `ready()` per guilds stored in DB.
- Example: add a Gemini tool
  1) Create `src/gemini/tools/my_tool.rs` with `get_command()` producing a `GeminiBotTools { name, action }`.
  2) Append `my_tool` in `load_gemini_tools!` inside `setting/gemini_setting.rs`.

Notes
- Keep macro lists in sync; the command/tool registries are macro-driven.
- Prefer updating `LOGGER` and sending structured embeds for user-visible errors.
- Dockerfile is minimal and may require review (release vs debug path); rely on local `cargo` for development.
