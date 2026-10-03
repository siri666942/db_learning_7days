CREATE TABLE public.tron_transactions (
    hash CHAR(64) PRIMARY KEY,
    token VARCHAR(16) NOT NULL,
    block_number  BIGINT NOT NULL,
    from_address VARCHAR(64) NOT NULL,
    to_address VARCHAR(64) NOT NULL,
    value NUMERIC(78,0) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    contract_ret SMALLINT NOT NULL,
    contract_type INTEGER NOT NULL,
    CHECK (contract_ret in (0,1))
);

COMMENT ON COLUMN public.tron_transactions.contract_ret is '交易结果，0 表示成功，1 表示失败；';

CREATE INDEX idx_tron_transactions_created_at
ON public.tron_transactions (created_at);

CREATE INDEX idx_tron_transactions_token_created_at
ON public.tron_transactions (token,created_at);
