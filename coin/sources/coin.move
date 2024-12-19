// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module coin::my_coin;

use sui::coin::{Self, TreasuryCap,Coin};
use sui::url::{Self};

const ENotAuthorized: u64 = 0;

/// The OTW for the module.
public struct ADMINCAP has key,store {
    id: UID,
    owner:address,
}

// The type identifier of coin. The coin will have a type
// tag of kind: `Coin<package_object::mycoin::MYCOIN>`
// Make sure that the name of the type matches the module's name.
public struct MY_COIN() has drop;

// Module initializer is called once on module publish. A treasury
// cap is sent to the publisher, who then controls minting and burning.
fun init(witness: MY_COIN, ctx: &mut TxContext) {
let (treasury, metadata) = coin::create_currency(
    witness,
    6,
    b"MY_COIN",
    b"NAME",
    b"This is the describscription",
    option::some(url::new_unsafe_from_bytes(b"https://i.imgur.com/j2EuFh5.png")),
    ctx,
);

//coin::mint_and_transfer(&mut treasury, 10000000000000000000, ctx.sender(), ctx);
// Freezing this object makes the metadata immutable, including the title, name, and icon image.
// If you want to allow mutability, share it with public_share_object instead.
transfer::public_freeze_object(metadata);
transfer::public_share_object(treasury);
// transfer::public_transfer(treasury, ctx.sender());

let admincap = ADMINCAP{id: object::new(ctx), owner:ctx.sender()};
    transfer::public_transfer(admincap, ctx.sender())
}


// Create MY_COINs using the TreasuryCap.
public entry fun mint(
    cap: &ADMINCAP,
    treasury_cap: &mut TreasuryCap<MY_COIN>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    assert!(cap.owner == ctx.sender(), ENotAuthorized);
    let coin = coin::mint(treasury_cap, amount, ctx);
    transfer::public_transfer(coin, recipient)
}

public entry fun transfer(
    mycoin: &mut Coin<MY_COIN>,
    amount: u64,
    recipient: address,
    ctx: &mut TxContext,
) {
    let coin = coin::split<MY_COIN>(mycoin, amount, ctx);
    transfer::public_transfer(coin, recipient)
}

// Burn MY_COINs using the TreasuryCap.
public entry fun burn(
    treasury_cap: &mut TreasuryCap<MY_COIN>,
    mycoin: Coin<MY_COIN>,
) {
    coin::burn(treasury_cap, mycoin);
}

// Burn MY_COINs using the TreasuryCap.
public entry fun merge(
    mycoin: &mut Coin<MY_COIN>,
    scoin: Coin<MY_COIN>,
) {
    coin::join(mycoin, scoin);
}

