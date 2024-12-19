// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// This is a simple example of a permissionless module for an imaginary game
/// that sells swords for Gems. Gems are an in-game currency that can be bought
/// with SUI.
module sbt_gems::sword {
    use sbt_gems::gem::GEM;
    use sui::token::{Self, Token, ActionRequest};

    /// Trying to purchase a sword with an incorrect amount.
    const EWrongAmount: u64 = 0;

    /// The price of a sword in Gems.
    const SWORD_PRICE: u64 = 10;

    /// A game item that can be purchased with Gems.
    public struct Sword has key, store { id: UID }

    /// Purchase a sword with Gems.
    public fun buy_sword( gems: Token<GEM>, ctx: &mut TxContext): ( ActionRequest<GEM>) {
        assert!(SWORD_PRICE == token::value(&gems), EWrongAmount);
        transfer::public_transfer(Sword { id: object::new(ctx) }, ctx.sender());
        token::spend(gems, ctx)
       // token::confirm_with_treasury_cap(&mut self.gem_treasury, request, ctx);
    }
}

/// Module that defines the in-game currency: GEMs which can be purchased with
/// SUI and used to buy swords (in the `sword` module).
module sbt_gems::gem {
    use std::{option::none, string::{Self, String}};
    use sui::{
        balance::{Self, Balance},
        coin::{Self, Coin, TreasuryCap},
        sui::SUI,
        token::{Self, Token, TokenPolicy, TokenPolicyCap},
        tx_context::sender
    };

    /// Trying to purchase Gems with an unexpected amount.
    const EUnknownAmount: u64 = 0;
    const EIncorrectAmount: u64 = 1;

    /// 0.0001 SUI is the price of a small bundle of Gems.
    const SMALL_BUNDLE: u64 = 100_000;
    const SMALL_AMOUNT: u64 = 1;

    /// 0.001 SUI is the price of a medium bundle of Gems.
    const MEDIUM_BUNDLE: u64 = 1_000_000;
    const MEDIUM_AMOUNT: u64 = 2;

    /// 0.01 SUI is the price of a large bundle of Gems.
    /// This is the best deal.
    const LARGE_BUNDLE: u64 = 10_000_000;
    const LARGE_AMOUNT: u64 = 3;

    #[allow(lint(coin_field))]
    /// Gems can be purchased through the `Store`.
    public struct GemStore has key {
        id: UID,
        /// Profits from selling Gems.
        profits: Balance<SUI>,
        /// The Treasury Cap for the in-game currency.
        gem_treasury: TreasuryCap<GEM>,
    }

    /// The OTW to create the in-game currency.
    public struct GEM has drop {}

    // In the module initializer we create the in-game currency and define the
    // rules for different types of actions.
    fun init(otw: GEM, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            otw,
            0,
            b"GEM",
            b"Capy Gems", // otw, decimal, symbol, name
            b"In-game currency for Capy Miners",
            none(), // description, url
            ctx,
        );
        // create and share the GemStore
        transfer::share_object(GemStore {
            id: object::new(ctx),
            gem_treasury: treasury_cap,
            profits: balance::zero(),
        });

        transfer::public_freeze_object(coin_metadata);
    }

    public entry fun initPolicy(self: &GemStore, ctx: &mut TxContext) {
        // assert!(cap.owner == ctx.sender(), ENotAuthorized);
        let (mut policy, policy_cap) = token::new_policy(&self.gem_treasury, ctx);
        // Allow transfer and spend by default
        token::allow(&mut policy, &policy_cap, token::to_coin_action(), ctx);
        token::allow(&mut policy, &policy_cap, token::spend_action(), ctx);
        token::allow(&mut policy, &policy_cap, buy_action(), ctx);
        transfer::public_transfer(policy_cap, ctx.sender());
        token::share_policy(policy);
    }

    /// Purchase Gems from the GemStore. Very silly value matching against module
    /// constants...
    public entry fun buy_gems(
        self: &mut GemStore,
        payment: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext,
    ) {
        assert!(coin::value(payment) >= amount , EIncorrectAmount);

        let purchased = if (amount == SMALL_BUNDLE) {
            SMALL_AMOUNT
        } else if (amount == MEDIUM_BUNDLE) {
            MEDIUM_AMOUNT
        } else if (amount == LARGE_BUNDLE) {
            LARGE_AMOUNT
        } else {
            abort EUnknownAmount
        };

        coin::put(&mut self.profits, coin::split(payment,amount,ctx));

        // create custom request and mint some Gems
        let gems = token::mint(&mut self.gem_treasury, purchased, ctx);
        let request = token::transfer(gems, ctx.sender(), ctx);
        token::confirm_with_treasury_cap(&mut self.gem_treasury, request, ctx);
    }

    public entry fun withdraw(
        self: &mut GemStore,
        des: &mut Coin<SUI>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        // assert!(admincap.owner == ctx.sender(), ENotAuthorized);
        assert!(self.profits.value() <= amount , EIncorrectAmount);
        coin::join(des,coin::take(&mut self.profits,amount,ctx));
    }

    /// The name of the `buy` action in the `GemStore`.
    public fun buy_action(): String { string::utf8(b"buy") }

    /// Be SBT if delete this funs
    public entry fun token_to_coin(policy: &TokenPolicy<GEM>, gems: Token<GEM>,  recipient: address, ctx: &mut TxContext) {
        let (coin, request) =  token::to_coin(gems,ctx);
        transfer::public_transfer(coin,recipient);
        token::confirm_request(policy, request, ctx);
    }

    /// Transfer converted coin objects
    public entry fun transfer_coin(from: &mut Coin<GEM>, amount: u64,  recipient: address, ctx: &mut TxContext){
        let coin = coin::split<GEM>(from, amount, ctx);
        transfer::public_transfer(coin, recipient)
    }
/*
    /// Not Allowed because 'store' constraint not satisifed in TOken<GEM>
    public fun from_coin_to_token(gems: Coin<GEM>,  recipient: address, ctx: &mut TxContext):ActionRequest<GEM> {
        let (token, request) =  token::from_coin(gems,ctx);
        transfer::public_transfer(token,recipient);
        request
    }
*/

}
