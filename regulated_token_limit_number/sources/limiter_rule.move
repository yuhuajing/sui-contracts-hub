// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// An example of a Rule for the Closed Loop Token which limits the amount per
/// operation. Can be used to limit any action (eg transfer, toCoin, fromCoin).
module regulated_token::denylist_rule;
    use std::string::String;
    use sui::{token::{Self, TokenPolicy, TokenPolicyCap, ActionRequest}, vec_map::{Self, VecMap}};

    /// Trying to perform an action that exceeds the limit.
    const ELimitExceeded: u64 = 0;

    /// The Rule witness.
    public struct Limiter has drop {}

    /// The Config object for the `lo
    public struct Config has store, drop {
        /// Mapping of Action -> Limit
        limits: VecMap<String, u64>,
    }

    /// Verifies that the request does not exceed the limit and adds an approval
    /// to the `ActionRequest`.
    public fun verify<T>(
        policy: &TokenPolicy<T>,
        request: &mut ActionRequest<T>,
        ctx: &mut TxContext,
    ) {
        if (!token::has_rule_config<T, Limiter>(policy)) {
            return token::add_approval(Limiter {}, request, ctx)
        };

        let config: &Config = token::rule_config(Limiter {}, policy);
        if (!vec_map::contains(&config.limits, &token::action(request))) {
            return token::add_approval(Limiter {}, request, ctx)
        };

        let action_limit = *vec_map::get(&config.limits, &token::action(request));

        assert!(token::amount(request) <= action_limit, ELimitExceeded);
        token::add_approval(Limiter {}, request, ctx);
    }

    /// Updates the config for the `Limiter` rule. Uses the `VecMap` to store
    /// the limits for each action.
    public entry fun set_config<T>(
        policy: &mut TokenPolicy<T>,
        cap: &TokenPolicyCap<T>,
        flag:u64,
        amount:u64,
        ctx: &mut TxContext,
    ) {
        let action = if (flag == 0){
            token::transfer_action()
        }else if (flag == 1){
            token::spend_action()
        }else if (flag == 2){
            token::to_coin_action()
        }else if (flag == 3){
            token::from_coin_action()
        }else{
            b"unknow".to_string()
        };

        let mut limit = vec_map::empty();
        vec_map::insert(&mut limit, action, amount);

        // if there's no stored config for the rule, add a new one
        if (!token::has_rule_config<T, Limiter>(policy)) {
            let config = Config { limits:limit };
            token::add_rule_config(Limiter {}, policy, cap, config, ctx);
        } else {
            let config: &mut Config = token::rule_config_mut(Limiter {}, policy, cap);
            config.limits = limit;
        }
    }

    /// Returns the config for the `Limiter` rule.
    public fun get_config<T>(policy: &TokenPolicy<T>): VecMap<String, u64> {
        token::rule_config<T, Limiter, Config>(Limiter {}, policy).limits
    }
