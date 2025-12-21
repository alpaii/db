# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This directory contains the Docker configuration for the MySQL 8.0 database used by the alpaii project. The database runs in a containerized environment with persistent data storage.

## Development Commands

### First-Time Setup

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your credentials
# Required variables:
# - MYSQL_ROOT_PASSWORD
# - MYSQL_DATABASE
# - MYSQL_USER
# - MYSQL_PASSWORD
```

### Container Management

```bash
# Start database (detached mode)
docker-compose up -d

# Start with logs visible
docker-compose up

# Stop database
docker-compose down

# Stop and remove volumes (⚠️ DELETES ALL DATA)
docker-compose down -v

# Restart database
docker-compose restart

# View logs
docker-compose logs
docker-compose logs -f          # Follow logs
docker-compose logs --tail=100  # Last 100 lines

# Check container status
docker-compose ps

# View resource usage
docker stats mysql-container
```

### Accessing MySQL

```bash
# MySQL shell as root
docker exec -it mysql-container mysql -u root -p
# Enter MYSQL_ROOT_PASSWORD when prompted

# MySQL shell as app user
docker exec -it mysql-container mysql -u myuser -p
# Enter MYSQL_PASSWORD when prompted

# Execute SQL from host
docker exec -i mysql-container mysql -u root -p${MYSQL_ROOT_PASSWORD} <<< "SHOW DATABASES;"

# Run SQL file
docker exec -i mysql-container mysql -u root -p${MYSQL_ROOT_PASSWORD} < script.sql

# Dump database
docker exec mysql-container mysqldump -u root -p${MYSQL_ROOT_PASSWORD} mydata > backup.sql

# Restore database
docker exec -i mysql-container mysql -u root -p${MYSQL_ROOT_PASSWORD} mydata < backup.sql
```

### Container Shell Access

```bash
# Bash shell inside container
docker exec -it mysql-container bash

# Then inside container:
# - MySQL config: /etc/mysql/my.cnf
# - Data directory: /var/lib/mysql
# - Logs: /var/log/mysql/
```

## Architecture

### Docker Configuration

**Dockerfile**:
- Base image: `mysql:8.0`
- Exposed port: 3306
- Data volume: `/var/lib/mysql`
- Optional: Custom MySQL config (my.cnf)
- Optional: Initialization scripts

**docker-compose.yml**:
- Service name: `mysql`
- Container name: `mysql-container`
- Port mapping: `3306:3306` (host:container)
- Restart policy: `always`
- Network: `mysql-network` (bridge driver)
- Volume: `mysql-data` (persistent storage)

### Environment Variables

Defined in `.env` file (use `.env.example` as template):

| Variable | Description | Example |
|----------|-------------|---------|
| `MYSQL_ROOT_PASSWORD` | Root user password | `SecureRootPass123!` |
| `MYSQL_DATABASE` | Default database name | `mydata` |
| `MYSQL_USER` | Application user | `myuser` |
| `MYSQL_PASSWORD` | Application user password | `SecureUserPass123!` |

### Data Persistence

- **Volume**: `mysql-data` (Docker managed volume)
- **Mount point**: `/var/lib/mysql` inside container
- **Persistence**: Data survives container restarts and removals
- **Backup**: Use `mysqldump` or volume backup methods

### Networking

- **Network name**: `mysql-network`
- **Driver**: bridge
- **Access from other containers**: Use service name `mysql` as hostname
- **Access from host**: `localhost:3306` or `127.0.0.1:3306`

## Initialization Scripts

To run SQL scripts on first container startup:

1. Create `init.sql` in this directory
2. Uncomment the volume mapping in `docker-compose.yml`:
   ```yaml
   volumes:
     - ./init.sql:/docker-entrypoint-initdb.d/init.sql
   ```
3. Scripts in `/docker-entrypoint-initdb.d/` run only on first initialization

**Example init.sql**:
```sql
-- Create tables
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email) VALUES
    ('admin', 'admin@example.com'),
    ('user1', 'user1@example.com');

-- Grant privileges
GRANT ALL PRIVILEGES ON mydata.* TO 'myuser'@'%';
FLUSH PRIVILEGES;
```

## Configuration Customization

### Custom MySQL Configuration

To override MySQL defaults:

1. Create `my.cnf` in this directory
2. Uncomment the COPY line in `Dockerfile`:
   ```dockerfile
   COPY my.cnf /etc/mysql/conf.d/
   ```
3. Rebuild: `docker-compose up -d --build`

**Example my.cnf**:
```ini
[mysqld]
# Character set
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci

# Performance
max_connections=200
innodb_buffer_pool_size=1G

