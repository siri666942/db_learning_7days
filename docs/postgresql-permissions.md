# PostgreSQL 用户与权限语法

## 用户与角色

```sql
CREATE ROLE intern NOLOGIN;                       -- 创建不能登录的权限组
CREATE ROLE alice LOGIN PASSWORD 'your_password'; -- 创建登录用户
CREATE USER bob PASSWORD 'your_password';         -- 创建用户，默认带 LOGIN

ALTER ROLE alice PASSWORD 'new_password';         -- 修改密码
ALTER ROLE alice NOLOGIN;                         -- 禁止新登录，已有连接不受影响
ALTER ROLE alice LOGIN;                           -- 恢复登录
ALTER ROLE alice VALID UNTIL '2026-12-31 23:59:59+08'; -- 设置密码认证的到期时间

ALTER ROLE alice CREATEDB;                        -- 允许创建数据库
ALTER ROLE alice NOCREATEDB;                      -- 撤回创建数据库的能力
ALTER ROLE alice CREATEROLE;                      -- 允许相应范围内的角色管理
ALTER ROLE alice NOCREATEROLE;                    -- 撤回角色管理能力
ALTER ROLE alice SUPERUSER;                       -- 设为超级用户，需超级用户执行
ALTER ROLE alice NOSUPERUSER;                     -- 撤回超级用户属性

GRANT intern TO alice;                           -- alice 加入 intern
REVOKE intern FROM alice;                        -- alice 退出 intern
SET ROLE intern;                                 -- 切换执行身份，需有切换权限
RESET ROLE;                                      -- 恢复原执行身份

DROP ROLE alice;                                 -- 删除角色，需先处理对象与权限依赖
```

PG 中用户是带 `LOGIN` 的角色，用户名需先在服务器创建。普通对象权限可通过角色继承；`SUPERUSER`、`CREATEDB` 等属性不会自动继承。

## database 权限

```sql
GRANT CONNECT ON DATABASE testdb TO alice;        -- 允许连接数据库
GRANT CREATE ON DATABASE testdb TO alice;         -- 允许在库内创建 schema 等对象
GRANT TEMPORARY ON DATABASE testdb TO alice;      -- 允许创建临时表
GRANT ALL PRIVILEGES ON DATABASE testdb TO alice; -- 授予该数据库支持的全部普通权限

REVOKE CONNECT ON DATABASE testdb FROM alice;     -- 撤回这条连接授权
REVOKE CREATE ON DATABASE testdb FROM alice;      -- 撤回在库内创建 schema 等的权限
REVOKE TEMPORARY ON DATABASE testdb FROM alice;   -- 撤回创建临时表的权限
```

数据库权限不包含其中表的 CRUD。撤回 CONNECT 不会断开已有连接；若 PUBLIC 仍有 CONNECT，用户仍可能连接。

## schema 权限

```sql
GRANT USAGE ON SCHEMA analytics TO alice;         -- 允许使用 schema 中的对象名称
GRANT CREATE ON SCHEMA sandbox TO alice;          -- 允许在 schema 中创建对象
GRANT USAGE, CREATE ON SCHEMA sandbox TO alice;   -- 同时授予访问与创建权限

REVOKE USAGE ON SCHEMA analytics FROM alice;      -- 撤回 schema 访问授权
REVOKE CREATE ON SCHEMA sandbox FROM alice;       -- 撤回创建对象的权限

CREATE SCHEMA sandbox AUTHORIZATION alice;       -- 创建由 alice 拥有的 schema
ALTER SCHEMA sandbox OWNER TO alice;             -- 转移 schema 所有权
```

`USAGE` 不等于表的 SELECT；`CREATE` 不等于已有表的 CRUD。查询通常需要 database CONNECT + schema USAGE + 表 SELECT。

## 表与列权限

```sql
GRANT SELECT ON TABLE lab.salary TO alice;        -- 允许查询表
GRANT INSERT ON TABLE lab.salary TO alice;        -- 允许插入行
GRANT UPDATE ON TABLE lab.salary TO alice;        -- 允许修改行
GRANT DELETE ON TABLE lab.salary TO alice;        -- 允许删除行

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE lab.salary TO alice;                    -- 一次授予 CRUD

GRANT SELECT ON TABLE lab.salary, lab.staff TO intern; -- 同时授权多张表
GRANT SELECT ON TABLE lab.salary TO alice, bob;   -- 同时授权多个用户

GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO intern; -- 现有表/视图全部只读
GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA sandbox TO alice;         -- 现有表/视图全部授予 CRUD

GRANT ALL PRIVILEGES ON TABLE lab.salary TO alice; -- 授予该表支持的全部普通权限
GRANT TRUNCATE ON TABLE lab.salary TO alice;      -- 允许清空整张表
GRANT REFERENCES ON TABLE lab.salary TO alice;    -- 允许外键引用该表
GRANT TRIGGER ON TABLE lab.salary TO alice;       -- 允许在表上创建触发器

GRANT SELECT (id, name) ON TABLE lab.salary TO bob; -- 只允许查询指定列
GRANT INSERT (id, name) ON TABLE lab.salary TO bob; -- 只允许向指定列插入值
GRANT UPDATE (name) ON TABLE lab.salary TO bob;    -- 只允许更新指定列
GRANT REFERENCES (id) ON TABLE lab.salary TO bob; -- 允许外键引用指定列

ALTER TABLE lab.salary OWNER TO alice;            -- 转移表所有权，需满足所有权转移条件
```

