/// Module: whitelist
module whitelist::kyc;

use sui::tx_context::{ sender};
use sui::transfer::transfer;
use sui::event::emit;
use sui::table::Table;
use sui::table;

///Witness
public struct KYC has drop {}

public struct AdminCap has key, store {
    id: UID
}

const KYC_LEVEL_ONE: u8 = 1;
// const KYC_LEVEL_TWO: u8 = 2;
// const KYC_LEVEL_THREE: u8 = 3;
// const KYC_LEVEL_FOUR: u8 = 4;

const ERR_ALREADY_KYC: u64 = 1001;
const ERR_NOT_KYC: u64 = 1002;

public struct Kyc has key, store {
    id: UID,
    whitelist: Table<address, u8>
}

fun init(_witness: KYC, ctx: &mut TxContext) {
    let adminCap = AdminCap { id: object::new(ctx) };
    transfer::public_transfer(adminCap, sender(ctx));

    transfer::share_object(Kyc {
        id: object::new(ctx),
        whitelist: table::new<address, u8>(ctx),
    });
}

public fun change_admin(admin_cap: AdminCap, to: address) {
    transfer(admin_cap, to);
}

public fun add(_admin_cap: &AdminCap, users: vector<address>, kyc: &mut Kyc){
    let mut index = vector::length<address>(&users);

    while (index > 0) {
        index = index - 1;
        let userAddr = *vector::borrow(&users, index);
        assert!(!table::contains(&kyc.whitelist, userAddr), ERR_ALREADY_KYC);
        table::add(&mut kyc.whitelist, userAddr, KYC_LEVEL_ONE);
    };

    emit(AddKycEvent {
        users
    })
}

public entry fun add_address(_admin_cap: &AdminCap, user: address, kyc: &mut Kyc){
    assert!(!table::contains(&kyc.whitelist, user), ERR_ALREADY_KYC);
    table::add(&mut kyc.whitelist, user, KYC_LEVEL_ONE);
}

public entry fun remove_address(_admin_cap: &AdminCap, user: address, kyc: &mut Kyc){
    assert!(table::contains(&kyc.whitelist, user), ERR_NOT_KYC);
    table::remove(&mut kyc.whitelist, user);
}

public  fun remove(_admin_cap: &AdminCap, users: vector<address>, kyc: &mut Kyc){
    let mut index = vector::length<address>(&users);

    while (index > 0) {
        index = index - 1;
        let userAddr = *vector::borrow(&users, index);
        assert!(table::contains(&kyc.whitelist, userAddr), ERR_NOT_KYC);
        table::remove(&mut kyc.whitelist, userAddr);
    };

    emit(RemoveKycEvent {
        users
    })
}

public entry fun hasKYC(user: address, kyc: &Kyc){
    emit(HasKycEvent{
        has:table::contains(&kyc.whitelist, user)
    })
}

public struct AddKycEvent has copy, drop {
    users: vector<address>
}

public struct HasKycEvent has copy, drop {
    has: bool
}

public struct RemoveKycEvent has copy, drop {
    users: vector<address>
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext){
    init(KYC{}, ctx);
}
