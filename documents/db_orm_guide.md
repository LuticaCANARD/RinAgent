# DB 및 ORM (SeaORM) 사용 가이드

이 문서는 RinAgent 프로젝트에서 PostgreSQL 데이터베이스와 SeaORM을 사용하는 방법을 설명합니다.

## 1. 사전 준비 (Prerequisites)

SeaORM을 효율적으로 사용하기 위해 CLI 도구가 필요합니다.

```bash
cargo install sea-orm-cli
```

## 2. 빠른 워크플로우 요약 (Quick Workflow)

개발 시 반복되는 작업 순서입니다.

1. **마이그레이션 생성**: 스키마 변경 사항이 생기면 마이그레이션 파일을 만듭니다.

```bash
    sea-orm-cli migrate generate <설명_이름>
```

2. **마이그레이션 작성**: 생성된 `migration/src/mYYYYMMDD_...rs` 파일을 열어 `up`/`down` 로직을 작성합니다.

3. **마이그레이션 적용**: DB에 변경 사항을 반영합니다.

```bash
    sea-orm-cli migrate up
```

4. **Entity 재생성**: 변경된 DB 스키마에 맞춰 Rust 코드를 갱신합니다.

```bash
    sea-orm-cli generate entity -u <DB_URL> -o entity/src --lib
```

6. **코드 작성**: 갱신된 Entity를 사용하여 비즈니스 로직을 구현합니다.

## 3. 프로젝트 구조

- **`entity/`**: 데이터베이스 테이블과 매핑되는 Rust 구조체(Entity)들이 위치합니다.
- **`migration/`**: 데이터베이스 스키마 변경 사항을 관리하는 마이그레이션 코드들이 위치합니다.
- **`rin_agent/`**: 실제 비즈니스 로직이 있는 메인 애플리케이션입니다.

## 4. 마이그레이션 (Migration)

데이터베이스 스키마를 변경(테이블 생성, 컬럼 추가 등)할 때는 반드시 마이그레이션을 통해 진행합니다.

### 4.1 마이그레이션 파일 생성

프로젝트 루트(`rin_agent/`)에서 다음 명령어를 실행하여 새 마이그레이션 파일을 생성합니다.

```bash
# 예: 'posts' 테이블 생성
sea-orm-cli migrate generate create_posts_table
```

생성된 파일은 `migration/src/` 경로에 `m20260101_000001_create_posts_table.rs`와 같은 형태로 저장됩니다.

### 4.2 스키마 정의 작성

생성된 파일의 `up` (적용) 및 `down` (되돌리기) 함수를 작성합니다.

```rust
use sea_orm_migration::prelude::*;

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    // 마이그레이션 적용 (테이블 생성)
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Posts::Table)
                    .if_not_exists()
                    .col(
                        ColumnDef::new(Posts::Id)
                            .integer()
                            .not_null()
                            .auto_increment()
                            .primary_key(),
                    )
                    .col(ColumnDef::new(Posts::Title).string().not_null())
                    .col(ColumnDef::new(Posts::Text).string().not_null())
                    .to_owned(),
            )
            .await
    }

    // 마이그레이션 롤백 (테이블 삭제)
    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_table(Table::drop().table(Posts::Table).to_owned())
            .await
    }
}

// 테이블 및 컬럼 식별자 정의
#[derive(Iden)]
enum Posts {
    Table,
    Id,
    Title,
    Text,
}
```

### 4.3 마이그레이션 적용 (Apply)

작성한 마이그레이션을 실제 DB에 반영합니다. `.env` 파일에 `DATABASE_URL`이 설정되어 있어야 합니다.

```bash
# 프로젝트 루트(rin_agent/)에서 실행
sea-orm-cli migrate up
```

### 4.4 마이그레이션 롤백 (Rollback)

가장 최근의 마이그레이션을 취소합니다.

```bash
sea-orm-cli migrate down
```

## 5. Entity 생성 (Entity Generation)

DB에 변경된 스키마를 Rust 코드(`entity` 크레이트)로 가져옵니다.

```bash
# 프로젝트 루트(rin_agent/)에서 실행
# -u: DB 접속 URL (postgres://아이디:비번@주소/DB명)
# -o: 출력 디렉토리 (entity/src)
# --lib: lib.rs 파일 자동 갱신

sea-orm-cli generate entity -u postgres://user:password@localhost:5432/rin_agent_db -o entity/src --lib
```

> **주의**: `.env` 파일의 `DATABASE_URL`을 참고하여 `-u` 옵션 값을 채워주세요.

## 6. 코드 사용 예시 (Usage)

`rin_agent` 코드 내에서 DB를 조작하는 방법입니다.

### 6.1 데이터 조회 (Select)

```rust
use entity::posts;
use sea_orm::*;

// ID로 조회
let post: Option<posts::Model> = posts::Entity::find_by_id(1)
    .one(&db_connection)
    .await?;

// 모든 데이터 조회
let all_posts: Vec<posts::Model> = posts::Entity::find()
    .all(&db_connection)
    .await?;
```

### 6.2 데이터 추가 (Insert)

```rust
use entity::posts;
use sea_orm::*;

let new_post = posts::ActiveModel {
    title: Set("제목입니다".to_owned()),
    text: Set("내용입니다".to_owned()),
    ..Default::default() // ID는 자동 증가이므로 생략
};

let result = new_post.insert(&db_connection).await?;
println!("Inserted ID: {}", result.id);
```

### 6.3 데이터 수정 (Update)

```rust
use entity::posts;
use sea_orm::*;

// 먼저 조회 후 ActiveModel로 변환
let post: Option<posts::Model> = posts::Entity::find_by_id(1).one(&db_connection).await?;
let mut post: posts::ActiveModel = post.unwrap().into();

// 값 변경
post.title = Set("수정된 제목".to_owned());

// 업데이트 실행
let updated_post: posts::Model = post.update(&db_connection).await?;
```

### 6.4 데이터 삭제 (Delete)

```rust
use entity::posts;
use sea_orm::*;

let post: Option<posts::Model> = posts::Entity::find_by_id(1).one(&db_connection).await?;
let post: posts::Model = post.unwrap();

let result: DeleteResult = post.delete(&db_connection).await?;
```
