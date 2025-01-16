// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

/// A basic ECDSA utility contract to do the following:
///
/// 1) Hash a piece of data using Keccak256, output an object with hashed data.
/// 2) Recover a Secp256k1 signature to its public key, output an
///    object with the public key.
/// 3) Verify a Secp256k1 signature, produce an event for whether it is verified.
module ecdsa_k1::claim;

use sui::{ecdsa_k1, event};
use std::string::{Self,String};
use sui::hex;
use std::ascii;
use sui::tx_context::{ sender};

// === Object Types ===

/// Object that holds the output data
public struct Output has key, store {
    id: UID,
    value: vector<u8>,
}

// == Event Types ===

/// Event on whether the signature is verified
public struct VerifiedEvent has copy, drop {
    is_verified: bool,
}

/// Event on whether the signature is verified
public struct ClaimEvent has copy, drop {
    uuid: String,
}

/// Event on whether the signature is verified
public struct JoinStringEvent has copy, drop {
    msg: String,
}

public entry fun verify(sig: String, public_key: String, amount: u64,index:u64, timestamp:u64, uuid:u64,signid:u64,ctx: &mut TxContext) {
    let signature = hex::decode(
        ascii::into_bytes(sig.to_ascii()),
    );
    let pk = hex::decode(
        ascii::into_bytes(public_key.to_ascii()),
    );

    let mut msgs = amount.to_string();
    msgs.append(index.to_string());
    msgs.append(timestamp.to_string());
    msgs.append(uuid.to_string());
    msgs.append(signid.to_string());

    event::emit(VerifiedEvent {
        is_verified: ecdsa_k1::secp256k1_verify(&signature, &pk, msgs.as_bytes(), 0),
    });
}

#[test]
fun test_sign() {
    let msg = b"11111";
    let pk = x"0475a3b9e2b8b14739f4e66adb08adb20200d5b2c24b53522574b782428b85bb8d10c6ba7134153f3c647b0aae73d5e2a1cb128ce0273e60f2fc030cb4d8dbb810";
    let sk = x"87d2ebd2b16a8796cf9521216a3ebc8ed6d573cf0a98552322e874c171179f6a";

    // Test with Keccak256 hash
    let sig = ecdsa_k1::secp256k1_sign(&sk, &msg, 0, false);
    assert!(ecdsa_k1::secp256k1_verify(&sig, &pk, &msg, 0));
    assert!(sig == x"fc69b17d89a08714270f0b1bac23c18e334d75855b41b0f89ba6d6836dbcdbf465c96b0b4c8762dcd7192b7fc3fa7f81d305a458a2ddfe04e9e7152cf201b7bb");
    // assert!(verify(sig.to_string(), pk.to_string(), msg.to_string()));

    // // Test with SHA256 hash
    // let sig = ecdsa_k1::secp256k1_sign(&sk, &msg, 1, false);
    // assert!(ecdsa_k1::secp256k1_verify(&sig, &pk, &msg, 1));
    // assert!(sig == x"e5847245b38548547f613aaea3421ad47f5b95a222366fb9f9b8c57568feb19c7077fc31e7d83e00acc1347d08c3e1ad50a4eeb6ab044f25c861ddc7be5b8f9f");
    //
    // // Verification should fail with another message
    // let other_msg = b"Farewell, world!";
    // assert!(!ecdsa_k1::secp256k1_verify(&sig, &pk, &other_msg, 0));
}