FROM mysql:8.0

# MySQL 설정 파일 복사 (필요시)
# COPY my.cnf /etc/mysql/conf.d/

# 초기화 스크립트 복사 (필요시)
# COPY ./init.sql /docker-entrypoint-initdb.d/

# 포트 노출
EXPOSE 3306

# MySQL 데이터 볼륨
VOLUME /var/lib/mysql
