# Sui Books
## 基础命令
- `sui move new xxx`，新建 `packages`
- `sui move build`，编译当前合约
- `sui move test`，执行测试函数
- `sui client active-address`,查看当前的节点地址
- `sui client faucet`,申领测试代笔到当前激活地址
- `sui client balance`,查询当前激活地址的余额
- `sui client objects`,查询当前账户挂在的 objects 对象
## 构建交易
```bash
sui client publish --gas-budget 100000000 --skip-dependency-verification --with-unpublished-dependencies --json
```
设置交易全局变量：
```bash
export PACKAGE_ID=xxxxx
export MY_ADDRESS=$(sui client active-address)
```
构建交易：
```bash
$ sui client ptb \
--gas-budget 100000000 \
--assign sender @$MY_ADDRESS \
--move-call $PACKAGE_ID::todo_list::new
```
处理交易返回结果：
```bash
--assign list \
--transfer-objects "[list]" sender
```
查询 object 数据
```bash
sui client object $LIST_ID --json
```