# Logging
general_log=1
general_log_file=/var/log/mysql/general.log
slow_query_log=1
slow_query_log_file=/var/log/mysql/slow.log
long_query_time=2
```

## Common Tasks

### Connecting from Backend Application

**Connection String Example** (Python/SQLAlchemy):
```python
# When running locally (host machine)
DATABASE_URL = "mysql+pymysql://myuser:SecureUserPass123!@localhost:3306/mydata"

# When running in Docker Compose (same network)
DATABASE_URL = "mysql+pymysql://myuser:SecureUserPass123!@mysql:3306/mydata"
```

**Node.js Example**:
```javascript
// When running locally
const connection = mysql.createConnection({
  host: 'localhost',
  port: 3306,
  user: 'myuser',
  password: 'SecureUserPass123!',
  database: 'mydata'
});

// When running in Docker Compose
const connection = mysql.createConnection({
  host: 'mysql',  // Use service name
  port: 3306,
  user: 'myuser',
  password: process.env.MYSQL_PASSWORD,
  database: 'mydata'
});
```

### Backup and Restore

```bash
# Backup all databases
docker exec mysql-container mysqldump -u root -p${MYSQL_ROOT_PASSWORD} --all-databases > full_backup.sql

# Backup specific database
docker exec mysql-container mysqldump -u root -p${MYSQL_ROOT_PASSWORD} mydata > mydata_backup.sql

# Backup with compression
docker exec mysql-container mysqldump -u root -p${MYSQL_ROOT_PASSWORD} mydata | gzip > mydata_backup.sql.gz

# Restore database
docker exec -i mysql-container mysql -u root -p${MYSQL_ROOT_PASSWORD} mydata < mydata_backup.sql

# Restore from compressed backup
gunzip < mydata_backup.sql.gz | docker exec -i mysql-container mysql -u root -p${MYSQL_ROOT_PASSWORD} mydata
```

### Reset Database

```bash
# Stop and remove container + volume (⚠️ DELETES ALL DATA)
docker-compose down -v

# Start fresh (runs init scripts again)
docker-compose up -d
```

### Monitoring

```bash
# View real-time MySQL process list
docker exec -it mysql-container mysql -u root -p -e "SHOW PROCESSLIST;"

# Check database size
docker exec -it mysql-container mysql -u root -p -e "
SELECT
    table_schema AS 'Database',
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
FROM information_schema.tables
GROUP BY table_schema;
"

# Check table sizes
docker exec -it mysql-container mysql -u root -p -e "
SELECT
    table_name AS 'Table',
    ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'mydata'
ORDER BY (data_length + index_length) DESC;
"
```

## Important Notes

### Security

- **NEVER commit `.env` file** - it's in `.gitignore`
- Use strong passwords for production
- Change default credentials in `.env.example` before deployment
- Consider using Docker secrets for production environments
- Restrict port exposure (don't expose 3306 publicly in production)

### Data Persistence

- Data persists in Docker volume `mysql-data`
- Removing the container does NOT delete data
- `docker-compose down -v` WILL delete all data
- Always backup before major changes

### Port Conflicts

If port 3306 is already in use:
```yaml
# Change in docker-compose.yml
ports:
  - "3307:3306"  # Use different host port
```

### Performance

- Default config is suitable for development
- For production, tune `my.cnf` based on server resources
- Consider using `innodb_buffer_pool_size` = 70-80% of available RAM
- Monitor slow queries and add indexes as needed

### Character Encoding

- MySQL 8.0 defaults to `utf8mb4` (recommended)
- Supports full Unicode including emojis
- Ensure application connection also uses `utf8mb4`

## Troubleshooting

### Container won't start
```bash
# Check logs
docker-compose logs mysql

# Common issues:
# - Port 3306 already in use
# - Invalid .env variables
# - Corrupted volume data
```

### Cannot connect from application
```bash
# Verify container is running
docker-compose ps

# Check network connectivity
docker exec -it mysql-container mysql -u root -p -e "SELECT 1;"

# Verify user privileges
docker exec -it mysql-container mysql -u root -p -e "
SELECT user, host FROM mysql.user WHERE user='myuser';
"
```

### Forgot password
```bash
# Stop container
docker-compose down

# Edit .env with new password
# Remove volume to reset
docker volume rm db_mysql-data

# Start fresh
docker-compose up -d
```

## Integration with Other Services

When using with backend API:

1. **Same Docker Compose**: Add API service to this `docker-compose.yml`
2. **Separate Compose**: Create shared network
   ```bash
   docker network create alpaii-network
   ```
   Then reference in both compose files

3. **Use service name as hostname**: `mysql` instead of `localhost`
4. **Environment variables**: Pass DB credentials to API container
