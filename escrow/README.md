# Sui Escrow
资源交换的托管实现方式
## Owner
- 双方各自拥有自己的 `object`
  - 将 `（key,DataField）`组合锁仓
- 创建第三方的托管
  - `A` 创建托管 `field_a`，要求交换 `address_b` 使用 `key_b` 锁仓的数据
  - `B` 创建托管 `field_b`，要求交换 `address_a` 使用 `key_a` 锁仓的数据
  - `field_a,field_b` 转入第三方账户
- 三方账户执行 `swap`
  - 传参并校验 `field_a,field_b`
  - `A` 想要的交换对象是 `B`，`B` 想要的交换对象是 `A`
  - `A` 想要的是 `B` 旗下 `key_b` 锁仓的数据，`B` 想要的 `A` 旗下 `key_a` 锁仓的数据
```sui move
        // Make sure the sender and recipient match each other
        assert!(sender1 == recipient2, EMismatchedSenderRecipient);
        assert!(sender2 == recipient1, EMismatchedSenderRecipient);

        // Make sure the objects match each other and haven't been modified
        // (they remain locked).
        assert!(escrowed_key1 == exchange_key2, EMismatchedExchangeObject);
        assert!(escrowed_key2 == exchange_key1, EMismatchedExchangeObject);
```
## Shared
owner 方式根据锁仓和第三方托管实现数据交换

第三方托管的方式存在风险，因此可以采用 `shared_field` 做数据交换,让数据锁仓方自己选择进行交换

- `A` 想要 交换 `B` 旗下 `key_b` 锁仓的数据
- `A` 创建一个 `data_field`
  - 指定待交换的数据是 `data_a`
  - 指定待交换的对象地址是 `address_b`
  - 指定待交换的数据通过 `key_b` 锁仓
- `data_field` 发布到 `shared_field`
- `B` 执行 `swap`
  - 传参锁仓数据（`key_b,locked_b`）
  - 解锁数据
  - 执行校验并完成交换
```sui move
        assert!(option::is_some(&escrow.escrowed), EAlreadyExchangedOrReturned);
        assert!(escrow.recipient == tx_context::sender(ctx), EMismatchedSenderRecipient);
        assert!(escrow.exchange_key == object::id(&key), EMismatchedExchangeObject);

        let escrowed1 = option::extract<T>(&mut escrow.escrowed);
        let escrowed2 = lock::unlock(locked, key);

        // Do the actual swap
        transfer::public_transfer(escrowed2, escrow.sender);
        transfer::public_transfer(escrowed1, escrow.recipient);
```
