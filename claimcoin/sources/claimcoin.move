/// Module: claimcoin
module claimcoin::referral;

use sui::balance::{Self,Balance};
use sui::object::{ id_address};
use sui::coin::Coin;
use sui::table::Table;
use sui::tx_context::{ sender};
use sui::transfer::{ share_object, public_transfer};
use sui::coin;
use sui::table;
use sui::event::emit;
use sui::clock::{Clock, timestamp_ms};

public struct REFERRAL has drop {}

public struct AdminCap has key, store {
    id: UID
}

const ERR_BAD_STATE: u64 = 1001;
const ERR_NOT_ENOUGH_FUND: u64 = 1002;
const ERR_BAD_REFERRAL_INFO: u64 = 1003;
const ERR_BAD_FUND: u64 = 1004;
const ERR_DISTRIBUTE_TIME: u64 = 1005;
const ERR_OUT_OF_FUND: u64 = 1006;

const STATE_INIT: u8 = 0;
const STATE_CLAIM: u8 = 1;
const STATE_CLOSED: u8 = 2;

public struct ReferralCreatedEvent has drop, copy {
    referral: address, // Chain address of the referral object
    state: u8, // Statue of teh referral statue
    rewards_total: u64, // Total rewards to the users
    fund_total: u64, // Total depositted coins
    user_total: u64, //Total to-claim users
    distribute_time_ms: u64 // Start time of claimming coins
}

public struct ReferralStatueEvent has drop, copy {
    referral: address,
    state: u8,
    rewards_total: u64,
    fund_total: u64,
    user_total: u64
}

public struct ReferralUserClaimedEvent has drop, copy {
    referral: address,
    state: u8,
    rewards_total: u64,
    fund_total: u64,
    user: address,
    user_claim: u64
}

public struct ReferralUpsertEvent has drop, copy {
    referral: address,
    state: u8,
    rewards_total: u64,
    fund_total: u64,
    user_total: u64,
    users: vector<address>,
    rewards: vector<u64>
}

public struct ReferralRemovedEvent has drop, copy {
    referral: address,
    state: u8,
    rewards_total: u64,
    fund_total: u64,
    user_total: u64,
    users: vector<address>,
}

public struct ReferralDepositEvent has drop, copy {
    referral: address,
    more_reward: u64,
    fund_total: u64,
}

public struct Referral<phantom COIN> has key, store {
    id: UID,
    state: u8,
    // fund: Coin<COIN>,
    fund: Balance<COIN>,
    rewards: Table<address, u64>,
    rewards_total: u64,
    distribute_time_ms: u64
}

fun init(_witness: REFERRAL, ctx: &mut TxContext) {
    let adminCap = AdminCap { id: object::new(ctx) };
    transfer::transfer(adminCap, sender(ctx));
}

public fun change_admin(admin: AdminCap, to: address) {
    public_transfer(admin, to);
}

public entry fun create<COIN>(_admin: &AdminCap, distribute_time_ms: u64, ctx: &mut TxContext) {
    let referral = Referral<COIN> {
        id: object::new(ctx),
        state: STATE_INIT,
        rewards_total: 0,
        fund: balance::zero(),//coin::zero<COIN>(ctx),
        rewards: table::new<address, u64>(ctx),
        distribute_time_ms
    };

    emit(ReferralCreatedEvent {
        referral: id_address(&referral),
        state: referral.state,
        rewards_total: referral.rewards_total,
        fund_total: balance::value(&referral.fund),
        user_total: table::length(&referral.rewards),
        distribute_time_ms
    });

    share_object(referral);
}

public entry fun update_distribute_time<COIN>(
    _admin: &AdminCap,
    distribute_time_ms: u64,
    referral: &mut Referral<COIN>
) {
    referral.distribute_time_ms = distribute_time_ms;
}

public fun upsert<COIN>(
    _admin: &AdminCap,
    referral: &mut Referral<COIN>,
    mut users: vector<address>,
    mut rewards: vector<u64>,
    _ctx: &mut TxContext
) {
    assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
    let index = vector::length(&users);
    let rsize = vector::length(&rewards);
    assert!(index == rsize && index > 0, ERR_BAD_REFERRAL_INFO);

    while (vector::length(&users) > 0) {
        let user = vector::pop_back(&mut users);// *vector::borrow(&users, index);
        let reward =  vector::pop_back(&mut rewards);//*vector::borrow(&rewards, index);
        assert!(reward > 0, ERR_BAD_REFERRAL_INFO);

        if (table::contains(&referral.rewards, user)) {
            let oldReward = table::remove(&mut referral.rewards, user);
            table::add(&mut referral.rewards, user, reward);
            assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
            referral.rewards_total = referral.rewards_total +  reward  - oldReward;
        }
        else {
            table::add(&mut referral.rewards, user, reward);
            referral.rewards_total = referral.rewards_total + reward;
        }
    };

    emit(ReferralUpsertEvent {
        referral: id_address(referral),
        state: referral.state,
        rewards_total: referral.rewards_total,
        fund_total: balance::value(&referral.fund),
        user_total: table::length(&referral.rewards),
        users,
        rewards
    })
}

