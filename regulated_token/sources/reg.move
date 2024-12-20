// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

module regulated_token::reg;
    use sui::coin::{Self, TreasuryCap};
    use sui::token::{Self, Token, TokenPolicy};

    use regulated_token::denylist_rule::{Self as denylist, Denylist};

    const ENotAuthorized: u64 = 0;
    /// The OTW and the type for the Token
    public struct REG has drop {}

    /// The Gift object - can be purchased for 10 tokens.
    public struct Gift has key, store {
        id: UID,
    }

    const GIFT_PRICE: u64 = 1;
    const EIncorrectAmount: u64 = 0;
    /// The OTW for the module.
    public struct ADMINCAP has key,store {
        id: UID,
        owner:address,
    }

    // Create a TreasuryCap in the module initializer.
    // Also create a `TokenPolicy` (while this action can be performed offchain).
    // The policy does not allow any action by default!
    fun init(otw: REG, ctx: &mut TxContext) {
        let (treasury_cap, coin_metadata) = coin::create_currency(
            otw, 6, b"REG", b"Regulated Token", b"Example of a regulated token",
            option::none(), ctx
        );


       // transfer::public_transfer(treasury_cap, ctx.sender());
        transfer::public_share_object(treasury_cap);
        transfer::public_freeze_object(coin_metadata);

        let admincap = ADMINCAP{id: object::new(ctx), owner:ctx.sender()};
        transfer::public_transfer(admincap, ctx.sender());
    }

   public entry fun initPolicy(cap: &ADMINCAP,treasury_cap: &TreasuryCap<REG>, ctx: &mut TxContext) {
        assert!(cap.owner == ctx.sender(), ENotAuthorized);
        let (mut policy, policy_cap) = token::new_policy(treasury_cap, ctx);

        // Allow transfer and spend by default
       // token::allow(&mut policy, &policy_cap, token::transfer_action(), ctx);
        token::allow(&mut policy, &policy_cap, token::spend_action(), ctx);

        // token::add_rule_for_action<REG, Denylist>(
        //     &mut policy, &policy_cap, token::transfer_action(), ctx
        // );

        token::add_rule_for_action<REG, Denylist>(
            &mut policy, &policy_cap, token::spend_action(), ctx
        );

        transfer::public_transfer(policy_cap, ctx.sender());
        token::share_policy(policy);
    }

    // === Admin entry functions (required for CLI) ===

    /// Mint `Token` with `amount` and transfer it to the `recipient`.
    public entry fun mint_and_transfer(
        admincap: &ADMINCAP,
        cap: &mut TreasuryCap<REG>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        assert!(admincap.owner == ctx.sender(), ENotAuthorized);
        let token = token::mint(cap, amount, ctx);
        let request = token::transfer(token, recipient, ctx);
        token::confirm_with_treasury_cap(cap, request, ctx);
    }

    public entry fun burn(
        cap: &mut TreasuryCap<REG>,
        token: Token<REG>
    ) {
        token::burn(cap, token);
    }

    // === User-related entry functions ===

    /// Split `amount` from `token` transfer it to the `recipient`.
    public entry fun split_and_transfer(
        self: &TokenPolicy<REG>,
        token: &mut Token<REG>,
        amount: u64,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let to_send = token::split(token, amount, ctx);
        let mut request = token::transfer(to_send, recipient, ctx);
        denylist::verify(self, &mut request, ctx);
        token::confirm_request(self, request, ctx);
    }

    /// Transfer `token` to the `recipient`.
    public entry fun transfer(
        self: &TokenPolicy<REG>,
        token: Token<REG>,
        recipient: address,
        ctx: &mut TxContext
    ) {
        let mut request = token::transfer(token, recipient, ctx);
        denylist::verify(self, &mut request, ctx);
        token::confirm_request(self, request, ctx);
    }

    /// Spend a given `amount` of `Token`.
    public entry fun spend(
        self: &mut TokenPolicy<REG>,
        token: &mut Token<REG>,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(token::value(token) >= amount * GIFT_PRICE, EIncorrectAmount);
        let to_spend = token::split(token, amount * GIFT_PRICE, ctx);
        let mut request = token::spend(to_spend, ctx);
        denylist::verify(self, &mut request, ctx);
        token::confirm_request_mut(self, request, ctx);
        transfer::public_transfer(Gift { id: object::new(ctx) },ctx.sender());
    }