- `ALL TABLES IN SCHEMA` 只覆盖现有对象，未来对象需设置默认权限。
- 整表 SELECT 已存在时，撤回单列 SELECT 不能隐藏该列；需消除整表授权来源。
- `DELETE` 删除行，`DROP TABLE` 删除表。改表结构、删表主要由所有权决定，CRUD 和 `ALL PRIVILEGES` 不等于所有权。
- 带 WHERE 的 UPDATE/DELETE 通常还需要对条件中使用的列有 SELECT 权限。

## 序列权限

```sql
GRANT USAGE ON SEQUENCE lab.salary_id_seq TO alice; -- 允许 nextval / currval
GRANT SELECT ON SEQUENCE lab.salary_id_seq TO alice; -- 允许读序列、使用 currval
GRANT UPDATE ON SEQUENCE lab.salary_id_seq TO alice; -- 允许 nextval / setval

GRANT USAGE ON ALL SEQUENCES IN SCHEMA sandbox TO alice; -- 批量授权现有序列
REVOKE USAGE ON ALL SEQUENCES IN SCHEMA sandbox FROM alice; -- 批量撤回授权
```

对使用 `serial` / `nextval` 默认值的表插入数据，可能还需要对应序列的 USAGE。

## 默认权限

```sql
ALTER DEFAULT PRIVILEGES FOR ROLE data_owner IN SCHEMA analytics
GRANT SELECT ON TABLES TO intern;                 -- data_owner 以后建的表自动给 intern 只读

ALTER DEFAULT PRIVILEGES FOR ROLE data_owner IN SCHEMA sandbox
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO alice; -- 以后建的表自动给 alice CRUD

ALTER DEFAULT PRIVILEGES FOR ROLE data_owner IN SCHEMA sandbox
GRANT USAGE ON SEQUENCES TO alice;                -- 以后建的序列自动授予 USAGE

ALTER DEFAULT PRIVILEGES FOR ROLE data_owner IN SCHEMA analytics
REVOKE SELECT ON TABLES FROM intern;              -- 撤回未来表的默认只读授权
```

默认权限按**对象创建者**生效，省略 `FOR ROLE` 时作用于当前角色。多个创建者需分别设置；已有对象不受影响。撤权应在原授权范围执行，schema 级撤权不能抵消全局默认授权。

## 再授权

```sql
GRANT SELECT ON TABLE lab.salary TO manager WITH GRANT OPTION;
-- manager 能查询，也能把该表的 SELECT 授予别人。

GRANT SELECT ON TABLE lab.salary TO bob;
-- manager 在自己的连接中执行，将 SELECT 授予 bob。

GRANT intern TO manager WITH ADMIN OPTION;
-- manager 能把 intern 这个角色授予别人。

GRANT intern TO bob;
-- manager 在自己的连接中执行，将 bob 加入 intern。
```

`GRANT OPTION` 管对象权限的再授权；`ADMIN OPTION` 管角色成员关系的再授予。查询表仍需 schema USAGE。

## 撤回权限

```sql
REVOKE SELECT ON TABLE lab.salary FROM alice;     -- 撤回表的查询授权
REVOKE INSERT, UPDATE, DELETE ON TABLE lab.salary FROM alice; -- 撤回写入授权
REVOKE ALL PRIVILEGES ON TABLE lab.salary FROM alice; -- 撤回该表的全部普通表级授权
REVOKE SELECT (salary) ON TABLE lab.salary FROM bob; -- 撤回指定列的查询授权
REVOKE SELECT ON ALL TABLES IN SCHEMA analytics FROM intern; -- 批量撤回现有表查询授权

REVOKE SELECT ON TABLE lab.salary FROM manager RESTRICT;
-- 默认行为：有下游依赖就报错，撤销不生效。

REVOKE SELECT ON TABLE lab.salary FROM manager CASCADE;
-- 撤回 manager 的授权，并撤回依赖此链的下游授权。

REVOKE GRANT OPTION FOR SELECT ON TABLE lab.salary FROM manager CASCADE;
-- 保留 manager 的 SELECT，撤回再授权能力及依赖它的下游授权。

REVOKE ADMIN OPTION FOR intern FROM manager;
-- 撤回 manager 再授予 intern 成员关系的能力，保留其成员身份。

REVOKE CONNECT ON DATABASE testdb FROM PUBLIC;    -- 撤回所有角色共有的连接授权
```