public entry fun adduser<COIN>(
    _admin: &AdminCap,
    referral: &mut Referral<COIN>,
    user: address,
    reward: u64,
    _ctx: &mut TxContext
) {
    assert!(referral.state == STATE_INIT, ERR_BAD_STATE);

    assert!(reward > 0, ERR_BAD_REFERRAL_INFO);
    if (table::contains(&referral.rewards, user)) {
        let oldReward = table::remove(&mut referral.rewards, user);
        table::add(&mut referral.rewards, user, reward + oldReward );
        // assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
        referral.rewards_total = referral.rewards_total +  reward  - oldReward;
    }else {
        table::add(&mut referral.rewards, user, reward);
        referral.rewards_total = referral.rewards_total + reward;
    };
}

public entry fun removeuser<COIN>(
    _admin: &AdminCap,
    referral: &mut Referral<COIN>,
    user: address,
    _ctx: &mut TxContext
) {
    assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
    assert!(table::contains(&referral.rewards, user), ERR_BAD_REFERRAL_INFO);

    let oldReward = table::remove(&mut referral.rewards, user);
    assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
    // assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
    referral.rewards_total = referral.rewards_total  - oldReward;
}

public fun remove<COIN>(
    _admin: &AdminCap,
    referral: &mut Referral<COIN>,
    mut users:  vector<address>,
    _ctx: &mut TxContext
) {
    assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
    let index = vector::length(&users);

    assert!(index > 0, ERR_BAD_REFERRAL_INFO);
    while (vector::length(&users) > 0) {
        let user = vector::pop_back(&mut users);//*vector::borrow(&users, index);
        assert!(table::contains(&referral.rewards, user), ERR_BAD_REFERRAL_INFO);
        let oldReward = table::remove(&mut referral.rewards, user);
        assert!(referral.rewards_total >= oldReward, ERR_BAD_REFERRAL_INFO);
        referral.rewards_total = referral.rewards_total - oldReward;
    };

    emit(ReferralRemovedEvent {
        referral: id_address(referral),
        state: referral.state,
        rewards_total: referral.rewards_total,
        fund_total: balance::value(&referral.fund),
        user_total: table::length(&referral.rewards),
        users,
    })
}

public entry fun start_claim_project<COIN>(_admin: &AdminCap, referral: &mut Referral<COIN>, _ctx: &mut TxContext) {
    assert!(referral.state == STATE_INIT, ERR_BAD_STATE);
    assert!(referral.rewards_total <= balance::value(&referral.fund), ERR_NOT_ENOUGH_FUND);
    referral.state = STATE_CLAIM;

    emit(ReferralStatueEvent {
        referral: id_address(referral),
        state: referral.state,
        rewards_total: referral.rewards_total,
        fund_total: balance::value(&referral.fund),
        user_total: table::length(&referral.rewards)
    })
}
// 0x6 - address of the system Clock object
public entry fun claim_reward<COIN>(referral: &mut Referral<COIN>, clock: &Clock, ctx: &mut TxContext) {
    let user = sender(ctx);
    assert!(referral.state == STATE_CLAIM, ERR_BAD_STATE);
    assert!(table::contains(&referral.rewards, user), ERR_BAD_REFERRAL_INFO);
    assert!(timestamp_ms(clock) >= referral.distribute_time_ms, ERR_DISTRIBUTE_TIME);

    let reward = table::remove(&mut referral.rewards, user);
    assert!(balance::value(&referral.fund) >= reward, ERR_OUT_OF_FUND);
    public_transfer(coin::take(&mut referral.fund, reward, ctx), user);
    referral.rewards_total = referral.rewards_total - reward;

    emit(ReferralUserClaimedEvent {
        referral: id_address(referral),
        state: referral.state,
        rewards_total: referral.rewards_total,
        fund_total: balance::value(&referral.fund),
        user,
        user_claim: reward
    })
}

public entry fun close<COIN>(_admin: &AdminCap, referral: &mut Referral<COIN>, _ctx: &mut TxContext) {
    assert!(referral.state < STATE_CLOSED, ERR_BAD_STATE);
    referral.state = STATE_CLOSED;

    emit(ReferralStatueEvent {
        referral: id_address(referral),
        state: referral.state,
        rewards_total: referral.rewards_total,
        fund_total: balance::value(&referral.fund),
        user_total: table::length(&referral.rewards)
    })
}

public entry fun withdraw_fund<COIN>(
    _admin: &AdminCap,
    referral: &mut Referral<COIN>,
    value: u64,
    to: address,
    ctx: &mut TxContext
) {
    assert!(referral.state == STATE_CLOSED, ERR_BAD_STATE);
    assert!(balance::value(&referral.fund) >= value, ERR_OUT_OF_FUND);
    public_transfer(coin::take(&mut referral.fund, value, ctx), to);

}

public entry fun deposit_fund<COIN>(referral: &mut Referral<COIN>, fund: Coin<COIN>) {
    let more_fund = coin::value(&fund);
    assert!(more_fund > 0, ERR_BAD_FUND);
    coin::put(&mut referral.fund, fund);

    emit(ReferralDepositEvent {
        referral: id_address(referral),
        more_reward: more_fund,
        fund_total: balance::value(&referral.fund)
    })
}