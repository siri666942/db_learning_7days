# 使用 Docker 启动 PostgreSQL

启动 PostgreSQL 17 容器，将容器的 5432 端口映射到本机的 5432 端口。执行前，将 `your_password` 替换为自己的数据库密码。

```bash
docker run \
  --name db_learning \
  -e POSTGRES_USER=siri \
  -e POSTGRES_PASSWORD='your_password' \
  -e POSTGRES_DB=tron_binance_txs \
  -p 5432:5432 \
  -d postgres:17
```

在 Python 或 DataGrip 中使用以下连接配置：

| 配置项 | 值 |
| --- | --- |
| 主机 | `localhost` |
| 端口 | `5432` |
| 数据库 | `tron_binance_txs` |
| 用户名 | `siri` |
| 密码 | 启动容器时设置的密码 |
| 实验使用的 schema | `public` |

容器已创建但处于停止状态时，直接启动已有容器：

```bash
docker start db_learning
```

查看运行中的容器：

```bash
docker ps
```

进入容器的 shell：

```bash
docker exec -it db_learning bash
```

也可以直接进入数据库命令行：

```bash
docker exec -it db_learning psql -U siri -d tron_binance_txs
```
