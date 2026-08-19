# Testing Setup - Simplified Version

## Vấn đề

Do hệ thống disk đầy và không có quyền tạo database mới trên server, chúng ta sẽ dùng phương pháp đơn giản hơn.

## Giải pháp: Manual Testing với Server Riêng

### Tạm thời dùng database dev để test

Hiện tại bạn có thể chạy manual test trực tiếp với database dev:

```bash
# Start server ở port khác để test
PORT=3003 npm run start:dev
```

**Lưu ý**: Cẩn thận với data khi test như vậy.

## Khuyến nghị: Setup Local Database

Để test an toàn, bạn nên:

### 1. Giải phóng dung lượng disk (QUAN TRỌNG)

```bash
# Kiểm tra disk usage
df -h

# Xóa Docker cache (cần ~10GB free)
docker system prune -a --volumes

# Xóa node_modules không dùng
find ~/Documents -name "node_modules" -type d -mtime +30 -prune -exec rm -rf {} \;

# Xóa Xcode derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### 2. Restart Docker Desktop

- Quit Docker Desktop hoàn toàn
- Mở lại Docker Desktop

### 3. Khởi động test database local

Sau khi có đủ dung lượng (ít nhất 10GB free):

```bash
# Start test database
./scripts/test-db.sh start

# Chờ database ready
sleep 5

# Run migrations
export $(cat .env.test | grep -v '^#' | xargs)
npm run migration:run

# Start server với test database
PORT=3003 npm run start:dev
```

## Alternative: PostgreSQL Local

Nếu Docker không hoạt động, cài PostgreSQL trực tiếp:

```bash
# Install PostgreSQL
brew install postgresql@15
brew services start postgresql@15

# Create test database
createdb app_19t_test

# Update .env.test
DB_HOST=localhost
DB_PORT=5432
DB_NAME=app_19t_test
```

## Tóm lại

**Hiện tại**: Dùng database dev để test cẩn thận
**Lâu dài**: Giải phóng disk → Setup Docker local database

