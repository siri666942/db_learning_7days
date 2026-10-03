# 表、数据写入与视图实验

这个实验最初是为了理解数据库视图，因此原目录名为 `view_demo`。实践过程中，我发现需要先准备数据、建表并完成入库，才能更直观地理解视图的作用，于是把实验扩展成了一条完整的流程：从 TRONSCAN 获取交易数据，使用 Python 清洗并写入 PostgreSQL，再通过视图查询。

## 实验流程

1. **查找地址**：调用 TRONSCAN 的 `/api/search/v2` 接口，搜索 `Binance-Hot`，筛选币安热钱包地址，按标签编号排序并保存为 JSON。
2. **获取交易**：选取一个热钱包地址，调用 `/api/transfer/trx` 接口，获取一批 TRX 转账记录作为实验数据。
3. **清洗数据**：从接口返回的原始数据中提取交易哈希、区块号、转出地址、转入地址和金额等字段；将毫秒时间戳转换为带时区的时间，并将交易结果映射为 `0`（成功）或 `1`（失败）。
4. **建表与入库**：通过 Docker 启动 PostgreSQL，创建 `public.tron_transactions` 表，添加列注释和索引，再使用 Psycopg 批量插入交易数据。
5. **创建与查询视图**：筛选成功的 TRX 交易，将金额从 SUN 换算为 TRX（1 TRX = 1,000,000 SUN），创建 `successful_txs_by_trx` 视图，并在 DataGrip 中使用 `SELECT` 查询。

## 文件说明

```text
db_view_lab/
├── README.md                       # 实验说明与学习记录
├── import_binance_trx.ipynb         # 数据获取、清洗、入库与视图实验
├── data/
│   └── binance_hot_addresses.json   # 从 API 获取的热钱包地址
└── sql/
    └── schema.sql                  # 建表、列注释与索引的 SQL
```

本实验以 notebook 为主要入口，方便逐步运行代码、查看接口响应和验证 SQL 执行结果。`schema.sql` 是表结构的独立参考，内容与 notebook 中的建表操作对应，选择一处执行即可。

## 运行准备

- 按照 [Docker 启动说明](../docs/docker-postgres.md)启动 PostgreSQL。
- 在 Python 环境中安装 `requests`、`python-dotenv`、`psycopg[binary]` 和 `ipykernel`，在 notebook 中选择该环境作为内核。
- 参考仓库根目录的 `.env.example`，在本地 `.env` 中设置 `TRON_API_KEY` 和 `POSTGRES_PASSWORD`，并确认 notebook 中的数据库连接参数与本地配置一致。
- 从仓库根目录或 `db_view_lab` 目录启动 notebook，按实验阶段运行相应单元格。地址 JSON 统一保存到本实验的 `data/` 目录。

notebook 保留了探索过程中报错、回滚和重试的单元格，适合逐段阅读与运行。重复执行建表、建索引或插入相同交易时，可能出现对象已存在或主键重复的错误；SQL 执行失败后，应先调用 `conn.rollback()` 恢复事务状态，再修改并重试。成功执行后，通过 `conn.commit()` 提交，其他连接才能看到结果。

## 学到的内容

- **TRONSCAN API**：构造请求参数、设置请求头、读取响应，并理解地址查询与交易查询接口的用途。
- **数据清洗**：将原始 JSON 整理成适合入库的记录，处理字段映射、数据类型、时间戳与金额单位。
- **Python 操作 PostgreSQL**：使用 `execute()` 执行语句，使用 `executemany()` 批量写入，理解命名占位符、事务提交与回滚。
- **表与索引**：设计字段类型、主键和约束，添加列注释，并为时间查询及币种与时间的组合查询建立索引。
- **视图**：用一条查询定义视图，把常用的筛选和单位换算封装起来，再像查询表一样查询视图。普通视图保存的是查询定义，查询结果来自底层表。
- **Docker 与 DataGrip**：启动数据库容器，理解端口映射，并在 DataGrip 中确认数据库与 schema、检查表结构和查询数据。

这个实验让我把“获取数据 → 清洗数据 → 建表入库 → 通过视图查询”的过程连了起来，也帮助我理解了 Python、SQL 和数据库客户端各自承担的工作。