REVOKE 删除授权来源，不是“禁止规则”。其他角色、PUBLIC、独立授权链或所有权仍可能提供权限。`PUBLIC` 代表所有角色，不是 schema `public`。角色成员关系的依赖撤销行为存在版本差异，PG 16 起会跟踪这类依赖。

领导离职、保留下属权限：先由表所有者/管理员给 bob 独立授权，再撤 manager 的链。

```sql
GRANT SELECT ON TABLE lab.salary TO bob;
REVOKE SELECT ON TABLE lab.salary FROM manager CASCADE;
```

## 查询用户与权限：SQL

```sql
SELECT session_user, current_user, current_database(); -- 查看登录身份、执行身份、当前数据库

SELECT rolname, rolcanlogin, rolsuper, rolcreaterole, rolcreatedb, rolinherit
FROM pg_roles ORDER BY rolname;                  -- 查看所有角色及属性

SELECT rolname FROM pg_roles WHERE rolcanlogin ORDER BY rolname;
-- 只查看能登录的用户。

SELECT r.rolname AS granted_role, m.rolname AS member, am.admin_option
FROM pg_auth_members AS am
JOIN pg_roles AS r ON r.oid = am.roleid
JOIN pg_roles AS m ON m.oid = am.member
ORDER BY granted_role, member;                   -- 查看直接角色成员关系

SELECT grantor, grantee, table_schema, table_name, privilege_type, is_grantable
FROM information_schema.table_privileges
WHERE table_schema = 'lab'
ORDER BY table_name, grantee, privilege_type;     -- 查看表级授权与是否可再授权

SELECT grantee, table_schema, table_name, column_name, privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'lab';                      -- 查看列权限记录，也可能包含整表授权对应的列

SELECT schemaname, tablename, tableowner
FROM pg_tables WHERE schemaname = 'lab';         -- 查看表的所有者

SELECT has_database_privilege('alice', 'testdb', 'CONNECT'); -- 是否能连接数据库
SELECT has_schema_privilege('alice', 'lab', 'USAGE');       -- 是否能访问 schema
SELECT has_schema_privilege('alice', 'lab', 'CREATE');      -- 是否能在 schema 建对象
SELECT has_table_privilege('alice', 'lab.salary', 'SELECT'); -- 是否有表查询权限
SELECT has_table_privilege('alice', 'lab.salary', 'DELETE'); -- 是否有表删除行权限
SELECT has_column_privilege('bob', 'lab.salary', 'name', 'SELECT'); -- 是否能查询指定列
SELECT has_sequence_privilege('alice', 'lab.salary_id_seq', 'USAGE'); -- 是否能使用序列
```

`information_schema` 权限视图受当前角色可见范围限制，不会把权限组授权展开成每个成员的记录。`has_*_privilege` 用于检查有效权限；最终用该用户连接执行操作验证。表权限检查为 true，也不代表能绕过行级安全或其他限制。

## 查询用户与权限：psql

这些是 psql 专用命令，不能当 SQL 在 DataGrip 或 Python 驱动中执行。

| 命令 | 含义 |
|---|---|
| `\conninfo` | 查看当前连接 |
| `\du` / `\du+` | 查看角色及属性 |
| `\drg` | 查看成员关系，需较新 psql 版本 |
| `\l+` | 查看数据库及权限 |
| `\dn+` | 查看 schema 及权限 |
| `\dp` | 查看表、视图、序列等对象权限 |
| `\dp lab.salary` | 查看指定表的权限 |
| `\ddp` | 查看默认权限 |
| `\password alice` | 交互修改 alice 的密码 |
| `\q` | 退出 psql |

`\dp` 中 `bob=r/manager` 表示 manager 给 bob 授予 SELECT，`r*` 表示可再授权。权限字段为空不等于没有权限，还需考虑默认 ACL、所有者与继承。

## 连接数据库：命令行与 Docker

```bash
# 本机连接：-h 地址，-p 端口，-U 用户，-d 数据库，-W 提示输入密码。
psql -h localhost -p 5432 -U alice -d testdb -W

# 本项目现有服务：以 siri 进入数据库命令行。
docker exec -it db_learning psql -U siri -d tron_binance_txs

# 在同一个服务容器中，以另一个已创建的用户建立连接。
docker exec -it db_learning \
  psql -h 127.0.0.1 -p 5432 -U alice -d tron_binance_txs -W

# Mac Docker Desktop：启动临时客户端容器，连接原服务，不启动第二个数据库。
docker run --rm -it postgres:17 \
  psql -h host.docker.internal -p 5432 -U alice -d tron_binance_txs -W
```

客户端容器中的 `localhost` 指向它自己，`host.docker.internal` 指向 Mac 宿主机；端口填原服务映射到宿主机的端口。省略 `-h` 通常走本地 socket，是否验证密码由服务器认证配置决定。
